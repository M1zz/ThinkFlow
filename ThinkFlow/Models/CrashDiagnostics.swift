import Foundation
import MetricKit

// MARK: - 크래시·행 진단 수집 (외부 SDK 없이 MetricKit 사용)
// 진단 페이로드를 앱 컨테이너의 Application Support/Diagnostics 에 JSON으로 남긴다.
// 문제 제보를 받으면 Xcode > Devices and Simulators 에서 컨테이너를 내려받아 확인한다.
final class CrashDiagnosticsCollector: NSObject, MXMetricManagerSubscriber {

    static let shared = CrashDiagnosticsCollector()

    private let maxStoredFiles = 20

    private var directory: URL? {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
    }

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for payload in payloads {
            let stamp = Int(payload.timeStampEnd.timeIntervalSince1970)
            let url = directory.appendingPathComponent("diagnostic-\(stamp).json")
            try? payload.jsonRepresentation().write(to: url, options: .atomic)
        }
        pruneOldFiles(in: directory)
    }

    private func pruneOldFiles(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }
        let sorted = files.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for url in sorted.dropFirst(maxStoredFiles) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
