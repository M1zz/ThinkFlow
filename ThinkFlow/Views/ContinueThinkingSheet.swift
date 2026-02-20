import SwiftUI

struct ContinueThinkingSheet: View {
    
    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    let thread: ThoughtThread
    
    @State private var newThought = ""
    @State private var phase: Phase = .thinking
    @State private var newCurrentState = ""
    @State private var newNextQuestion = ""
    @State private var sessionStart = Date()
    @FocusState private var isThoughtFocused: Bool
    @FocusState private var isCurrentStateFocused: Bool
    @FocusState private var isNextQuestionFocused: Bool
    
    enum Phase {
        case thinking    // 생각 쓰기
        case bridging    // 브릿지 업데이트
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    switch phase {
                    case .thinking:
                        thinkingPhase
                    case .bridging:
                        bridgingPhase
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(phase == .thinking ? "생각 이어가기" : "북마크 남기기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") {
                        saveAndDismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if phase == .thinking {
                        Button("다음") {
                            saveThought()
                            prepareForBridging()
                        }
                        .fontWeight(.semibold)
                        .disabled(newThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button("완료") {
                            saveBridge()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            sessionStart = Date()
            store.startSession(threadID: thread.id)
            isThoughtFocused = true
        }
        .interactiveDismissDisabled(!newThought.isEmpty)
    }
    
    // MARK: - Phase 1: 생각 쓰기
    private var thinkingPhase: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 컨텍스트 리마인더 (어디서 이어가는지)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(thread.emoji)
                    Text(thread.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                if !thread.bridge.nextQuestion.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("이어서 생각할 것", systemImage: "arrow.right.circle.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                        Text(thread.bridge.nextQuestion)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                if !thread.bridge.currentState.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("지난번 여기까지", systemImage: "mappin.circle.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        Text(thread.bridge.currentState)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(16)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // 생각 쓰기 영역
            VStack(alignment: .leading, spacing: 8) {
                Text("지금 떠오르는 생각")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $newThought)
                    .focused($isThoughtFocused)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .lineSpacing(4)
                
                HStack {
                    Spacer()
                    Text("\(newThought.count)자")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // 세션 타이머
            sessionTimer
        }
    }
    
    // MARK: - Phase 2: 브릿지 업데이트
    private var bridgingPhase: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 설명
            VStack(alignment: .leading, spacing: 6) {
                Text("사고의 북마크를 남겨주세요")
                    .font(.headline)
                Text("다음에 이 생각을 열었을 때 바로 이어갈 수 있도록,\n지금 어디까지 왔는지와 다음에 생각할 것을 남겨두세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            
            // 현재 상태
            VStack(alignment: .leading, spacing: 8) {
                Label("여기까지 왔어요", systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                
                TextEditor(text: $newCurrentState)
                    .focused($isCurrentStateFocused)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .font(.subheadline)
                    .lineSpacing(3)
                
                if newCurrentState.isEmpty {
                    Text("예: \"보상 지연 시간과 주의력의 관계까지 정리함\"")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
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
                
                TextEditor(text: $newNextQuestion)
                    .focused($isNextQuestionFocused)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .font(.subheadline)
                    .lineSpacing(3)
                
                if newNextQuestion.isEmpty {
                    Text("예: \"의도적 지루함을 설계하면 깊은 사고가 회복될까?\"")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(16)
            .background(.orange.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.orange.opacity(0.1), lineWidth: 1)
            )
            
            // 스킵 버튼
            Button {
                dismiss()
            } label: {
                Text("나중에 할게요")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - 세션 타이머
    private var sessionTimer: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.purple.opacity(0.5))
            Text(sessionStart, style: .timer)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text("생각 중...")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // MARK: - Actions
    
    private func saveThought() {
        let trimmed = newThought.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addEntry(to: thread.id, content: trimmed)
    }
    
    private func prepareForBridging() {
        newCurrentState = thread.bridge.currentState
        newNextQuestion = thread.bridge.nextQuestion
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .bridging
        }
        isCurrentStateFocused = true
    }
    
    private func saveBridge() {
        let state = newCurrentState.trimmingCharacters(in: .whitespacesAndNewlines)
        let question = newNextQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !state.isEmpty || !question.isEmpty {
            store.updateBridge(for: thread.id, currentState: state, nextQuestion: question)
        }
        store.endSession()
    }
    
    private func saveAndDismiss() {
        let trimmed = newThought.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            store.addEntry(to: thread.id, content: trimmed)
        }
        store.endSession()
        dismiss()
    }
}

#Preview {
    ContinueThinkingSheet(thread: ThoughtThread.sampleThreads[0])
        .environment(ThoughtStore())
}
