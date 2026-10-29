import Foundation
import LeeoKit

enum ThinkFlowSpec: LeeoAppSpec {
    static let appName = "이어생각"
    static let developerEmail = "leeo@kakao.com"
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.leeo.thinkflow")

    /// 정책 링크 — docs/ (GitHub Pages) 의 privacy.html · index.html(지원).
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/ThinkFlow/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/ThinkFlow/")!
    )

    /// 인앱 결제 없음.
    static let monetization = LeeoMonetization.free

    /// App Store 앱 ID — 리뷰 링크 · 친구에게 소개하기에 쓴다.
    static var appStoreID: String? { "6779270691" }

    /// 익명 사용 통계 → FeedbackHub. 없으면 bootstrap 이 스냅샷·app_open 을 건너뛴다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: ThinkFlowSpec.self)
}

// MARK: - 팁 (개발자 응원하기)

/// 무료 앱이라 LeeoStore 가 없다. 팁 엔진을 여기 하나 두고, 앱을 열 때 `startStandalone()` 을 부른다.
@MainActor
enum ThinkFlowTip {
    static let tipJar = LeeoTipJar(config: LeeoTipJarConfig(productIDs: [
        "com.leeo.thinkflow.tip.small",
        "com.leeo.thinkflow.tip.medium",
        "com.leeo.thinkflow.tip.large",
    ]))
}

/// 팁을 부탁할 만한 순간 — 지금까지 적어 온 **내 생각** 수(붙여 둔 자료는 빼고). 큰 것부터.
enum ThinkFlowTipMoments {
    static let thoughts = [300, 100, 30]

    static func reached(thoughtCount n: Int) -> [LeeoTipMoment] {
        thoughts.filter { n >= $0 }.map { threshold in
            LeeoTipMoment(id: "thoughts.\(threshold)",
                          message: String(localized: "지금까지 생각 \(n)개를 적었어요",
                                          comment: "Tip ask card: how many thoughts the person has written so far"))
        }
    }

    static func reachedNow(in threads: [ThoughtThread]) -> [LeeoTipMoment] {
        reached(thoughtCount: threads.reduce(0) { $0 + $1.entries.filter { !$0.isReference }.count })
    }
}
