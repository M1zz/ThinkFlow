import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import WidgetKit

@Observable
final class ThoughtStore {
    /// 앱 화면과 Siri 인텐트가 같은 저장소를 쓴다 (→ ThoughtIntents.swift).
    @MainActor static let shared: ThoughtStore = {
        let store = ThoughtStore()
        store.sweepPhotos()
        return store
    }()

    var threads: [ThoughtThread] = []
    var dumpItems: [DumpItem] = []
    /// Siri · Spotlight 에서 고른 생각. HomeView 가 열고 비운다 (→ OpenThoughtIntent).
    var openRequestID: UUID?

    // 현재 사고 세션 타이머 (중첩 진입 대비 depth 카운팅)
    var activeThreadID: UUID?
    var sessionStartTime: Date?
    private var sessionDepth = 0

    private let saveKey = "thought_threads_v1"
    private let dumpSaveKey = "dump_items_v1"
    // 디코딩에 실패한 원본을 보존하는 키 — 다음 save()가 사용자 데이터를 덮어쓰지 않도록
    private let recoveryKey = "thought_threads_v1_recovery"
    private let dumpRecoveryKey = "dump_items_v1_recovery"
    static let appGroupID = "group.com.leeo.thinkflow"

    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?
    private let sessionActivity = SessionActivityController()
    /// 저장된 글을 온전히 읽었는가 — 못 읽었으면 사진을 치우지 않는다.
    private var loadedCleanly = true

