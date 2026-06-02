import SwiftUI
import UIKit

struct ContinueThinkingSheet: View {

    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let thread: ThoughtThread

    @State private var newThought = ""
    @State private var phase: Phase = .thinking
    @State private var nextStartingPoint = ""
    @State private var sessionStart = Date()
    @FocusState private var isThoughtFocused: Bool
    @FocusState private var isNextFocused: Bool

    enum Phase { case thinking, bridging }

    private var hasThought: Bool {
        !newThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var hasNextPoint: Bool {
        !nextStartingPoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .thinking: thinkingPhase
                    case .bridging: bridgingPhase
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(phase == .thinking ? "이어서 생각하기" : "문장 끊어두기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // 입력이 없을 때만 그냥 닫기. 입력이 있으면 '다음'으로 문장을 끊어둬야 닫힌다.
                    if phase == .thinking && !hasThought {
                        Button("닫기") { dismiss() }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if phase == .thinking {
                        Button("다음") {
                            saveThought()
                            goToBridging()
                        }
                        .fontWeight(.semibold)
                        .disabled(!hasThought)
                    } else {
                        Button("완료") {
                            saveBridge()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(!hasNextPoint)
                    }
                }
            }
        }
        .interactiveDismissDisabled(hasThought || phase == .bridging)
        .onAppear {
            sessionStart = Date()
            store.startSession(threadID: thread.id)
            isThoughtFocused = true
        }
        .onDisappear {
            // 어떤 경로로 닫히든(완료/닫기/스와이프) 세션을 한 번만 마감
            store.endSession()
        }
    }

    // MARK: - Phase 1: 생각 쓰기 (재진입 맥락 복원 우선)

    private var thinkingPhase: some View {
        VStack(alignment: .leading, spacing: 14) {

            // 끊어둔 문장 — 가장 먼저, 가장 크게 (재진입 트리거)
            if !thread.bridge.nextQuestion.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("여기서 끊어뒀어요", systemImage: "arrow.turn.down.right")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    Text(thread.bridge.nextQuestion)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    HStack(spacing: 0) {
                        Color.orange.opacity(0.45)
                            .frame(width: 3)
                        Color.orange.opacity(0.07)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // 지금까지의 맥락 — 정제된 핵심 + 직전 생각 흐름
            if thread.lastEntry != nil {
                ThreadRecapView(thread: thread)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground).opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // 생각 쓰기
            VStack(alignment: .leading, spacing: 8) {
                Text("지금 이어지는 생각")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextEditor(text: $newThought)
                    .focused($isThoughtFocused)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .lineSpacing(4)
                    .accessibilityLabel("지금 이어지는 생각")

                HStack {
                    Spacer()
                    Text("\(newThought.count)자")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            sessionTimer
        }
    }

    // MARK: - Phase 2: 문장 끊어두기

    private var bridgingPhase: some View {
        VStack(alignment: .leading, spacing: 20) {

            // 닫기 불가 안내
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Text("문장을 끊어둬야 닫을 수 있어요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 안내
            VStack(alignment: .leading, spacing: 8) {
                Text("기세가 있을 때 끊어두세요")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("막혀서 멈추는 게 아니라, 아직 쓸 게 있을 때 여기서 끊어두세요.\n다음에 열면 뇌가 자동으로 이어받습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }

            // 미완성 문장 입력
            VStack(alignment: .leading, spacing: 8) {
                Label("이어질 문장 끊기", systemImage: "arrow.turn.down.right")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)

                TextEditor(text: $nextStartingPoint)
                    .focused($isNextFocused)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .lineSpacing(4)
                    .accessibilityLabel("이어질 문장 끊기")
                    .accessibilityHint("다음에 이어서 생각할 미완성 문장을 적습니다")

                if nextStartingPoint.isEmpty {
                    Text("예: \"숏폼이 뇌를 망치는 이유는 보상 주기 때문인데, 그렇다면—\"")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(.orange.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(hasNextPoint ? 0.3 : 0.1), lineWidth: 1.5)
            )
        }
        .onAppear { isNextFocused = true }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("사고 세션 진행 중")
    }

    // MARK: - Actions

    private func saveThought() {
        let trimmed = newThought.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addEntry(to: thread.id, content: trimmed)
    }

    private func goToBridging() {
        nextStartingPoint = thread.bridge.nextQuestion
        withAnimation(.easeInOut(duration: 0.25)) { phase = .bridging }
        UIAccessibility.post(
            notification: .screenChanged,
            argument: "문장 끊어두기 단계입니다. 다음에 이어갈 문장을 적으세요."
        )
    }

    private func saveBridge() {
        let point = nextStartingPoint.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateBridge(for: thread.id, nextQuestion: point)
        // 세션 마감은 onDisappear에서 일괄 처리
    }
}

#Preview {
    ContinueThinkingSheet(thread: ThoughtThread.sampleThreads[0])
        .environment(ThoughtStore())
}
