import Foundation

// MARK: - 이어생각 Pro — 앱과 위젯이 함께 읽는 한 줄
//
// 위젯 익스텐션은 결제를 조회하지 않는다. 앱(`ProStore`)이 영수증을 읽고 그 답을
// App Group 에 한 줄로 적으면, 위젯과 라이브 액티비티는 그 한 줄만 본다.
// 이 파일은 앱 타겟과 위젯 타겟이 함께 컴파일한다.
//
// ⚠️ 이 한 줄은 거울이지 권한의 근거가 아니다. 앱은 켤 때마다 영수증을 다시 읽고 덮어쓴다.
enum ProAccess {
    static let appGroupID = "group.com.leeo.thinkflow"

    /// 잠긴 위젯을 누르면 가는 곳. 앱이 이 주소를 받으면 페이월을 연다.
    static let paywallURL = URL(string: "thinkflow://pro")!

    private static let key = "pro.featuresOpen"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    /// 홈 화면 위젯 · 잠금 화면 생각 시간을 보여도 되는가.
    ///
    /// 앱이 아직 한 번도 적지 않았으면 **연다** — 페이월이 들어오기 전부터 위젯을 쓰던 사람이
    /// 업데이트 뒤 앱을 열기 전까지 잠긴 위젯을 보지 않게.
    static var featuresOpen: Bool {
        defaults?.object(forKey: key) as? Bool ?? true
    }

    /// 앱만 부른다. 값이 바뀌었으면 true.
    @discardableResult
    static func setFeaturesOpen(_ open: Bool) -> Bool {
        guard let defaults, defaults.object(forKey: key) as? Bool != open else { return false }
        defaults.set(open, forKey: key)
        return true
    }
}
