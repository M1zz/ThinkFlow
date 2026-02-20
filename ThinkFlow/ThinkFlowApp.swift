import SwiftUI

@main
struct ThinkFlowApp: App {
    
    @State private var store = ThoughtStore()
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
        }
    }
}