    init(
        defaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = UserDefaults(suiteName: ThoughtStore.appGroupID)
    ) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
        load()
        loadDumpItems()
        sessionActivity.endOrphans()
        #if DEBUG
        if let seed = ScreenshotScene.seed {
            threads = seed.threads
            dumpItems = seed.dumpItems
            save()
            saveDumpItems()
        }
        #endif
    }
    
    // MARK: - 가장 최근 방문한 스레드 (앱 열자마자 보여줄 것)
    var mostRecentThread: ThoughtThread? {
        threads.sorted { $0.lastVisitedAt > $1.lastVisitedAt }.first
    }
    
    // MARK: - 오래 방치된 스레드 (되살릴 생각들)
    var dormantThreads: [ThoughtThread] {
        threads.filter { $0.daysSinceLastVisit >= 3 }
              .sorted { $0.daysSinceLastVisit > $1.daysSinceLastVisit }
    }
    
    // MARK: - 활발한 스레드
    var activeThreads: [ThoughtThread] {
        threads.filter { $0.daysSinceLastVisit < 3 }
              .sorted { $0.lastVisitedAt > $1.lastVisitedAt }
    }
    
    // MARK: - CRUD
    
    func addThread(_ thread: ThoughtThread) {
        threads.insert(thread, at: 0)
        save()
    }
    
    func deleteThread(id: UUID) {
        threads.removeAll { $0.id == id }
        save()
    }
    
    func updateThread(_ thread: ThoughtThread) {
        if let index = threads.firstIndex(where: { $0.id == thread.id }) {
            threads[index] = thread
            save()
        }
    }
    
    // MARK: - 생각 이어가기 (핵심 기능)
    
    /// `parentID` 를 주면 그 글에 단 답글이 된다. 없으면 스레드의 큰 줄기에 이어진다.
    func addEntry(to threadID: UUID, content: String, layer: Int = 0, parentID: UUID? = nil, photos: [String] = []) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        let entry = ThoughtEntry(content: content, layer: layer, parentID: parentID, photos: photos)
        threads[index].entries.append(entry)
        threads[index].lastVisitedAt = Date()
        save()
    }
    
    /// 조사 결과·자료를 스레드에 붙인다 (예: Claude에게 물어본 결과 정리).
    func addReference(to threadID: UUID, content: String, source: String? = nil, parentID: UUID? = nil) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty,
              let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        let trimmedSource = source?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = ThoughtEntry(
            content: trimmedContent,
            kind: .reference,
            source: (trimmedSource?.isEmpty ?? true) ? nil : trimmedSource,
            parentID: parentID
        )
        threads[index].entries.append(entry)
        threads[index].lastVisitedAt = Date()
        save()
    }

    func updateBridge(for threadID: UUID, nextQuestion: String) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].bridge = HemingwayBridge(
            nextQuestion: nextQuestion,
            updatedAt: Date()
        )
        threads[index].lastVisitedAt = Date()
        save()
    }
    
    func updateEntryLayer(threadID: UUID, entryID: UUID, newLayer: Int) {
        guard let threadIndex = threads.firstIndex(where: { $0.id == threadID }),
              let entryIndex = threads[threadIndex].entries.firstIndex(where: { $0.id == entryID }) else { return }
        threads[threadIndex].entries[entryIndex].layer = min(3, max(0, newLayer))
        save()
    }

    /// `photos` 를 주면 붙은 사진도 함께 바꾼다. 글도 사진도 없는 글로는 바꾸지 않는다.
    func updateEntryContent(threadID: UUID, entryID: UUID, content: String, photos: [String]? = nil) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let threadIndex = threads.firstIndex(where: { $0.id == threadID }),
              let entryIndex = threads[threadIndex].entries.firstIndex(where: { $0.id == entryID }) else { return }
        let newPhotos = photos ?? threads[threadIndex].entries[entryIndex].photos
        guard !trimmed.isEmpty || !newPhotos.isEmpty else { return }
        threads[threadIndex].entries[entryIndex].content = trimmed
        threads[threadIndex].entries[entryIndex].photos = newPhotos
        save()
    }

    func deleteEntry(threadID: UUID, entryID: UUID) {
        guard let threadIndex = threads.firstIndex(where: { $0.id == threadID }),
              let removed = threads[threadIndex].entries.first(where: { $0.id == entryID }) else { return }
        // 지운 글에 달린 답글은 버리지 않고 한 칸 위(지운 글이 답하던 글)로 올려 붙인다.
        for index in threads[threadIndex].entries.indices
        where threads[threadIndex].entries[index].parentID == entryID {
            threads[threadIndex].entries[index].parentID = removed.parentID
        }
        threads[threadIndex].entries.removeAll { $0.id == entryID }
        save()
    }
    
    // MARK: - 사고 세션 타이머
    
    /// 사고 세션 시작. 상세 화면 → 이어쓰기 시트처럼 중첩 진입해도
    /// 하나의 세션으로 묶여 시간이 한 번만 누적된다.
    func startSession(threadID: UUID) {
        // 다른 스레드의 세션이 열려 있으면 먼저 마감
        if let active = activeThreadID, active != threadID, sessionDepth > 0 {
            commitElapsed()
            sessionDepth = 0
        }

        if sessionDepth == 0 {
            activeThreadID = threadID
            sessionStartTime = Date()
            if let thread = threads.first(where: { $0.id == threadID }) {
                sessionActivity.start(thread: thread)
            }
        }
        sessionDepth += 1

        // 방문 기록 갱신
        if let index = threads.firstIndex(where: { $0.id == threadID }) {
            threads[index].lastVisitedAt = Date()
            save()
        }
    }

    /// 세션 도중 Pro 가 열렸다 — 지금 세션을 잠금 화면에 띄운다(시작 시각 그대로).
    func showSessionActivity() {
        guard sessionDepth > 0, let threadID = activeThreadID,
              let thread = threads.first(where: { $0.id == threadID }) else { return }
        sessionActivity.start(thread: thread, startedAt: sessionStartTime ?? Date())
    }

    func endSession() {
        guard sessionDepth > 0 else { return }
        sessionDepth -= 1
        guard sessionDepth == 0 else { return }
        commitElapsed()
    }

    /// 현재 세션의 경과 시간을 누적하고 세션을 닫는다.
    private func commitElapsed() {
        sessionActivity.end()
        guard let threadID = activeThreadID,
              let startTime = sessionStartTime,
              let index = threads.firstIndex(where: { $0.id == threadID }) else {
            activeThreadID = nil
            sessionStartTime = nil
            return
        }

        let elapsed = Int(Date().timeIntervalSince(startTime))
        threads[index].totalThinkingSeconds += elapsed
        threads[index].lastVisitedAt = Date()

        activeThreadID = nil
        sessionStartTime = nil
        save()
    }
    
    // MARK: - 덤프 CRUD

    /// `photos` 는 첫 생각에 붙는다.
    func addDumpItems(_ contents: [String], photos: [String] = []) {
        var items = contents
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { DumpItem(content: $0) }
        if !items.isEmpty { items[0].photos = photos }
        dumpItems.append(contentsOf: items)
        saveDumpItems()
    }

    func deleteDumpItem(id: UUID) {
        dumpItems.removeAll { $0.id == id }
        saveDumpItems()
    }

    @discardableResult
    func promoteDumpItemToThread(id: UUID) -> ThoughtThread? {
        guard let item = dumpItems.first(where: { $0.id == id }) else { return nil }
        let title = Self.extractTitle(from: item.content)
        let thread = ThoughtThread(
            title: title.isEmpty ? item.content : title,
            entries: [ThoughtEntry(content: item.content, photos: item.photos)]
        )
        addThread(thread)
        dumpItems.removeAll { $0.id == id }
        saveDumpItems()
        return thread
    }

    static func extractTitle(from content: String) -> String {
        let sentence = content
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return sentence.count > 24 ? String(sentence.prefix(24)) : sentence
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(threads) {
            defaults.set(data, forKey: saveKey)
            sharedDefaults?.set(data, forKey: saveKey)
        }
        #if !os(visionOS)   // visionOS 2 에는 위젯이 없다 — 위젯 확장은 iOS 에만 묶여 있다
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func load() {
        let data = sharedDefaults?.data(forKey: saveKey)
                ?? defaults.data(forKey: saveKey)
        guard let data else { return }
        if let decoded = try? JSONDecoder().decode([ThoughtThread].self, from: data) {
            threads = decoded
        } else {
            // 깨진 데이터를 보존해 두면 빈 상태로 시작해도 복구 여지가 남는다
            defaults.set(data, forKey: recoveryKey)
            loadedCleanly = false
        }
    }

    private func saveDumpItems() {
        if let data = try? JSONEncoder().encode(dumpItems) {
            defaults.set(data, forKey: dumpSaveKey)
        }
    }

    private func loadDumpItems() {
        guard let data = defaults.data(forKey: dumpSaveKey) else { return }
        if let decoded = try? JSONDecoder().decode([DumpItem].self, from: data) {
            dumpItems = decoded
        } else {
            defaults.set(data, forKey: dumpRecoveryKey)
            loadedCleanly = false
        }
    }

    // MARK: - 사진 정리

    /// 어느 글에도 붙어 있지 않은 사진 파일을 지운다 — 지운 글의 사진, 올리지 않고 닫은 글의 사진.
    /// 글을 지울 때마다 따라 지우지 않고 앱을 열 때 한 번에 치운다.
    func sweepPhotos() {
        guard loadedCleanly else { return }
        let used = threads.flatMap { $0.entries.flatMap(\.photos) } + dumpItems.flatMap(\.photos)
        PhotoStore.sweep(keeping: Set(used))
    }
}

