import XCTest
@testable import ThinkFlow

final class ThoughtStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ThoughtStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStore() -> ThoughtStore {
        ThoughtStore(defaults: defaults, sharedDefaults: nil)
    }

    // MARK: - 영속화

    func testSaveAndLoadRoundTrip() {
        let store = makeStore()
        let thread = ThoughtThread(
            title: "라운드트립",
            entries: [ThoughtEntry(content: "생각", layer: 1)]
        )
        store.addThread(thread)
        store.addDumpItems(["덤프 항목"])

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.threads.count, 1)
        XCTAssertEqual(reloaded.threads.first?.title, "라운드트립")
        XCTAssertEqual(reloaded.threads.first?.entries.first?.content, "생각")
        XCTAssertEqual(reloaded.dumpItems.map(\.content), ["덤프 항목"])
    }

    // MARK: - 손상 데이터는 덮어쓰지 않고 백업한다

    func testCorruptThreadDataIsPreservedInRecoveryKey() {
        let corrupt = Data("not valid json {{{".utf8)
        defaults.set(corrupt, forKey: "thought_threads_v1")

        let store = makeStore()
        XCTAssertTrue(store.threads.isEmpty)
        XCTAssertEqual(defaults.data(forKey: "thought_threads_v1_recovery"), corrupt)
    }

    func testCorruptDumpDataIsPreservedInRecoveryKey() {
        let corrupt = Data("broken".utf8)
        defaults.set(corrupt, forKey: "dump_items_v1")

        let store = makeStore()
        XCTAssertTrue(store.dumpItems.isEmpty)
        XCTAssertEqual(defaults.data(forKey: "dump_items_v1_recovery"), corrupt)
    }

    // MARK: - 덤프 → 스레드 승격

    func testPromoteDumpItemCreatesThreadAndRemovesDumpItem() {
        let store = makeStore()
        store.addDumpItems(["승격될 생각. 나머지 내용"])
        let item = store.dumpItems[0]

        let thread = store.promoteDumpItemToThread(id: item.id)

        XCTAssertEqual(thread?.title, "승격될 생각")
        XCTAssertEqual(store.threads.count, 1)
        XCTAssertTrue(store.dumpItems.isEmpty)
        XCTAssertEqual(store.threads.first?.entries.first?.content, "승격될 생각. 나머지 내용")
    }

    // MARK: - 레이어 승급은 0...3 으로 클램프

    func testUpdateEntryLayerClampsToValidRange() {
        let store = makeStore()
        let entry = ThoughtEntry(content: "생각")
        let thread = ThoughtThread(title: "클램프", entries: [entry])
        store.addThread(thread)

        store.updateEntryLayer(threadID: thread.id, entryID: entry.id, newLayer: 99)
        XCTAssertEqual(store.threads.first?.entries.first?.layer, 3)

        store.updateEntryLayer(threadID: thread.id, entryID: entry.id, newLayer: -5)
        XCTAssertEqual(store.threads.first?.entries.first?.layer, 0)
    }

    // MARK: - 자료 붙이기

    // MARK: - 답글 (어느 글에 달았는가)

    func testReplyKeepsItsParentAcrossSaveAndLoad() {
        let store = makeStore()
        let root = ThoughtEntry(content: "첫 생각")
        let thread = ThoughtThread(title: "답글", entries: [root])
        store.addThread(thread)
        store.addEntry(to: thread.id, content: "첫 생각에 단 답글", parentID: root.id)
        store.addEntry(to: thread.id, content: "큰 줄기에 이은 생각")

        let entries = makeStore().threads.first?.entries ?? []
        XCTAssertEqual(entries.first { $0.content == "첫 생각에 단 답글" }?.parentID, root.id)
        XCTAssertNil(entries.first { $0.content == "큰 줄기에 이은 생각" }?.parentID)
    }

    func testDeletingEntryMovesItsRepliesUpOneLevel() {
        let store = makeStore()
        let root = ThoughtEntry(content: "첫 생각")
        let reply = ThoughtEntry(content: "답글", parentID: root.id)
        let nested = ThoughtEntry(content: "답글의 답글", parentID: reply.id)
        let thread = ThoughtThread(title: "지우기", entries: [root, reply, nested])
        store.addThread(thread)

        store.deleteEntry(threadID: thread.id, entryID: reply.id)

        let entries = store.threads.first?.entries ?? []
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first { $0.id == nested.id }?.parentID, root.id)
    }

    func testPhotosStayOnTheEntryAcrossSaveAndLoad() {
        let store = makeStore()
        store.addThread(ThoughtThread(title: "사진"))
        let threadID = store.threads[0].id
        store.addEntry(to: threadID, content: "", photos: ["a.jpg", "b.jpg"])
        let entryID = store.threads[0].entries[0].id

        // 사진만 있는 글은 글을 비워도 남고, 사진까지 다 빼면 바뀌지 않는다
        store.updateEntryContent(threadID: threadID, entryID: entryID, content: "", photos: ["a.jpg"])
        store.updateEntryContent(threadID: threadID, entryID: entryID, content: " ", photos: [])

        let reloaded = ThoughtStore(defaults: defaults, sharedDefaults: nil)
        XCTAssertEqual(reloaded.threads[0].entries[0].photos, ["a.jpg"])
    }

    func testDumpPhotosFollowTheThoughtIntoItsThread() {
        let store = makeStore()
        store.addDumpItems(["첫 생각", "둘째 생각"], photos: ["a.jpg"])
        XCTAssertEqual(store.dumpItems.map(\.photos), [["a.jpg"], []])
        let thread = store.promoteDumpItemToThread(id: store.dumpItems[0].id)
        XCTAssertEqual(thread?.entries.first?.photos, ["a.jpg"])
    }

    func testShareTextKeepsRepliesUnderTheirParent() {
        let root = ThoughtEntry(content: "처음", createdAt: Date(timeIntervalSince1970: 1))
        let later = ThoughtEntry(content: "다음", createdAt: Date(timeIntervalSince1970: 2))
        let reply = ThoughtEntry(content: "답글", createdAt: Date(timeIntervalSince1970: 3), parentID: root.id)
        let thread = ThoughtThread(title: "제목", emoji: "🧠",
                                   bridge: HemingwayBridge(nextQuestion: ""),
                                   entries: [later, reply, root])
        XCTAssertEqual(ThoughtExporter.shareText(for: thread), "🧠 제목\n\n처음\n\n    ↳ 답글\n\n다음")
    }

    func testEntryWithoutParentFieldStillDecodes() throws {
        // 답글이 생기기 전에 저장된 데이터
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","content":"옛 생각","layer":0,"createdAt":0}"#
        let entry = try JSONDecoder().decode(ThoughtEntry.self, from: Data(json.utf8))
        XCTAssertNil(entry.parentID)
        XCTAssertEqual(entry.content, "옛 생각")
    }

    func testAddReferenceTrimsAndStoresSource() {
        let store = makeStore()
        let thread = ThoughtThread(title: "자료")
        store.addThread(thread)

        store.addReference(to: thread.id, content: "  내용  ", source: "  Claude  ")
        let entry = store.threads.first?.entries.first
        XCTAssertEqual(entry?.content, "내용")
        XCTAssertEqual(entry?.source, "Claude")
        XCTAssertEqual(entry?.kind, .reference)

        // 빈 내용은 무시
        store.addReference(to: thread.id, content: "   ", source: nil)
        XCTAssertEqual(store.threads.first?.entries.count, 1)
    }

    // MARK: - 세션 깊이 추적 (중첩 진입 시 시간이 한 번만 누적)

    func testNestedSessionCommitsOnlyOnce() {
        let store = makeStore()
        let thread = ThoughtThread(title: "세션")
        store.addThread(thread)

        store.startSession(threadID: thread.id)
        store.startSession(threadID: thread.id) // 상세 → 이어쓰기 시트 중첩 진입

        store.endSession()
        XCTAssertNotNil(store.activeThreadID, "중첩이 남아 있으면 세션은 유지된다")

        store.endSession()
        XCTAssertNil(store.activeThreadID)
        XCTAssertNil(store.sessionStartTime)
    }

    func testEndSessionWithoutStartIsNoOp() {
        let store = makeStore()
        store.endSession()
        XCTAssertNil(store.activeThreadID)
    }

    func testSwitchingThreadsCommitsPreviousSession() {
        let store = makeStore()
        let first = ThoughtThread(title: "첫째")
        let second = ThoughtThread(title: "둘째")
        store.addThread(first)
        store.addThread(second)

        store.startSession(threadID: first.id)
        store.startSession(threadID: second.id)

        XCTAssertEqual(store.activeThreadID, second.id)

        store.endSession()
        XCTAssertNil(store.activeThreadID)
    }
}
