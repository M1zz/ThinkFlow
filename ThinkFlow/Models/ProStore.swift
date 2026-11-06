import Foundation
import StoreKit
import SwiftUI
import Combine
import WidgetKit
import LeeoKit

// MARK: - 무엇을 파는가

/// 이어생각의 두 칸 — 무료와 Pro. 상품 · 무료 한도 · 기존 사용자 기준을 여기 한 곳에만 둔다.
///
/// 무료: 생각 다섯 개까지, 끊어둔 문장 · 네 단계 다듬기 · 자료 · 생각 꺼내기 · 내보내기 전부.
/// Pro: 생각 무제한, 홈 화면 위젯, 잠금 화면 · 다이내믹 아일랜드의 생각 시간.
///
/// ⚠️ 이미 만든 생각은 다섯 개를 넘어도 열고 · 이어 쓰고 · 지울 수 있다. 막는 것은 **새로 시작**할 때뿐이다.
enum ThinkFlowPro {

    // ⚠️ App Store Connect · ThinkFlow.storekit 과 글자 하나까지 같아야 한다.
    //    구독 셋은 한 구독 그룹("이어생각 Pro")에 둔다.
    static let weeklyID = "com.leeo.thinkflow.pro.weekly"
    static let monthlyID = "com.leeo.thinkflow.pro.monthly"
    /// 연 구독. 처음 구독하는 사람은 첫 해 반값(App Store 첫 구독 할인).
    static let yearlyID = "com.leeo.thinkflow.pro.yearly"
    /// 평생(비소모성).
    static let lifetimeID = "com.leeo.thinkflow.pro"
    /// 구독 중인 사람의 졸업가 평생 (→ LeeoGraduation).
    static let graduateID = "com.leeo.thinkflow.pro.graduate"

    /// 개발자 응원 팁. 아무것도 열지 않는다 — 권한 상품에 넣지 않는다.
    static let tipIDs = [
        "com.leeo.thinkflow.tip.small",
        "com.leeo.thinkflow.tip.medium",
        "com.leeo.thinkflow.tip.large",
    ]

    static let subscriptionIDs: Set<String> = [weeklyID, monthlyID, yearlyID]
    static let lifetimeIDs: Set<String> = [lifetimeID, graduateID]
    /// 스토어가 불러올 상품. 페이월은 이 가운데 졸업가를 뺀 것을 보인다.
    static let soldIDs = [yearlyID, lifetimeID, monthlyID, weeklyID, graduateID]
    static let entitlementIDs = subscriptionIDs.union(lifetimeIDs)

    /// 자동 갱신 구독의 이용약관 — Apple 표준 EULA.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// 무료로 동시에 벌여 둘 수 있는 생각 수.
    static let freeThreadLimit = 5

    // 계약(`ThinkFlowSpec.monetization`)의 게이트 이름.
    static let threadKey = "thread"
    static let widgetKey = "widget"
    static let liveActivityKey = "liveActivity"

    /// **페이월 없이 나간 마지막 빌드 (1.0.3 빌드 5).** 이 빌드까지 받은 사람은 Pro 를 평생 그대로 쓴다 —
    /// 그때는 생각 개수 · 위젯 · 잠금 화면이 모두 무료였다.
    static let lastFreeBuild = 5

    /// 처음 받은 빌드(`AppTransaction.originalAppVersion`, iOS 는 CFBundleVersion)가 페이월 전인가.
    static func isBeforePaywall(originalAppVersion: String) -> Bool {
        guard let build = originalAppVersion.split(separator: ".").first.flatMap({ Int($0) }) else { return false }
        return build <= lastFreeBuild
    }

    /// 새 생각을 하나 더 시작해도 되는가. Pro 이거나 아직 팔지 않는 중이면 늘 된다.
    static func mayStartThread(existing count: Int, hasPro: Bool, isSelling: Bool) -> Bool {
        hasPro || !isSelling || count < freeThreadLimit
    }
}