// MARK: - 사진 보관

/// 글에 붙인 사진은 위젯과 함께 쓰는 공유 폴더에 파일로 둔다 (백업 금고가 이 폴더를 통째로 담는다).
/// 글에는 파일 이름만 적는다.
enum PhotoStore {

    /// 긴 변 한도 — 화면에서 크게 보기에 넉넉하고 저장 공간은 아낀다.
    private static let maxSide: CGFloat = 2000

    static let directory: URL = {
        let fm = FileManager.default
        let base = fm.containerURL(forSecurityApplicationGroupIdentifier: ThoughtStore.appGroupID)
            ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Photos", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static let cache = NSCache<NSString, CGImage>()

    static func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// 고른 사진을 줄여서 저장하고 파일 이름을 돌려준다.
    /// ImageIO 로 줄이므로 아이폰과 맥이 같은 길을 쓴다. 사진의 방향(EXIF)은 줄이면서 픽셀에 입힌다.
    static func save(_ data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        guard let resized = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let name = UUID().uuidString + ".jpg"
        guard let destination = CGImageDestinationCreateWithURL(
            url(for: name) as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, resized,
                                   [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? name : nil
    }

    static func image(named name: String) -> CGImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let source = CGImageSourceCreateWithURL(url(for: name) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func sweep(keeping used: Set<String>) {
        let fm = FileManager.default
        for name in (try? fm.contentsOfDirectory(atPath: directory.path)) ?? [] where !used.contains(name) {
            try? fm.removeItem(at: url(for: name))
        }
    }
}
#if DEBUG
// MARK: - 스토어 스크린샷 전용 장면

/// 스토어 스크린샷 전용 — 디버그 빌드에만 있다. `scripts/take_screenshots.sh` 가 실행 인자로 넘긴다.
///
///   -ScreenshotSeed <json 경로>               생각·덤프 데이터를 이 파일 내용으로 바꿔 넣는다
///   -ScreenshotScene home|continue|bridge|thread|dump   그 화면을 바로 연다
///
/// 입력칸에 미리 적어 둘 글(draft · bridgeDraft · dumpText)도 같은 JSON 에 둔다.
/// 실행 인자로 글을 넘기면 괄호로 시작하는 글이 배열로 읽히는 등 망가지기 때문이다.
enum ScreenshotScene {

    struct Seed: Decodable {
        var threads: [ThoughtThread]
        var dumpItems: [DumpItem]
        var draft: String?
        var bridgeDraft: String?
        var dumpText: String?
    }

    static let scene: String? = UserDefaults.standard.string(forKey: "ScreenshotScene")

    static let seed: Seed? = {
        guard let path = UserDefaults.standard.string(forKey: "ScreenshotSeed"),
              let data = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(Seed.self, from: data)
    }()
}
#endif
