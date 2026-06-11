import SwiftUI

@main
struct ThinkFlowApp: App {

    @State private var store = ThoughtStore()

    init() {
        CrashDiagnosticsCollector.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
        }
    }
}