// MARK: - 지금 Pro 인가

/// Pro 를 파는 자리. **속은 전부 `LeeoStore`다** — 상품 로드 · 구매 · 복원 · 거래 리스너(다른 기기,
/// 가족 공유, 구입 요청 승인, 환불, 구독 만료)는 거기 있다. 여기서는 그 값을 화면이 읽기 좋게 옮기고,
/// 이 앱의 두 가지 규칙만 더한다.
///
///  ① 페이월 전에 받은 사람은 Pro (`ThinkFlowPro.lastFreeBuild`).
///  ② 스토어에서 Pro 상품을 **한 번도** 불러온 적이 없는 기기는 막지 않는다 —
///     상품이 App Store Connect 에 서기 전에 빌드가 나가도, 살 수 없는데 막히는 사람이 없게.
///     한 번이라도 불러왔으면 그 뒤로는 네트워크가 잠깐 끊겨도 다시 막는다.
@MainActor
@Observable
final class ProStore {

    static let shared = ProStore()

    @ObservationIgnored let store: LeeoStore

    /// 산 것 · 구독 중인 것 · 기존 사용자 가운데 하나라도 있는가.
    private(set) var hasPro: Bool
    /// 페이월 전에 받아서 Pro 를 그대로 쓰는 사람인가.
    private(set) var isLegacy: Bool
    /// 이 기기가 Pro 상품을 한 번이라도 불러왔는가 (②).
    private(set) var isSelling: Bool
    private(set) var products: [Product] = []
    /// 평생(또는 졸업가)을 가졌는가. 그러면 '평생으로 바꾸기' 가 필요 없다.
    private(set) var ownsLifetime = false
    /// 지금 살아 있는 구독. 있으면 설정에 '평생으로 바꾸기' 가 선다.
    private(set) var subscription: LeeoGraduation.Subscription?
    /// 구독 졸업을 제안할 때인가 — 6개월째 · 갱신 7일 전에 한 번씩. 띄운 쪽이 `markGraduationOffered()` 를 부른다.
    private(set) var graduationIsDue = false
    private(set) var isWorking = false
    private(set) var isLoadingProducts = false
    /// 사다가 막혔을 때 그대로 보여 줄 말.
    private(set) var failureMessage: String?

    @ObservationIgnored private var observation: AnyCancellable?
    @ObservationIgnored private static let sellingKey = "pro.productsSeen"

