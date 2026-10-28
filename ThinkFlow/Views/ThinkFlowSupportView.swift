import SwiftUI
import LeeoKit

struct ThinkFlowSupportView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    // 앞으로 만들 기능 — 원본은 ThinkFlowRoadmap.swift
                    NavigationLink(LeeoRoadmapText.entry) { RoadmapScreen() }
                    LeeoShareAppLink<ThinkFlowSpec>()
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
