import Foundation
import SwiftUI
import WidgetKit

@Observable
final class ThoughtStore {

    var threads: [ThoughtThread] = []
    var dumpItems: [DumpItem] = []

    // 현재 사고 세션 타이머 (중첩 진입 대비 depth 카운팅)
    var activeThreadID: UUID?
    var sessionStartTime: Date?
    private var sessionDepth = 0

    private let saveKey = "thought_threads_v1"
    private let dumpSaveKey = "dump_items_v1"
    static let appGroupID = "group.com.leeo.thinkflow"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    init() {
        load()
        loadDumpItems()
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
    
    func addEntry(to threadID: UUID, content: String, layer: Int = 0) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        let entry = ThoughtEntry(content: content, layer: layer)
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

    func updateEntryContent(threadID: UUID, entryID: UUID, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let threadIndex = threads.firstIndex(where: { $0.id == threadID }),
              let entryIndex = threads[threadIndex].entries.firstIndex(where: { $0.id == entryID }) else { return }
        threads[threadIndex].entries[entryIndex].content = trimmed
        save()
    }

    func deleteEntry(threadID: UUID, entryID: UUID) {
        guard let threadIndex = threads.firstIndex(where: { $0.id == threadID }) else { return }
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
        }
        sessionDepth += 1

        // 방문 기록 갱신
        if let index = threads.firstIndex(where: { $0.id == threadID }) {
            threads[index].lastVisitedAt = Date()
            save()
        }
    }

    func endSession() {
        guard sessionDepth > 0 else { return }
        sessionDepth -= 1
        guard sessionDepth == 0 else { return }
        commitElapsed()
    }

    /// 현재 세션의 경과 시간을 누적하고 세션을 닫는다.
    private func commitElapsed() {
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

    func addDumpItems(_ contents: [String]) {
        let items = contents
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { DumpItem(content: $0) }
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
            entries: [ThoughtEntry(content: item.content)]
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
            UserDefaults.standard.set(data, forKey: saveKey)
            sharedDefaults?.set(data, forKey: saveKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func load() {
        let data = sharedDefaults?.data(forKey: saveKey)
                ?? UserDefaults.standard.data(forKey: saveKey)
        guard let data,
              let decoded = try? JSONDecoder().decode([ThoughtThread].self, from: data) else { return }
        threads = decoded
    }

    private func saveDumpItems() {
        if let data = try? JSONEncoder().encode(dumpItems) {
            UserDefaults.standard.set(data, forKey: dumpSaveKey)
        }
    }

    private func loadDumpItems() {
        guard let data = UserDefaults.standard.data(forKey: dumpSaveKey),
              let decoded = try? JSONDecoder().decode([DumpItem].self, from: data) else { return }
        dumpItems = decoded
    }
}
