import ActivityKit
import WidgetKit
import SwiftUI

// 속성 정의는 앱 타겟과 공유하는 ThinkFlow/Models/ThinkingSessionAttributes.swift 에 있다.

// MARK: - Live Activity Widget

struct ThinkingSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ThinkingSessionAttributes.self) { context in
            // 잠금 화면 / 배너 UI
            lockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Text(context.attributes.threadEmoji)
                            .font(.title3)
                        Text(context.attributes.threadTitle)
                            .font(.caption)
                            .fontWeight(.bold)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(context.attributes.sessionStartDate, style: .timer)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "brain")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.state.nextQuestion.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("지금 생각할 것", systemImage: "arrow.right.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.orange)
                            Text(context.state.nextQuestion)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 4)
                    }
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Text(context.attributes.threadEmoji)
                        .font(.caption2)
                    Image(systemName: "brain")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            } compactTrailing: {
                Text(context.attributes.sessionStartDate, style: .timer)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            } minimal: {
                Image(systemName: "brain")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "thinkflow://continue?threadId=\(context.attributes.threadID.uuidString)"))
            .keylineTint(.orange)
        }
    }

    // MARK: - 잠금 화면 뷰

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<ThinkingSessionAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Text(context.attributes.threadEmoji)
                        .font(.title3)
                    Text(context.attributes.threadTitle)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                Spacer()

                // 타이머
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(context.attributes.sessionStartDate, style: .timer)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
            }

            if !context.state.nextQuestion.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Label("지금 생각할 것", systemImage: "arrow.right.circle.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    Text(context.state.nextQuestion)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
    }
}

// MARK: - Preview

extension ThinkingSessionAttributes {
    fileprivate static var preview: ThinkingSessionAttributes {
        ThinkingSessionAttributes(
            threadID: UUID(),
            threadTitle: "숏폼 vs 딥워크",
            threadEmoji: "🧠",
            sessionStartDate: Date()
        )
    }
}

extension ThinkingSessionAttributes.ContentState {
    fileprivate static var thinking: ThinkingSessionAttributes.ContentState {
        ThinkingSessionAttributes.ContentState(
            nextQuestion: "의도적 지루함을 설계하면 깊은 사고가 회복될까?"
        )
    }
}

#Preview("Notification", as: .content, using: ThinkingSessionAttributes.preview) {
    ThinkingSessionLiveActivity()
} contentStates: {
    ThinkingSessionAttributes.ContentState.thinking
}
