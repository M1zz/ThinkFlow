import SwiftUI
import StoreKit
import LeeoKit

// MARK: - 페이월이 뜬 까닭

/// 무엇에 부딪혀 페이월이 떴는가. 머리말 아래 한 줄이 그 순간을 말한다.
enum PaywallReason: String, Identifiable {
    /// 여섯 번째 생각을 시작하려 할 때.
    case threadLimit
    /// 잠긴 홈 화면 위젯을 눌렀을 때.
    case widget
    /// 생각하는 동안 잠금 화면에 시간을 띄우려 할 때.
    case liveActivity
    /// 설정에서 직접 열었을 때.
    case settings

    var id: String { rawValue }

    fileprivate var line: String? {
        switch self {
        case .threadLimit:
            String(localized: "무료로 벌여 둘 수 있는 생각 \(ThinkFlowPro.freeThreadLimit)개가 다 찼어요. 방금 꺼낸 생각은 정리 안 된 생각들에 그대로 남아 있어요.",
                   comment: "Paywall reason: the free thought limit is reached. The new thought is kept in the unsorted list")
        case .widget:
            String(localized: "홈 화면 위젯은 Pro에서 열려요.",
                   comment: "Paywall reason: a locked Home Screen widget was tapped")
        case .liveActivity:
            String(localized: "잠금 화면과 다이내믹 아일랜드의 생각 시간은 Pro에서 열려요.",
                   comment: "Paywall reason: showing the thinking timer on the Lock Screen needs Pro")
        case .settings:
            nil
        }
    }
}

// MARK: - 페이월

/// 이어생각 Pro 페이월 — 무료와 Pro 를 나란히 보이고, 연 구독을 기본으로 고른다.
/// 평생은 연 구독 바로 옆에, 월 · 주는 '다른 기간 보기' 안에 둔다.
struct ProPaywallView: View {
    let reason: PaywallReason
    /// Pro 가 열린 순간. 시트는 스스로 닫힌다.
    var onUnlocked: (() -> Void)?

