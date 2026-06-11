import XCTest
@testable import ThinkFlow

final class ThoughtModelTests: XCTestCase {

    // MARK: - 구버전 데이터 호환 (kind/source 없는 엔트리)

    func testEntryDecodingWithoutKindAndSourceFallsBackToThought() throws {
        let legacyJSON = """
        {
            "id": "\(UUID().uuidString)",
            "content": "옛날 메모",
            "layer": 1,
            "createdAt": 700000000
        }
        """
        let entry = try JSONDecoder().decode(ThoughtEntry.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(entry.kind, .thought)
        XCTAssertNil(entry.source)
        XCTAssertEqual(entry.content, "옛날 메모")
        XCTAssertEqual(entry.layer, 1)
    }

    func testEntryEncodeDecodeRoundTripPreservesReference() throws {
        let original = ThoughtEntry(content: "자료 내용", kind: .reference, source: "Claude")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThoughtEntry.self, from: data)
        XCTAssertEqual(decoded.kind, .reference)
        XCTAssertEqual(decoded.source, "Claude")
        XCTAssertTrue(decoded.isReference)
    }

    // MARK: - 스레드 통계는 자료(reference)를 제외해야 한다

    func testThreadStatisticsExcludeReferences() {
        let thread = ThoughtThread(
            title: "테스트",
            entries: [
                ThoughtEntry(content: "생각1", layer: 0),
                ThoughtEntry(content: "생각2", layer: 3),
                ThoughtEntry(content: "자료", layer: 0, kind: .reference, source: "검색"),
            ]
        )
        XCTAssertEqual(thread.entryCount, 2)
        XCTAssertEqual(thread.referenceCount, 1)
        XCTAssertEqual(thread.highestLayer, 3)
        // 진행도 평균에도 자료는 제외: (0 + 3) / 2 / 3
        XCTAssertEqual(thread.progressionRatio, 0.5, accuracy: 0.0001)
    }

    func testDistilledEntriesOnlyIncludeHighLayerThoughts() {
        let thread = ThoughtThread(
            title: "테스트",
            entries: [
                ThoughtEntry(content: "메모", layer: 0),
                ThoughtEntry(content: "핵심", layer: 2),
                ThoughtEntry(content: "자료인데 레이어 높음", layer: 3, kind: .reference),
            ]
        )
        XCTAssertEqual(thread.distilledEntries.map(\.content), ["핵심"])
        XCTAssertEqual(thread.latestCore?.content, "핵심")
    }

    // MARK: - 제목 추출

    func testExtractTitleTakesFirstSentence() {
        XCTAssertEqual(ThoughtStore.extractTitle(from: "첫 문장. 둘째 문장"), "첫 문장")
        XCTAssertEqual(ThoughtStore.extractTitle(from: "줄바꿈\n다음 줄"), "줄바꿈")
    }

    func testExtractTitleTruncatesAt24Characters() {
        let long = String(repeating: "가", count: 40)
        XCTAssertEqual(ThoughtStore.extractTitle(from: long).count, 24)
    }

    func testDisplayTitleRestoresTruncatedFirstSentence() {
        let fullSentence = "이것은 스물네 글자를 넘어가는 아주 긴 첫 문장입니다"
        let truncated = String(fullSentence.prefix(24))
        let thread = ThoughtThread(
            title: truncated,
            entries: [ThoughtEntry(content: fullSentence + ". 나머지")]
        )
        XCTAssertEqual(thread.displayTitle, fullSentence)
    }

    // MARK: - 내보내기

    func testMarkdownExportContainsCoreContent() {
        let thread = ThoughtThread(
            title: "수출 테스트",
            bridge: HemingwayBridge(nextQuestion: "여기서 이어가기"),
            entries: [
                ThoughtEntry(content: "본문 생각", layer: 2),
                ThoughtEntry(content: "붙인 자료", kind: .reference, source: "Claude"),
            ]
        )
        let dump = [DumpItem(content: "정리 안 된 생각")]
        let markdown = ThoughtExporter.markdown(threads: [thread], dumpItems: dump)

        XCTAssertTrue(markdown.contains("수출 테스트"))
        XCTAssertTrue(markdown.contains("여기서 이어가기"))
        XCTAssertTrue(markdown.contains("본문 생각"))
        XCTAssertTrue(markdown.contains("자료 · Claude"))
        XCTAssertTrue(markdown.contains("정리 안 된 생각"))
    }

    func testJSONExportRoundTrips() throws {
        let thread = ThoughtThread(title: "JSON", entries: [ThoughtEntry(content: "내용")])
        let data = try ThoughtExporter.jsonData(threads: [thread], dumpItems: [])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ThoughtExporter.ExportPayload.self, from: data)
        XCTAssertEqual(payload.threads.count, 1)
        XCTAssertEqual(payload.threads.first?.entries.first?.content, "내용")
    }
}
