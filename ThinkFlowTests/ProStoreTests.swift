import XCTest
import StoreKit
import StoreKitTest
import LeeoKit
@testable import ThinkFlow

/// 이어생각 Pro — 무료 한도 · 기존 사용자 기준 · StoreKit 설정 파일로 사 보기.
final class ProStoreTests: XCTestCase {

    // MARK: - 무료 한도

    func testFreeUserCanStartUpToFiveThoughts() {
        for count in 0..<ThinkFlowPro.freeThreadLimit {
            XCTAssertTrue(ThinkFlowPro.mayStartThread(existing: count, hasPro: false, isSelling: true))
        }
        XCTAssertFalse(ThinkFlowPro.mayStartThread(existing: 5, hasPro: false, isSelling: true))
        XCTAssertFalse(ThinkFlowPro.mayStartThread(existing: 9, hasPro: false, isSelling: true))
    }

    func testProIsUnlimited() {
        XCTAssertTrue(ThinkFlowPro.mayStartThread(existing: 100, hasPro: true, isSelling: true))
    }

    /// 상품이 스토어에 서기 전에 나간 빌드는 막지 않는다 — 살 수 없는데 막히면 안 된다.
    func testNothingIsLockedBeforeProductsExist() {
        XCTAssertTrue(ThinkFlowPro.mayStartThread(existing: 100, hasPro: false, isSelling: false))
    }

    // MARK: - 페이월 전에 받은 사람

    func testBuildsUpToTheLastFreeOneKeepPro() {
        XCTAssertTrue(ThinkFlowPro.isBeforePaywall(originalAppVersion: "1"))
        XCTAssertTrue(ThinkFlowPro.isBeforePaywall(originalAppVersion: "5"))
        XCTAssertFalse(ThinkFlowPro.isBeforePaywall(originalAppVersion: "6"))
        XCTAssertFalse(ThinkFlowPro.isBeforePaywall(originalAppVersion: ""))
    }

    // MARK: - 상품

    /// 팁은 아무것도 열지 않는다.
    func testTipsNeverUnlockPro() {
        XCTAssertTrue(ThinkFlowPro.entitlementIDs.isDisjoint(with: ThinkFlowPro.tipIDs))
        XCTAssertTrue(Set(ThinkFlowPro.soldIDs).isDisjoint(with: ThinkFlowPro.tipIDs))
    }

    func testContractAuditHasNoErrors() {
        let errors = LeeoPreflight.audit(ThinkFlowSpec.self).filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty, "\(errors)")
    }

    // MARK: - StoreKit 설정 파일로 사 보기

    private func makeSession() throws -> SKTestSession {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ThinkFlow/ThinkFlow.storekit")
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    func testEveryProductIsInTheStoreKitFile() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let ids = Set(ThinkFlowPro.soldIDs + ThinkFlowPro.tipIDs)
        let products = try await Product.products(for: ids)
        XCTAssertEqual(Set(products.map(\.id)), ids)

        let yearly = try XCTUnwrap(products.first { $0.id == ThinkFlowPro.yearlyID })
        XCTAssertNotNil(yearly.subscription?.introductoryOffer, "연 구독 첫 해 반값")
        let groups = Set(products.compactMap { $0.subscription?.subscriptionGroupID })
        XCTAssertEqual(groups.count, 1, "주 · 월 · 연은 한 구독 그룹")
    }

    /// 결제 창 없이 세션이 바로 산다 — 권한 판정만 본다.
    @MainActor
    func testBuyingYearlyOpensPro() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let store = LeeoStore(config: try XCTUnwrap(ThinkFlowSpec.paywall))
        _ = try await session.buyProduct(identifier: ThinkFlowPro.yearlyID)
        await store.refreshEntitlements()
        XCTAssertTrue(store.hasPro)
    }

    @MainActor
    func testBuyingATipOpensNothing() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let store = LeeoStore(config: try XCTUnwrap(ThinkFlowSpec.paywall))
        _ = try await session.buyProduct(identifier: ThinkFlowPro.tipIDs[0])
        await store.refreshEntitlements()
        XCTAssertFalse(store.hasPro)
    }
}
