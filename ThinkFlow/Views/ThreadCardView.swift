import SwiftUI

struct ThreadCardView: View {

    let thread: ThoughtThread
    /// 가장 최근 스레드(히어로)일 때 "여기서 이어서" 헤더를 보여준다.
    var isResume: Bool = false
    var onContinue: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // "여기서 이어서" 헤더 (히어로 전용)
            if isResume {
                HStack {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("여기서 이어서")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(thread.bridge.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {

                // 제목 — 첫 생각 전체 (자르지 않음)
                HStack(alignment: .top, spacing: 8) {
                    Text(thread.emoji)
                        .font(.title2)
                    Text(thread.displayTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !isResume {
                        Spacer(minLength: 8)
                        Text(thread.lastVisitedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .layoutPriority(-1)
                    }
                }

                // 끊어둔 문장 — 재진입 트리거 (가장 중요)
                if !thread.bridge.nextQuestion.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("끊어둔 문장", systemImage: "arrow.turn.down.right")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                        Text(thread.bridge.nextQuestion)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        HStack(spacing: 0) {
                            Color.orange.opacity(0.4)
                                .frame(width: 3)
                            Color.orange.opacity(0.07)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("끊어둔 문장: \(thread.bridge.nextQuestion)")
                }

                // 지금까지의 흐름 — 핵심 + 직전 생각
                if thread.lastEntry != nil {
                    ThreadRecapView(thread: thread)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // 이어서 생각하기 버튼
                if let onContinue {
                    Button {
                        onContinue()
                    } label: {
                        HStack {
                            Image(systemName: "pencil.line")
                            Text("이어서 생각하기")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.orange.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("이어서 생각하기")
                    .accessibilityHint("\(thread.displayTitle)에 생각을 이어 적습니다")
                    .padding(.top, 4)
                }
            }
        }
        .padding(20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ThreadCardView(thread: ThoughtThread.sampleThreads[0], isResume: true, onContinue: {})
            ThreadCardView(thread: ThoughtThread.sampleThreads[1], onContinue: {})
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
