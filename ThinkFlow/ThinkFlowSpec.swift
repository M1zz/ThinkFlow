import Foundation
import LeeoKit

enum ThinkFlowSpec: LeeoAppSpec {
    static let appName = "이어생각"
    static let developerEmail = "mizzking75@gmail.com"
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.leeo.thinkflow")

    /// 정책 링크 — docs/ (GitHub Pages) 의 privacy.html · index.html(지원).
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/ThinkFlow/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/ThinkFlow/")!
    )

    /// 인앱 결제 없음.
    static let monetization = LeeoMonetization.free

    /// 익명 사용 통계 → FeedbackHub. 없으면 bootstrap 이 스냅샷·app_open 을 건너뛴다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: ThinkFlowSpec.self)
}
