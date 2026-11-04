//
//  ThoughtIntents.swift
//  ThinkFlow
//
//  - "이어생각에 생각 던져 둬": 떠오른 것을 앱을 열지 않고 머릿속 비우기 목록에 넣는다.
//  - "이어생각 어디까지 했지": 가장 최근 생각과 끊어 둔 다음 질문을 읽어 준다. 다시 시작하는 문장이다.
//  - 생각(스레드)마다 Spotlight 에 색인한다. Siri 가 앱 이름 없이도 찾고, 누르면 그 생각이 열린다.
//    색인(IndexedEntity)은 iOS 18 부터라 그 부분만 나눠 둔다.
//

import AppIntents
import CoreSpotlight
import Foundation

struct DumpThoughtIntent: AppIntent {
    static let title = LocalizedStringResource("생각 던져 두기", comment: "Siri: drop a thought into the brain dump list")
    static let description = IntentDescription(
        LocalizedStringResource("떠오른 생각을 머릿속 비우기 목록에 넣어 둡니다.", comment: "Siri: dump thought description")
    )

    @Parameter(title: LocalizedStringResource("생각", comment: "Siri: thought parameter"),
               description: LocalizedStringResource("머릿속 비우기 목록에 넣을 생각의 내용", comment: "Siri: thought parameter description"),
               requestValueDialog: IntentDialog(LocalizedStringResource("무슨 생각이에요?", comment: "Siri: ask for the thought")))
    var thought: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        ThoughtStore.shared.addDumpItems([thought])
        return .result(dialog: IntentDialog(LocalizedStringResource("던져 뒀어요. 나중에 이어서 생각해요.", comment: "Siri: thought saved")))
    }
}

struct ResumeThoughtIntent: AppIntent {
    static let title = LocalizedStringResource("어디까지 했지", comment: "Siri: where did I leave off thinking")
    static let description = IntentDescription(
        LocalizedStringResource("가장 최근 생각과 끊어 둔 다음 질문을 읽어 줍니다.", comment: "Siri: resume thought description")
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let thread = ThoughtStore.shared.threads.max(by: { $0.lastVisitedAt < $1.lastVisitedAt }) else {
            return .result(dialog: IntentDialog(LocalizedStringResource("아직 이어 갈 생각이 없어요.", comment: "Siri: no threads yet")))
        }
        let next = thread.bridge.nextQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.isEmpty else {
            return .result(dialog: IntentDialog(LocalizedStringResource("‘\(thread.title)’에서 멈췄어요.", comment: "Siri: last thread without a next question. Argument is the title")))
        }
        return .result(dialog: IntentDialog(LocalizedStringResource("‘\(thread.title)’에서 멈췄어요. 다음 질문은 ‘\(next)’예요.", comment: "Siri: last thread and its next question. Arguments: title, question")))
    }
}

// MARK: - 생각 (스레드)

struct ThoughtEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("생각", comment: "Siri/Spotlight: one thought thread")
    )
    static let defaultQuery = ThoughtQuery()

    let id: UUID
    let title: String
    let emoji: String
    /// 끊어 둔 다음 질문. 비어 있을 수 있다.
    let nextQuestion: String
    /// 적어 둔 생각과 붙여 둔 자료. 검색 · 색인에 쓴다.
    let text: String

    init(_ thread: ThoughtThread) {
        id = thread.id
        title = thread.title
        emoji = thread.emoji
        nextQuestion = thread.bridge.nextQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        text = thread.entries.map(\.content).joined(separator: "\n")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: "\(emoji) \(title)"),
            subtitle: nextQuestion.isEmpty ? nil : LocalizedStringResource(stringLiteral: nextQuestion)
        )
    }

    /// 최근에 들른 생각부터.
    @MainActor
    static func all() -> [ThoughtEntity] {
        ThoughtStore.shared.threads
            .sorted { $0.lastVisitedAt > $1.lastVisitedAt }
            .map(ThoughtEntity.init)
    }

    /// Spotlight 색인을 지금 생각 목록으로 새로 만든다. 앱을 열 때 · 뒤로 보낼 때 부른다.
    @MainActor
    static func reindex() async {
        guard #available(iOS 18.0, *) else { return }
        let entities = all()
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: ThoughtEntity.self)
        try? await index.indexAppEntities(entities)
    }
}

@available(iOS 18.0, *)
extension ThoughtEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.textContent = [nextQuestion, text].filter { !$0.isEmpty }.joined(separator: "\n")
        return set
    }
}

struct ThoughtQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ThoughtEntity] {
        let wanted = Set(identifiers)
        return ThoughtEntity.all().filter { wanted.contains($0.id) }
    }

    /// 제목 · 다음 질문 · 적어 둔 내용에서 찾는다(대소문자 · 악센트 무시).
    @MainActor
    func entities(matching string: String) async throws -> [ThoughtEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        func matches(_ s: String) -> Bool { s.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        return ThoughtEntity.all().filter { matches($0.title) || matches($0.nextQuestion) || matches($0.text) }
    }

    @MainActor
    func suggestedEntities() async throws -> [ThoughtEntity] {
        Array(ThoughtEntity.all().prefix(20))
    }
}

/// 생각을 연다. Spotlight · Siri 결과를 누르면 여기로 온다.
struct OpenThoughtIntent: OpenIntent {
    static let title = LocalizedStringResource("생각 열기", comment: "Siri/Spotlight: open a thought thread")
    static let description = IntentDescription(
        LocalizedStringResource("고른 생각을 열어 이어서 생각합니다.", comment: "Siri: open thought description")
    )

    @Parameter(title: LocalizedStringResource("생각", comment: "Siri: thought thread parameter"),
               description: LocalizedStringResource("열어 볼 생각", comment: "Siri: thought thread parameter description"))
    var target: ThoughtEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        ThoughtStore.shared.openRequestID = target.id
        return .result()
    }
}

// MARK: - Siri 문구

struct ThinkFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DumpThoughtIntent(),
            phrases: ["Drop a thought in \(.applicationName)", "Brain dump in \(.applicationName)"],
            shortTitle: "Drop a Thought",
            systemImageName: "tray.and.arrow.down"
        )
        AppShortcut(
            intent: ResumeThoughtIntent(),
            phrases: ["Where did I leave off in \(.applicationName)", "Resume thinking in \(.applicationName)"],
            shortTitle: "Where I Left Off",
            systemImageName: "arrow.uturn.forward"
        )
    }
}
