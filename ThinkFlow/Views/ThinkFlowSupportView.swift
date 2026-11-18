import SwiftUI
import LeeoKit

struct ThinkFlowSupportView: View {
    @AppStorage(PostTextSize.key) private var textSize = PostTextSize.system
    @State private var proSheet: ProSettingsSheet?

    var body: some View {
        NavigationStack {
            List {
                ProSettingsSection(sheet: $proSheet)
                Section {
                    Picker("글자 크기", selection: $textSize) {
                        ForEach(PostTextSize.allCases) { size in
                            Text(size.label).tag(size)
                        }
                    }
                }
                Section {
                    // 앞으로 만들 기능 — 원본은 ThinkFlowRoadmap.swift
                    NavigationLink(LeeoRoadmapText.entry) { RoadmapScreen() }
                    LeeoShareAppLink<ThinkFlowSpec>()
                    LeeoTipJarLink<ThinkFlowSpec>(tipJar: ThinkFlowTip.tipJar)
                    LeeoSupportSection<ThinkFlowSpec>()
                } header: {
                    Text("지원")
                }
            }
            .proSettingsSheets($proSheet)
            .navigationTitle("설정")
            .inlineNavigationTitle()
        }
    }
}
