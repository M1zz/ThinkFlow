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
}
