import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// 아이폰 · 아이패드 · Vision Pro(UIKit) 와 맥(AppKit)이 다른 곳은 여기 한 곳에 모은다.
// 화면 코드는 이 이름들만 쓰고 `#if` 를 달지 않는다.

// MARK: - 색

extension Color {
    /// 화면 바탕.
    static var appBackground: Color {
        #if canImport(UIKit)
        Color(.systemBackground)
        #else
        Color(nsColor: .textBackgroundColor)
        #endif
    }

    /// 바탕 위에 한 겹 올린 판(생각 카드, 입력칸).
    static var raisedBackground: Color {
        #if canImport(UIKit)
        Color(.secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// 묶음 목록의 바탕(결제 화면).
    static var groupedBackground: Color {
        #if canImport(UIKit)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// 묶음 목록 위의 칸.
    static var groupedRaised: Color {
        #if canImport(UIKit)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

// MARK: - 제목 줄 · 전체 화면

extension View {
    /// 작은 제목 줄. 맥 창에는 제목 크기가 하나뿐이라 아무것도 하지 않는다.
    func inlineNavigationTitle() -> some View {
        #if os(macOS)
        self
        #else
        navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// 아이폰에서는 화면을 덮고, 맥에서는 창 위에 시트로 띄운다.
    func coverOrSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(macOS)
        sheet(item: item, content: content)
        #else
        fullScreenCover(item: item, content: content)
        #endif
    }
}

// MARK: - 복사 · 읽어 주기

enum Clipboard {
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

enum Announce {
    /// VoiceOver 에 짧게 알린다.
    static func say(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}

// MARK: - 툴바 자리

extension ToolbarItemPlacement {
    /// 닫기 · 취소. 아이폰은 왼쪽 위, 맥은 시트 아래 취소 자리.
    static var barLeading: ToolbarItemPlacement {
        #if os(macOS)
        .cancellationAction
        #else
        .topBarLeading
        #endif
    }

    /// 저장 · 완료 · 다음. 아이폰은 오른쪽 위, 맥은 시트 아래 확인 자리.
    static var barConfirm: ToolbarItemPlacement {
        #if os(macOS)
        .confirmationAction
        #else
        .topBarTrailing
        #endif
    }

    /// 화면의 도구 단추(공유 · 설정 · 더 보기). 아이폰은 오른쪽 위, 맥은 창 툴바.
    static var barTrailing: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .topBarTrailing
        #endif
    }
}

// MARK: - 공유 · 내보내기

extension View {
    /// 글 · 사진을 다른 앱으로 보낸다. 아이폰은 공유 시트, 맥은 단추 옆에 공유 메뉴.
    func shareSheet<Item: Identifiable>(item: Binding<Item?>, items: @escaping (Item) -> [Any]) -> some View {
        #if os(macOS)
        background(SharingPickerAnchor(item: item, items: items))
        #else
        sheet(item: item) { ShareSheet(items: items($0)) }
        #endif
    }

    /// 백업 파일을 내보낸다. 아이폰은 공유 시트(파일에 저장 · AirDrop), 맥은 저장 위치를 고르는 창.
    func exportFile<Item: Identifiable>(item: Binding<Item?>, url: @escaping (Item) -> URL) -> some View {
        #if os(macOS)
        fileMover(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        ), file: item.wrappedValue.map(url)) { _ in item.wrappedValue = nil }
        #else
        sheet(item: item) { ShareSheet(items: [url($0)]) }
        #endif
    }
}

#if canImport(UIKit)
/// 시스템 공유 시트.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
/// 단추 뒤에 깔린 빈 판. 보낼 것이 생기면 그 자리에서 맥의 공유 메뉴를 연다.
private struct SharingPickerAnchor<Item: Identifiable>: NSViewRepresentable {
    @Binding var item: Item?
    let items: (Item) -> [Any]

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        guard let current = item else { return }
        DispatchQueue.main.async {
            item = nil
            NSSharingServicePicker(items: items(current))
                .show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
    }
}
#endif
