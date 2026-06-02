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

                    HStack(spacing: 12) {
                        Label("\(thread.entryCount)개 메모", systemImage: "note.text")
                        Label(thread.formattedThinkingTime, systemImage: "clock")
                        if thread.daysSinceLastVisit > 0 {
                            Label("\(thread.daysSinceLastVisit)일 전", systemImage: "calendar")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Progressive Summarization 진행도
                progressRing
            }

            // 다음 질문 미리보기
            if !thread.bridge.nextQuestion.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    Text(thread.bridge.nextQuestion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.leading, 2)
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
