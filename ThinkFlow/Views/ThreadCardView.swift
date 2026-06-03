import SwiftUI

struct ThreadCardView: View {
    
    let thread: ThoughtThread
    var onContinue: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(thread.emoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(thread.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        metaChip("note.text", "\(thread.entryCount)개 메모")
                        metaChip("clock", thread.formattedThinkingTime)
                        if thread.daysSinceLastVisit > 0 {
                            metaChip("calendar", "\(thread.daysSinceLastVisit)일 전", highlighted: thread.daysSinceLastVisit >= 3)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                Spacer()

                // Progressive Summarization 진행도
                progressRing
            }

            // 끊어둔 문장 — 이어서 생각할 트리거 (가장 중요)
            if !thread.bridge.nextQuestion.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Label("끊어둔 문장", systemImage: "arrow.turn.down.right")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    Text(thread.bridge.nextQuestion)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    HStack(spacing: 0) {
                        Color.orange.opacity(0.4)
                            .frame(width: 3)
                        Color.orange.opacity(0.06)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("끊어둔 문장: \(thread.bridge.nextQuestion)")
            }

            // 정제된 핵심 — 한 줄 요약 (있을 때만)
            if let core = thread.latestCore {
                HStack(spacing: 6) {
                    LayerBadge(entry: core)
                    Text(core.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("핵심: \(core.content)")
            }

            // 빠른 이어쓰기 버튼
            if let onContinue {
                Button {
                    onContinue()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.line")
                            .font(.subheadline)
                        Text("이어서 생각하기")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.12))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("이어서 생각하기")
                .accessibilityHint("\(thread.title)에 생각을 이어 적습니다")
            }
        }
        .padding(18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }
    
    // MARK: - 메타 칩 (메모 수 · 사고 시간 · 경과일)
    private func metaChip(_ icon: String, _ text: String, highlighted: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(highlighted ? Color.orange : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((highlighted ? Color.orange : Color.secondary).opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - 진행도 링
    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(.gray.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: thread.progressionRatio)
                .stroke(.orange.gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("L\(thread.highestLayer)")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 38, minHeight: 38)
        .accessibilityElement()
        .accessibilityLabel("정리 깊이 레벨 \(thread.highestLayer)")
    }
}

#Preview {
    ThreadCardView(
        thread: ThoughtThread.sampleThreads[0],
        onContinue: {}
    )
    .padding()
}
