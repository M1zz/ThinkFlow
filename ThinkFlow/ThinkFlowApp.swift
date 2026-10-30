import SwiftUI
import LeeoKit

@main
struct ThinkFlowApp: App {

    @State private var store = ThoughtStore()

    init() {
        CrashDiagnosticsCollector.shared.start()
        // 사용량 기록 · 익명 사용 통계 · 크래시 진단 (FeedbackHub). 위 수집기는 기기 안 보관용으로 그대로 둔다.
        LeeoKit.bootstrap(ThinkFlowSpec.self)
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
