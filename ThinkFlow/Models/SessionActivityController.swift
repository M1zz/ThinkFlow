import ActivityKit
import Foundation

// MARK: - 사고 세션 라이브 액티비티 관리
// 세션이 시작되면 잠금 화면·다이내믹 아일랜드에 타이머를 띄우고, 끝나면 내린다.
final class SessionActivityController {

    private var activity: Activity<ThinkingSessionAttributes>?

    func start(thread: ThoughtThread) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()

        let attributes = ThinkingSessionAttributes(
            threadID: thread.id,
            threadTitle: thread.displayTitle,
            threadEmoji: thread.emoji,
            sessionStartDate: Date()
        )
        let state = ThinkingSessionAttributes.ContentState(
            nextQuestion: thread.bridge.nextQuestion
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil)
        )
    }

    /// 앱이 세션 도중 강제 종료되면 라이브 액티비티가 주인 없이 남는다.
    /// 앱을 새로 띄울 때 그런 것들을 내린다 (새 세션은 이 뒤에 시작된다).
    func endOrphans() {
        let orphans = Activity<ThinkingSessionAttributes>.activities
        guard !orphans.isEmpty else { return }
        Task {
            for orphan in orphans {
                await orphan.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
