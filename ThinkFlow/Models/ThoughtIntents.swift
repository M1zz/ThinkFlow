//
//  ThoughtIntents.swift
//  ThinkFlow
//
//  - "이어생각에 생각 던져 둬": 떠오른 것을 앱을 열지 않고 머릿속 비우기 목록에 넣는다.
//  - "이어생각 어디까지 했지": 가장 최근 생각과 끊어 둔 다음 질문을 읽어 준다. 다시 시작하는 문장이다.
//

import AppIntents
import Foundation

struct DumpThoughtIntent: AppIntent {
    static let title = LocalizedStringResource("생각 던져 두기", comment: "Siri: drop a thought into the brain dump list")
    static let description = IntentDescription(
        LocalizedStringResource("떠오른 생각을 머릿속 비우기 목록에 넣어 둡니다.", comment: "Siri: dump thought description")
    )

    @Parameter(title: LocalizedStringResource("생각", comment: "Siri: thought parameter"),
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
