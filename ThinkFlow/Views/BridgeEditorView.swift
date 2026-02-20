import SwiftUI

struct BridgeEditorView: View {
    
    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    let thread: ThoughtThread
    
    @State private var currentState: String = ""
    @State private var nextQuestion: String = ""
    @FocusState private var currentStateFocused: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 설명
                    VStack(alignment: .leading, spacing: 4) {
                        Text("헤밍웨이 브릿지")
                            .font(.headline)
                        Text("생각을 멈출 때 남기는 북마크입니다.\n다음에 열었을 때 바로 이어갈 수 있어요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 현재 상태
                    VStack(alignment: .leading, spacing: 8) {
                        Label("여기까지 왔어요", systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        
                        TextEditor(text: $currentState)
                            .focused($currentStateFocused)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .font(.subheadline)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(.blue.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.blue.opacity(0.1), lineWidth: 1)
                    )
                    
                    // 다음 질문
                    VStack(alignment: .leading, spacing: 8) {
                        Label("다음에 생각할 것", systemImage: "arrow.right.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                        
                        TextEditor(text: $nextQuestion)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .font(.subheadline)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(.orange.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.orange.opacity(0.1), lineWidth: 1)
                    )
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("브릿지 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        store.updateBridge(
                            for: thread.id,
                            currentState: currentState.trimmingCharacters(in: .whitespacesAndNewlines),
                            nextQuestion: nextQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                currentState = thread.bridge.currentState
                nextQuestion = thread.bridge.nextQuestion
                currentStateFocused = true
            }
        }
    }
}

#Preview {
    BridgeEditorView(thread: ThoughtThread.sampleThreads[0])
        .environment(ThoughtStore())
}
