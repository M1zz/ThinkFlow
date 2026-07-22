import SwiftUI
import LeeoKit

@main
struct ThinkFlowApp: App {

    @State private var store = ThoughtStore()

    init() {
        CrashDiagnosticsCollector.shared.start()
        LeeoEngagement.shared.registerLaunch()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .leeoSatisfactionCheck(ThinkFlowSpec.self)
        }
    }
}
