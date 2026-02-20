import SwiftUI

struct ThreadCardView: View {
    
    let thread: ThoughtThread
    var onContinue: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(thread.emoji)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 12) {
                        Label("\(thread.entryCount)개 메모", systemImage: "note.text")
                        Label(thread.formattedThinkingTime, systemImage: "clock")
                        if thread.daysSinceLastVisit > 0 {
                            Label("\(thread.daysSinceLastVisit)일 전", systemImage: "calendar")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                // Progressive Summarization 진행도
                progressRing
            }
            
            // 다음 질문 미리보기
            if !thread.bridge.nextQuestion.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(thread.bridge.nextQuestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
            }
            
            // 빠른 이어쓰기 버튼
            if let onContinue {
                Button {
                    onContinue()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.line")
                            .font(.caption2)
                        Text("이어서 생각하기")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.12))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(width: 32, height: 32)
    }
}

#Preview {
    ThreadCardView(
        thread: ThoughtThread.sampleThreads[0],
        onContinue: {}
    )
    .padding()
}
