import Foundation
import SwiftUI

@Observable
final class ThoughtStore {
    
    var threads: [ThoughtThread] = []
    
    // 현재 사고 세션 타이머
    var activeThreadID: UUID?
    var sessionStartTime: Date?
    
    private let saveKey = "thought_threads_v1"
    
    init() {
        load()
        if threads.isEmpty {
            threads = ThoughtThread.sampleThreads
            save()
        }
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
    
    func updateBridge(for threadID: UUID, currentState: String, nextQuestion: String) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].bridge = HemingwayBridge(
            currentState: currentState,
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
    
    // MARK: - 사고 세션 타이머
    
    func startSession(threadID: UUID) {
        activeThreadID = threadID
        sessionStartTime = Date()
        
        // 방문 기록 갱신
        if let index = threads.firstIndex(where: { $0.id == threadID }) {
            threads[index].lastVisitedAt = Date()
            save()
        }
    }
    
    func endSession() {
        guard let threadID = activeThreadID,
              let startTime = sessionStartTime,
              let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        
        let elapsed = Int(Date().timeIntervalSince(startTime))
        threads[index].totalThinkingSeconds += elapsed
        threads[index].lastVisitedAt = Date()
        
        activeThreadID = nil
        sessionStartTime = nil
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(threads) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([ThoughtThread].self, from: data) else { return }
        threads = decoded
    }
}