    private init() {
        guard let config = ThinkFlowSpec.paywall else {
            preconditionFailure("계약에 페이월이 없다. ThinkFlowSpec.monetization 을 확인할 것")
        }
        store = LeeoStore(config: config, unlockOverride: Self.unlockOverride, grandfather: Self.installedBeforePaywall)
        hasPro = store.hasPro
        isLegacy = store.isGrandfathered
        isSelling = UserDefaults.standard.bool(forKey: Self.sellingKey)
        // ⚠️ objectWillChange 는 값이 바뀌기 **직전**에 온다. 다음 차례로 미뤄서 읽는다.
        observation = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.pull() }
        }
        pull()
    }

    // MARK: 막아도 되는가

    /// 무료 한도로 막을 수 있는 상태인가. Pro 이거나, 아직 팔지 않는 중이면 막지 않는다.
    var isLocked: Bool { isSelling && !hasPro }

    /// 새 생각을 하나 더 시작해도 되는가. 이미 있는 생각은 언제나 열고 이어 쓰고 지울 수 있다.
    func canStartThread(existing count: Int) -> Bool {
        ThinkFlowPro.mayStartThread(existing: count, hasPro: hasPro, isSelling: isSelling)
    }

    /// 홈 화면 위젯 · 잠금 화면 생각 시간.
    var featuresOpen: Bool { !isLocked }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    // MARK: 상태 맞추기

    /// 영수증을 다시 읽고 상품을 불러온다. 앱을 켤 때 · 다시 열 때마다 부른다.
    func refresh() async {
        await store.refreshEntitlements()
        await store.loadProducts()
        await refreshSubscription()
        pull()
    }

    func loadProducts() async {
        await store.loadProducts()
        pull()
    }

    /// 고른 상품을 산다. ⚠️ `action` 은 화면의 `@Environment(\.purchase)` —
    /// `product.purchase()` 로 사면 아이패드에서 결제 창을 엉뚱한 창에 띄우려다 실패한다.
    func purchase(_ product: Product, using action: PurchaseAction) async {
        _ = await store.purchase(product) { try await action($0) }
        await refreshSubscription()
        pull()
    }

    /// 산 뒤(졸업가 화면 등 LeeoKit 부품이 직접 산 경우) 권한을 다시 읽는다.
    func didPurchaseElsewhere() async {
        await store.refreshEntitlements()
        await refreshSubscription()
        pull()
    }

    /// 기기를 바꿨거나 앱을 지웠다 받은 사람이 되찾는 길.
    func restore() async {
        await store.restore()
        await refreshSubscription()
        pull()
        if !hasPro, failureMessage == nil {
            failureMessage = String(localized: "이 Apple 계정에서 구매한 기록을 찾지 못했어요.",
                                    comment: "Restore purchases: nothing found for this Apple Account")
        }
    }

    func markGraduationOffered() {
        LeeoGraduation.markOffered()
        graduationIsDue = false
    }

    // MARK: -

    private func refreshSubscription() async {
        subscription = await LeeoGraduation.currentSubscription(among: ThinkFlowPro.subscriptionIDs)
    }

    private func pull() {
        hasPro = store.hasPro
        isLegacy = store.isGrandfathered
        products = store.products
        ownsLifetime = !store.purchasedProductIDs.isDisjoint(with: ThinkFlowPro.lifetimeIDs)
        isWorking = store.purchasingProductID != nil || store.isRestoring
        isLoadingProducts = store.isLoadingProducts
        failureMessage = store.lastError

        // ② 졸업가만 온 것은 '판다'로 치지 않는다 — 처음 사는 사람이 살 수 있는 것이 있어야 막는다.
        if !isSelling, products.contains(where: { $0.id != ThinkFlowPro.graduateID }) {
            isSelling = true
            UserDefaults.standard.set(true, forKey: Self.sellingKey)
        }

        if let subscription, !ownsLifetime, product(ThinkFlowPro.graduateID) != nil {
            graduationIsDue = LeeoGraduation.isDue(subscription, lastOffered: LeeoGraduation.lastOffered())
        } else {
            graduationIsDue = false
        }

        // 위젯 · 라이브 액티비티는 App Group 의 한 줄만 읽는다. 바뀐 판에만 다시 그린다.
        if ProAccess.setFeaturesOpen(featuresOpen) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: 규칙 ①

    /// 페이월이 들어오기 전 빌드(`lastFreeBuild` 이하)를 처음 받은 사람인가.
    ///
    /// iOS 의 `originalAppVersion` 은 처음 받은 빌드 번호(CFBundleVersion)다.
    /// ⚠️ 샌드박스 · TestFlight 에서는 늘 "1.0" 이라 모두 기존 사용자로 읽힌다 — 실제 App Store 영수증만 믿는다.
    private static func installedBeforePaywall() async -> Bool {
        guard let result = try? await AppTransaction.shared,
              case .verified(let transaction) = result,
              transaction.environment == .production else { return false }
        return ThinkFlowPro.isBeforePaywall(originalAppVersion: transaction.originalAppVersion)
    }

    private static func unlockOverride() -> Bool? {
        #if DEBUG
        // 스토어 스크린샷은 Pro 화면으로 찍는다 (위젯 · 잠금 화면이 잠긴 채 찍히지 않게).
        if ScreenshotScene.seed != nil { return true }
        #endif
        return nil
    }
}
