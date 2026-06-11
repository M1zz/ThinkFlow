import Foundation

// MARK: - 전체 생각 내보내기 (백업·이동용)
// 모든 데이터가 기기 안에만 있으므로, 사용자가 직접 백업할 수단을 제공한다.
enum ThoughtExporter {

    struct ExportPayload: Codable {
        let exportedAt: Date
        let threads: [ThoughtThread]
        let dumpItems: [DumpItem]
    }

    // MARK: - Markdown

    static func markdown(threads: [ThoughtThread], dumpItems: [DumpItem]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyy년 M월 d일 HH:mm"

        var lines: [String] = []
        lines.append("# 이어생각 내보내기")
        lines.append("")
        lines.append("> 내보낸 시각: \(dateFormatter.string(from: Date()))")
        lines.append("")

        for thread in threads.sorted(by: { $0.lastVisitedAt > $1.lastVisitedAt }) {
            lines.append("## \(thread.emoji) \(thread.displayTitle)")
            lines.append("")
            lines.append("- 시작: \(dateFormatter.string(from: thread.createdAt))")
            lines.append("- 누적 사고 시간: \(thread.formattedThinkingTime)")
            lines.append("- 메모 \(thread.entryCount)개 · 자료 \(thread.referenceCount)개")
            if !thread.bridge.nextQuestion.isEmpty {
                lines.append("")
                lines.append("**끊어둔 문장:** \(thread.bridge.nextQuestion)")
            }
            lines.append("")
            for entry in thread.chronologicalEntries {
                let badge: String
                if entry.isReference {
                    let source = entry.source.map { " · \($0)" } ?? ""
                    badge = "자료\(source)"
                } else {
                    badge = entry.layerLabel
                }
                lines.append("- **[\(badge)]** (\(dateFormatter.string(from: entry.createdAt)))")
                lines.append("")
                // 여러 줄 내용을 목록 안에 들여쓰기로 유지
                for contentLine in entry.content.components(separatedBy: "\n") {
                    lines.append("  \(contentLine)")
                }
                lines.append("")
            }
        }

        if !dumpItems.isEmpty {
            lines.append("## 💭 아직 정리 안 된 생각")
            lines.append("")
            for item in dumpItems {
                lines.append("- \(item.content) (\(dateFormatter.string(from: item.createdAt)))")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - JSON

    static func jsonData(threads: [ThoughtThread], dumpItems: [DumpItem]) throws -> Data {
        let payload = ExportPayload(exportedAt: Date(), threads: threads, dumpItems: dumpItems)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    // MARK: - 임시 파일 생성 (공유 시트용)

    static func writeTemporaryFile(named fileName: String, contents: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThoughtExport", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        try contents.write(to: url, options: .atomic)
        return url
    }

    /// 파일명에 쓸 날짜 문자열 (예: 2026-06-11)
    static func fileDateStamp(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
