import SwiftUI
import LeeoKit

struct ThinkFlowSupportView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LeeoSupportSection<ThinkFlowSpec>()
                } header: {
                    Text("지원")
                }
            }
            .navigationTitle("설정")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
