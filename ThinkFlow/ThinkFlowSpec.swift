import Foundation
import LeeoKit

enum ThinkFlowSpec: LeeoAppSpec {
    static let appName = "이어생각"
    static let developerEmail = "leeo@kakao.com"
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.leeo.thinkflow")

    /// 정책 링크 — docs/ (GitHub Pages) 의 privacy.html · index.html(지원).
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/ThinkFlow/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/ThinkFlow/")!
    )

    /// 무료 · 이어생각 Pro (주 · 월 · 연 구독과 평생). 상품과 무료 한도는 `ThinkFlowPro` 한 곳에 있다.
    /// 팁은 같은 스토어가 받지만 아무것도 열지 않는다.
    static let monetization = LeeoMonetization.freemiumSubscription(LeeoSubscriptionConfig(
        productIDs: ThinkFlowPro.soldIDs,
        termsURL: ThinkFlowPro.termsURL,
        entitlementIDs: ThinkFlowPro.entitlementIDs,
        gate: LeeoGatePolicy(freeLimits: [ThinkFlowPro.threadKey: ThinkFlowPro.freeThreadLimit],
                             proOnly: [ThinkFlowPro.widgetKey, ThinkFlowPro.liveActivityKey]),
        tipJar: LeeoTipJarConfig(productIDs: ThinkFlowPro.tipIDs)
    ))
    /// 금고가 위젯과 함께 쓰는 공유 컨테이너도 백업한다.
    static let appGroups = ["group.com.leeo.thinkflow"]

    /// App Store 앱 ID — 리뷰 링크 · 친구에게 소개하기에 쓴다.
    static var appStoreID: String? { "6779270691" }

    /// 익명 사용 통계 → FeedbackHub. 없으면 bootstrap 이 스냅샷·app_open 을 건너뛴다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: ThinkFlowSpec.self)
}

// MARK: - 팁 (개발자 응원하기)

/// 팁 엔진은 Pro 를 파는 `LeeoStore` 안에 있다 — 결제 소식을 한 리스너가 받아 팁과 권한으로 나눈다.
/// 팁은 아무것도 열지 않는다.
@MainActor
enum ThinkFlowTip {
    static var tipJar: LeeoTipJar { ProStore.shared.store.tipJar! }
}

/// 팁을 부탁할 만한 순간 — 지금까지 적어 온 **내 생각** 수(붙여 둔 자료는 빼고). 큰 것부터.
enum ThinkFlowTipMoments {
    static let thoughts = [300, 100, 30]

    static func reached(thoughtCount n: Int) -> [LeeoTipMoment] {
        thoughts.filter { n >= $0 }.map { threshold in
            LeeoTipMoment(id: "thoughts.\(threshold)",
                          message: String(localized: "지금까지 생각 \(n)개를 적었어요",
                                          comment: "Tip ask card: how many thoughts the person has written so far"))
        }
    }

    static func reachedNow(in threads: [ThoughtThread]) -> [LeeoTipMoment] {
        reached(thoughtCount: threads.reduce(0) { $0 + $1.entries.filter { !$0.isReference }.count })
    }
}
