import SwiftUI

struct NewThreadSheet: View {
    
    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var emoji = "💭"
    @State private var firstThought = ""
    @State private var nextQuestion = ""
    @FocusState private var titleFocused: Bool
    
    private let emojiOptions = ["💭", "🧠", "💡", "🚀", "📚", "🎯", "🔬", "🎨", "⚡", "🌱", "🔮", "🏗️"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 이모지 선택
                    VStack(alignment: .leading, spacing: 8) {
                        Text("아이콘")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(emojiOptions, id: \.self) { option in
                                Button {
                                    emoji = option
                                } label: {
                                    Text(option)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(emoji == option ? Color.orange.opacity(0.2) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(emoji == option ? Color.orange : Color.clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // 제목
                    VStack(alignment: .leading, spacing: 8) {
                        Text("생각의 제목")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        TextField("예: 1인 개발자 성장 전략", text: $title)
                            .focused($titleFocused)
                            .font(.body)
                            .textFieldStyle(.plain)
                    }
                    .padding(16)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // 첫 번째 생각 (선택)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("첫 번째 생각")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("선택사항")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        TextEditor(text: $firstThought)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .font(.body)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // 다음에 생각할 것 (선택)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("다음에 생각할 것", systemImage: "arrow.right.circle.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                            Spacer()
                            Text("선택사항")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        TextField("예: 이 아이디어가 실현 가능한지 검증할 방법은?", text: $nextQuestion, axis: .vertical)
                            .lineLimit(2...4)
                            .font(.body)
                            .textFieldStyle(.plain)
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
            .navigationTitle("새로운 생각")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("만들기") {
                        createThread()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                titleFocused = true
            }
        }
    }
    
    private func createThread() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        var entries: [ThoughtEntry] = []
        let trimmedThought = firstThought.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedThought.isEmpty {
            entries.append(ThoughtEntry(content: trimmedThought))
        }
        
        let bridge = HemingwayBridge(
            currentState: trimmedThought.isEmpty ? "" : "첫 생각을 기록함",
            nextQuestion: nextQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        let thread = ThoughtThread(
            title: trimmedTitle,
            emoji: emoji,
            bridge: bridge,
            entries: entries
        )
        
        store.addThread(thread)
        dismiss()
    }
}

#Preview {
    NewThreadSheet()
        .environment(ThoughtStore())
}