    private var pro: ProStore { .shared }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedID = ThinkFlowPro.yearlyID
    @State private var showsOtherTerms = false
    @State private var introEligible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    ProComparisonTable()
                    if pro.hasPro {
                        ownedNote
                    } else {
                        plans
                    }
                    footer
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .tint(.orange)
        .task {
            await pro.loadProducts()
            introEligible = await pro.product(ThinkFlowPro.yearlyID)?.subscription?.isEligibleForIntroOffer ?? false
        }
        .onChange(of: pro.hasPro) { _, unlocked in
            guard unlocked else { return }
            onUnlocked?()
            dismiss()
        }
    }

    // MARK: 머리말

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.orange.gradient)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
            Text("이어생각 Pro")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let line = reason.line {
                Text(line)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("생각을 마음껏 벌여 두고, 홈 화면에서 바로 이어 가세요. 연 구독이나 평생 중에 고르세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    // MARK: 고르기

    @ViewBuilder
    private var plans: some View {
        let yearly = pro.product(ThinkFlowPro.yearlyID)
        let lifetime = pro.product(ThinkFlowPro.lifetimeID)
        let monthly = pro.product(ThinkFlowPro.monthlyID)
        let weekly = pro.product(ThinkFlowPro.weeklyID)

        if yearly == nil && lifetime == nil && monthly == nil && weekly == nil {
            // 스토어에 상품이 아직 없으면 단추를 세우지 않는다 — 누를 수 없는 단추는 고장으로 읽힌다.
            VStack(spacing: 12) {
                if pro.isLoadingProducts {
                    ProgressView()
                } else {
                    Text("지금은 상품을 불러오지 못했어요. 잠시 뒤에 다시 시도해 주세요.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("다시 시도") { Task { await pro.loadProducts() } }
                        .font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
            VStack(spacing: 10) {
                if let yearly {
                    option(yearly, title: LeeoLadderText.yearly,
                           price: String(format: LeeoLadderText.perYearFormat, yearly.displayPrice),
                           note: introNote(yearly))
                }
                if let lifetime {
                    option(lifetime, title: LeeoLadderText.lifetime, price: lifetime.displayPrice,
                           note: lifetimeNote(lifetime, yearly: yearly))
                }
                if monthly != nil || weekly != nil {
                    otherTerms(monthly: monthly, weekly: weekly)
                }
            }
            buyButton
        }
    }

    @ViewBuilder
    private func otherTerms(monthly: Product?, weekly: Product?) -> some View {
        if showsOtherTerms {
            if let monthly {
                option(monthly, title: String(localized: "월 구독", comment: "Paywall: monthly subscription option"),
                       price: String(format: String(localized: "%@ / 월", comment: "Paywall: monthly price. %@ = price"),
                                     monthly.displayPrice),
                       note: nil)
            }
            if let weekly {
                option(weekly, title: String(localized: "주 구독", comment: "Paywall: weekly subscription option"),
                       price: String(format: String(localized: "%@ / 주", comment: "Paywall: weekly price. %@ = price"),
                                     weekly.displayPrice),
                       note: nil)
            }
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showsOtherTerms = true }
            } label: {
                Label("다른 기간 보기", systemImage: "chevron.down")
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private func option(_ product: Product, title: String, price: String, note: String?) -> some View {
        // 고른 상품을 아직 못 불러왔으면 대신 살 상품에 표시가 선다 (단추가 사는 것과 같게).
        let selected = selectedProduct?.id == product.id
        // 아주 큰 글자에서는 값을 이름 아래로 내린다. 옆에 두면 이름이 몇 글자 폭으로 꺾인다.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return Button {
            selectedID = product.id
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.orange : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    layout {
                        Text(title)
                            .font(.headline)
                        if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                        Text(price)
                            .font(.headline)
                            .monospacedDigit()
                    }
                    if let note {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .foregroundStyle(.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? Color.orange : .clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityInputLabels([Text(title)])
    }

    private var selectedProduct: Product? {
        pro.product(selectedID) ?? pro.product(ThinkFlowPro.yearlyID) ?? pro.product(ThinkFlowPro.lifetimeID)
    }

    private var buyButton: some View {
        let product = selectedProduct
        let title = product?.subscription != nil
            ? String(localized: "구독하기", comment: "Paywall: buy button for a subscription")
            : String(localized: "평생으로 구매하기", comment: "Paywall: buy button for the one-time lifetime purchase")
        return Button {
            guard let product else { return }
            Task { await pro.purchase(product, using: purchase) }
        } label: {
            ZStack {
                if pro.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.headline)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(.white)
            .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(product == nil || pro.isWorking)
        .accessibilityLabel(title)
    }

    private func introNote(_ yearly: Product) -> String? {
        guard introEligible, let offer = yearly.subscription?.introductoryOffer,
              offer.paymentMode == .payUpFront || offer.paymentMode == .payAsYouGo else { return nil }
        return String(format: LeeoLadderText.introFormat, offer.displayPrice)
    }

    private func lifetimeNote(_ lifetime: Product, yearly: Product?) -> String? {
        guard let yearly, yearly.price > 0 else { return nil }
        let years = Int(NSDecimalNumber(decimal: lifetime.price / yearly.price).doubleValue.rounded(.down))
        return years >= 2 ? String(format: LeeoLadderText.lifetimeWorthFormat, years) : nil
    }

    // MARK: 이미 Pro

    private var ownedNote: some View {
        VStack(spacing: 8) {
            Label("이어생각 Pro를 쓰고 있어요", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            if pro.isLegacy {
                Text("유료 기능이 생기기 전부터 써 주셔서, Pro를 평생 그대로 드려요.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: 아래

    private var footer: some View {
        VStack(spacing: 12) {
            if let message = pro.failureMessage, !pro.hasPro {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            if !pro.hasPro {
                Button {
                    Task { await pro.restore() }
                } label: {
                    Text("구매 복원")
                        .font(.body)
                        .frame(minHeight: 44)
                }
                .disabled(pro.isWorking)
            }
            Text("구독은 기간이 끝나기 24시간 전까지 해지하지 않으면 자동으로 갱신돼요. 결제는 Apple 계정으로 청구되고, 설정의 구독 관리에서 언제든 해지할 수 있어요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 20) {
                Link("이용약관", destination: ThinkFlowPro.termsURL)
                Link("개인정보처리방침", destination: ThinkFlowSpec.legal.privacyURL)
            }
            .font(.body)
        }
    }
}

// MARK: - 무료 · Pro 비교표

/// 페이월에 그대로 서는 표. 무엇이 무료로 남고 무엇이 Pro 인지 한눈에.
struct ProComparisonTable: View {

    private struct Row: Identifiable {
        let feature: String
        let free: Mark
        let pro: Mark
        var id: String { feature }
    }

    private enum Mark {
        case included, excluded
        case text(String)
    }

    private var rows: [Row] {
        [
            Row(feature: String(localized: "생각 수", comment: "Comparison table: number of thoughts"),
                free: .text(String(localized: "\(ThinkFlowPro.freeThreadLimit)개")),
                pro: .text(String(localized: "무제한", comment: "Comparison table: unlimited"))),
            Row(feature: String(localized: "끊어둔 문장 · 이어서 카드", comment: "Comparison table: bridge sentence and resume card"),
                free: .included, pro: .included),
            Row(feature: String(localized: "네 단계 다듬기", comment: "Comparison table: refining in four stages"),
                free: .included, pro: .included),
            Row(feature: String(localized: "자료 붙이기", comment: "Comparison table: attaching references"),
                free: .included, pro: .included),
            Row(feature: String(localized: "되살릴 생각 · 사고 시간", comment: "Comparison table: dormant thoughts and thinking time"),
                free: .included, pro: .included),
            Row(feature: String(localized: "생각 꺼내기", comment: "Comparison table: brain dump"),
                free: .included, pro: .included),
            Row(feature: String(localized: "마크다운 · JSON 내보내기", comment: "Comparison table: Markdown and JSON export"),
                free: .included, pro: .included),
            Row(feature: String(localized: "홈 화면 위젯", comment: "Comparison table: Home Screen widget"),
                free: .excluded, pro: .included),
            Row(feature: String(localized: "잠금 화면 · 다이내믹 아일랜드", comment: "Comparison table: Lock Screen and Dynamic Island"),
                free: .excluded, pro: .included),
        ]
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Text("무료", comment: "Comparison table column: free")
                    .font(.headline)
                    .gridColumnAlignment(.center)
                Text(verbatim: "Pro")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .gridColumnAlignment(.center)
            }
            .accessibilityHidden(true)
            ForEach(rows) { row in
                Divider().gridCellColumns(3)
                GridRow {
                    Text(row.feature)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    mark(row.free)
                    mark(row.pro)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(row.feature), \(spoken(row.free, tier: freeName)), \(spoken(row.pro, tier: "Pro"))"))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var freeName: String { String(localized: "무료", comment: "Comparison table column: free") }

    @ViewBuilder
    private func mark(_ mark: Mark) -> some View {
        switch mark {
        case .included:
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.orange)
        case .excluded:
            Image(systemName: "minus")
                .font(.body)
                .foregroundStyle(.tertiary)
        case .text(let text):
            Text(text)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
        }
    }

    /// VoiceOver 가 한 줄을 "생각, 무료 5개, Pro 무제한" 처럼 읽게.
    private func spoken(_ mark: Mark, tier: String) -> String {
        switch mark {
        case .included: String(localized: "\(tier) 포함", comment: "Comparison table, VoiceOver: included in this plan. %@ = plan name")
        case .excluded: String(localized: "\(tier) 없음", comment: "Comparison table, VoiceOver: not in this plan. %@ = plan name")
        case .text(let text): "\(tier) \(text)"
        }
    }
}

// MARK: - 설정의 Pro 칸

/// 설정 맨 위. 무료면 Pro 와 구매 복원, 구독 중이면 구독 관리와 '평생으로 바꾸기'.
struct ProSettingsSection: View {
    private var pro: ProStore { .shared }
    @State private var showsPaywall = false
    @State private var showsGraduation = false
    @State private var showsManage = false

    var body: some View {
        Section {
            if pro.hasPro {
                Label("이어생각 Pro를 쓰고 있어요", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.orange)
                if pro.isLegacy {
                    Text("유료 기능이 생기기 전부터 써 주셔서, Pro를 평생 그대로 드려요.")
                        .foregroundStyle(.secondary)
                }
                if pro.subscription != nil {
                    Button(LeeoLadderText.manageSubscription) { showsManage = true }
                    if !pro.ownsLifetime, pro.product(ThinkFlowPro.graduateID) != nil {
                        Button(LeeoLadderText.switchToLifetimeEntry) { showsGraduation = true }
                    }
                }
            } else {
                Button { showsPaywall = true } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("이어생각 Pro")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("생각 무제한 · 홈 화면 위젯 · 잠금 화면 생각 시간")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("구매 복원") { Task { await pro.restore() } }
                    .disabled(pro.isWorking)
            }
        } header: {
            Text("이어생각 Pro")
        } footer: {
            if let message = pro.failureMessage, !pro.hasPro {
                Text(message)
            }
        }
        .sheet(isPresented: $showsPaywall) {
            ProPaywallView(reason: .settings)
        }
        .sheet(isPresented: $showsGraduation) {
            ProGraduationSheet()
        }
        .manageSubscriptionsSheet(isPresented: $showsManage)
    }
}

// MARK: - 구독 졸업

/// 구독 중인 사람에게 평생을 졸업가로. 산 뒤에는 LeeoKit 화면이 구독 해지를 안내한다.
struct ProGraduationSheet: View {
    private var pro: ProStore { .shared }

    var body: some View {
        LeeoGraduationOfferView(graduate: pro.product(ThinkFlowPro.graduateID)) {
            await pro.didPurchaseElsewhere()
        }
        .tint(.orange)
    }
}
