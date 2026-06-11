import ActivityKit
import Foundation

// MARK: - 사고 세션 라이브 액티비티 속성
// 앱(세션 시작/종료)과 위젯 익스텐션(표시)이 같은 타입을 컴파일해야 한다.
struct ThinkingSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var nextQuestion: String
    }

    var threadID: UUID
    var threadTitle: String
    var threadEmoji: String
    var sessionStartDate: Date
}
