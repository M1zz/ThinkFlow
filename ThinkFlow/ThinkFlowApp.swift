import SwiftUI
import LeeoKit

@main
struct ThinkFlowApp: App {

    /// 금고(bootstrap 안)가 예약된 복원을 먼저 적용한 뒤에 읽도록 init 에서 꺼낸다.
    @State private var store: ThoughtStore

    init() {
        // 백업 금고 · 사용량 기록 · 익명 사용 통계 · 크래시 진단 (FeedbackHub). 저장소보다 먼저 켠다.
        LeeoKit.bootstrap(ThinkFlowSpec.self)
        // 아래 수집기는 기기 안 보관용으로 그대로 둔다.
        CrashDiagnosticsCollector.shared.start()
        _store = State(initialValue: ThoughtStore.shared)
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                // 아이폰 듀오: 접힘을 재서 아래로 흘리고, 시트 · 알림창이 접힌 선을 비키게 한다.
                .foldAware()
                .leeoSatisfactionCheck(ThinkFlowSpec.self)
                .task { await ThinkFlowTip.tipJar.startStandalone() }
        }
    }
}
