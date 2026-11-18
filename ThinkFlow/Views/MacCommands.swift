import SwiftUI

// 맥에서만 쓰는 것: 메뉴 막대 명령. 화면은 아이패드의 두 칸(목록 | 고른 생각)을 그대로 쓴다.

/// 지금 창이 "생각 꺼내기"를 할 수 있으면 그 동작. 메뉴 막대가 읽는다.
struct NewThoughtActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var newThought: (() -> Void)? {
        get { self[NewThoughtActionKey.self] }
        set { self[NewThoughtActionKey.self] = newValue }
    }
}

#if os(macOS)
/// 파일 ▸ 생각 꺼내기(⌘N). 새 창 대신 생각 꺼내기 — 이 앱은 창 하나로 쓴다.
struct ThinkFlowCommands: Commands {
    @FocusedValue(\.newThought) private var newThought

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("생각 꺼내기") { newThought?() }
                .keyboardShortcut("n")
                .disabled(newThought == nil)
        }
    }
}
#endif
