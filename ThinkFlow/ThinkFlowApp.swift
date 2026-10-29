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
                .leeoSatisfactionCheck(ThinkFlowSpec.self)
                .task { await ThinkFlowTip.tipJar.startStandalone() }
        }
    }
}
