import SwiftUI

struct BridgeEditorView: View {

    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let thread: ThoughtThread

    @State private var nextStartingPoint = ""
    @FocusState private var isFocused: Bool

    private var hasContent: Bool {
        !nextStartingPoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text("끊어둔 문장 수정")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("기세가 있을 때 끊어둔 미완성 문장. 다음에 열면 뇌가 자동으로 이어받습니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("이어질 문장 끊기", systemImage: "arrow.turn.down.right")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)

                        TextEditor(text: $nextStartingPoint)
                            .focused($isFocused)
                            .frame(minHeight: 160)
                            .scrollContentBackground(.hidden)
                            .font(.body)
                            .lineSpacing(4)

                        if nextStartingPoint.isEmpty {
                            Text("예: \"숏폼이 뇌를 망치는 이유는 보상 주기 때문인데, 그렇다면—\"")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                        }
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange.opacity(hasContent ? 0.3 : 0.1), lineWidth: 1.5)
                    )

                    Spacer(minLength: 80)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("끊어둔 문장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.updateBridge(
                        for: thread.id,
                        nextQuestion: nextStartingPoint.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    dismiss()
                } label: {
                    Text("저장")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(hasContent ? Color.orange : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                .disabled(!hasContent)
                .background(.ultraThinMaterial)
            }
            .onAppear {
                nextStartingPoint = thread.bridge.nextQuestion
                isFocused = true
            }
        }
    }
}

#Preview {
    BridgeEditorView(thread: ThoughtThread.sampleThreads[0])
        .environment(ThoughtStore())
}
