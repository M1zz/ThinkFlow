import SwiftUI
import UIKit
import PhotosUI

// MARK: - 나 혼자 쓰는 SNS 의 공통 부품
//
// 화면 전체가 같은 문법으로 선다: 왼쪽에 얼굴, 그 아래로 다음 글까지 이어지는 선, 오른쪽에 글.
// 카드 · 그림자 · 색 면은 쓰지 않는다. 주황은 '끊어둔 문장' 한 곳에만 남긴다.

enum PostMetrics {
    static let avatar: CGFloat = 36
    static let smallAvatar: CGFloat = 22
    static let gutter: CGFloat = 12
    static let side: CGFloat = 16
}

/// 글쓴이 얼굴. 내 생각은 그 스레드의 이모지, 붙여 둔 자료는 클립, 끊어둔 문장은 꺾인 화살표.
struct PostAvatar: View {
    enum Kind {
        case thought(String)
        case reference
        case bridge
    }

    let kind: Kind
    var size: CGFloat = PostMetrics.avatar

    var body: some View {
        ZStack {
            if case .bridge = kind {
                // 아직 올리지 않은 글 — 채우지 않고 점선으로
                Circle().strokeBorder(Color.orange.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
            } else {
                Circle().fill(fill)
            }
            switch kind {
            case .thought(let emoji):
                Text(emoji).font(.system(size: size * 0.5))
            case .reference:
                Image(systemName: "paperclip")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.teal)
            case .bridge:
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.orange)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        switch kind {
        case .thought: return Color(.secondarySystemBackground)
        case .reference: return Color.teal.opacity(0.14)
        case .bridge: return Color.orange.opacity(0.16)
        }
    }
}

/// 스레드의 한 줄. `connectsDown` 이면 얼굴 아래로 다음 줄까지 선을 잇는다.
struct PostRow<Avatar: View, Content: View>: View {
    var connectsDown = false
    var avatarSize: CGFloat = PostMetrics.avatar
    /// 아래 줄과의 간격. 주지 않으면 선이 이어질 때만 띄운다.
    var gap: CGFloat?
    @ViewBuilder var avatar: () -> Avatar
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: PostMetrics.gutter) {
            avatar()
                .frame(width: PostMetrics.avatar)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, gap ?? (connectsDown ? 16 : 0))
        .background(alignment: .topLeading) {
            if connectsDown {
                Capsule()
                    .fill(Color.primary.opacity(0.14))
                    .frame(width: 2)
                    .padding(.top, avatarSize + 5)
                    .padding(.bottom, 5)
                    .frame(width: PostMetrics.avatar)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// 답글의 이음선. 윗글의 얼굴 아래에서 내려와 이 글의 얼굴로 꺾여 들어오고,
/// 아래에 형제 답글(또는 큰 줄기의 다음 글)이 더 있으면 그 줄은 이 줄을 지나 계속 내려간다.
struct ThreadGuides: Shape {
    /// 한 단계 들여 쓰는 폭.
    static let step: CGFloat = 24
    /// 답글 얼굴 크기.
    static let avatar: CGFloat = 28

    let depth: Int
    /// 단계마다(0 ..< depth) 그 칸의 세로선이 이 줄을 지나 아래로 이어지는가.
    let guides: [Bool]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top: CGFloat = -5                   // 윗줄의 선 끝과 맞닿게
        let bottom = rect.height - 5
        for level in 0 ..< depth {
            let x = CGFloat(level) * Self.step + PostMetrics.avatar / 2
            if level < guides.count, guides[level] {
                path.move(to: CGPoint(x: x, y: top))
                path.addLine(to: CGPoint(x: x, y: bottom))
            }
            if level == depth - 1 {
                // 윗글에서 내려와 이 글의 얼굴 옆으로 꺾인다
                let centerY = Self.avatar / 2
                let radius: CGFloat = 8
                path.move(to: CGPoint(x: x, y: top))
                path.addLine(to: CGPoint(x: x, y: centerY - radius))
                path.addQuadCurve(to: CGPoint(x: x + radius, y: centerY),
                                  control: CGPoint(x: x, y: centerY))
                path.addLine(to: CGPoint(x: CGFloat(depth) * Self.step + 2, y: centerY))
            }
        }
        return path
    }
}

/// 글쓴이 이름과 올린 때. 이름을 주지 않으면 '나'.
struct PostAuthor: View {
    var name: String = String(localized: "나")
    var date: Date?

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let date {
                Text(date.postAge)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

extension Date {
    /// 글 옆에 붙는 짧은 나이 — "3시간 전". 방금 쓴 글이 '0초 후' 로 읽히지 않게 1초는 지난 것으로 본다.
    var postAge: String {
        min(self, Date().addingTimeInterval(-1))
            .formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
    }
}

/// 끊어둔 문장 — 스레드 끝에 놓인 쓰다 만 글. 누르면 이 문장에서 이어 쓴다.
struct BridgePost: View {
    var title: LocalizedStringKey = "끊어둔 문장"
    let text: String
    var connectsDown = false
    /// 다시 들어올 때 가장 먼저 읽혀야 하는 자리에서는 크게.
    var prominent = false

    var body: some View {
        PostRow(connectsDown: connectsDown, avatarSize: PostMetrics.smallAvatar) {
            PostAvatar(kind: .bridge, size: PostMetrics.smallAvatar)
        } content: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(text)
                    .font(prominent ? .title3 : .body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("끊어둔 문장: \(text)")
    }
}

/// 글 쓰는 칸. 상자 없이 글쓴이 줄 바로 아래에서 시작한다.
struct PostEditor: View {
    @Binding var text: String
    let placeholder: String
    var minHeight: CGFloat = 120
    var focus: FocusState<Bool>.Binding

    var body: some View {
        TextEditor(text: $text)
            .focused(focus)
            .scrollContentBackground(.hidden)
            .font(.body)
            .lineSpacing(4)
            .frame(minHeight: minHeight)
            // TextEditor 안쪽 여백만큼 당겨 글쓴이 이름과 왼쪽을 맞춘다
            .padding(.leading, -5)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

extension View {
    /// 화면에서 가장 중요한 단추 하나 — 검은 알약 (어두운 화면에서는 흰 알약).
    func postButtonStyle(enabled: Bool = true) -> some View {
        self
            .fontWeight(.semibold)
            .foregroundStyle(Color(.systemBackground))
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(Color.primary.opacity(enabled ? 1 : 0.25), in: Capsule())
    }
}

// MARK: - 글자 크기

/// 앱 안 글자 크기. 고르지 않으면 기기 설정을 따른다.
enum PostTextSize: Int, CaseIterable, Identifiable {
    case system, small, standard, large, larger

    static let key = "postTextSize"
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "기기 설정대로")
        case .small: return String(localized: "작게")
        case .standard: return String(localized: "보통")
        case .large: return String(localized: "크게")
        case .larger: return String(localized: "더 크게")
        }
    }

    fileprivate var dynamicType: DynamicTypeSize? {
        switch self {
        case .system: return nil
        case .small: return .small
        case .standard: return .large
        case .large: return .xLarge
        case .larger: return .xxxLarge
        }
    }
}

private struct PostTextSizeModifier: ViewModifier {
    @AppStorage(PostTextSize.key) private var choice = PostTextSize.system
    @Environment(\.dynamicTypeSize) private var systemSize

    func body(content: Content) -> some View {
        content.dynamicTypeSize(choice.dynamicType ?? systemSize)
    }
}

extension View {
    /// 설정에서 고른 글자 크기를 이 화면 아래 전부에 입힌다.
    func postTextSize() -> some View { modifier(PostTextSizeModifier()) }
}

// MARK: - 사진

/// 글에 붙은 사진들. 높이를 맞춰 옆으로 늘어놓고, 누르면 크게 본다.
struct PostPhotos: View {
    let names: [String]
    var height: CGFloat = 220
    /// 주면 사진마다 빼기 단추가 붙는다 (글 쓰는 중).
    var onRemove: ((String) -> Void)?

    @State private var shown: Shown?

    private struct Shown: Identifiable {
        let name: String
        var id: String { name }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(names, id: \.self) { name in
                    if let image = PhotoStore.image(named: name) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
                            .overlay(alignment: .topTrailing) {
                                if let onRemove {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) { onRemove(name) }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                            .padding(4)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("사진 삭제")
                                }
                            }
                            .onTapGesture { shown = Shown(name: name) }
                            .accessibilityLabel("사진")
                            .accessibilityAddTraits(.isImage)
                    }
                }
            }
        }
        .fullScreenCover(item: $shown) { photo in
            PhotoViewer(name: photo.name)
        }
    }
}

/// 사진 한 장을 화면 가득. 두 손가락으로 키우고, 두 번 누르면 원래대로.
private struct PhotoViewer: View {
    let name: String
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let image = PhotoStore.image(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom * pinch)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        MagnifyGesture()
                            .updating($pinch) { value, state, _ in state = value.magnification }
                            .onEnded { value in zoom = min(max(zoom * value.magnification, 1), 4) }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.2)) { zoom = zoom > 1 ? 1 : 2 }
                    }
                    .accessibilityLabel("사진")
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .padding(12)
            .accessibilityLabel("닫기")
        }
    }
}

/// 사진 고르기 단추. 고른 사진은 줄여서 저장하고 이름을 `photos` 에 더한다.
struct PhotoPickerButton: View {
    @Binding var photos: [String]
    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(selection: $picked, maxSelectionCount: 10, matching: .images) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 36, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("사진 추가")
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            Task {
                for item in items {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let name = PhotoStore.save(data) else { continue }
                    withAnimation(.easeInOut(duration: 0.2)) { photos.append(name) }
                }
            }
        }
    }
}

// MARK: - 스레드 공유

/// 스레드 하나를 글과 사진 그대로 다른 앱으로 보낸다.
struct ThreadShareButton: View {
    let thread: ThoughtThread
    @State private var payload: Payload?

    private struct Payload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    var body: some View {
        Button {
            let photos = thread.chronologicalEntries.flatMap(\.photos).map(PhotoStore.url(for:))
            payload = Payload(items: [ThoughtExporter.shareText(for: thread)] + photos)
        } label: {
            Image(systemName: "paperplane")
                .frame(minWidth: 28, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("공유")
        .sheet(item: $payload) { payload in
            ShareSheet(items: payload.items)
        }
    }
}

// MARK: - 피드의 글 하나 (스레드 하나)

/// 첫 생각 → 핵심 · 직전 생각 → 끊어둔 문장이 한 줄로 이어진 작은 스레드.
struct ThreadCardView: View {

    let thread: ThoughtThread
    var onContinue: (() -> Void)?

    private var root: ThoughtEntry? { thread.firstEntry }
    private var followUps: [ThoughtEntry] {
        thread.recapEntries.filter { $0.id != root?.id }
    }
    private var hasBridge: Bool { !thread.bridge.nextQuestion.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            PostRow(connectsDown: !followUps.isEmpty || hasBridge) {
                PostAvatar(kind: .thought(thread.emoji))
            } content: {
                VStack(alignment: .leading, spacing: 4) {
                    PostAuthor(date: thread.lastWrittenAt)
                    Text(root?.content ?? thread.displayTitle)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                    if let photos = root?.photos, !photos.isEmpty {
                        PostPhotos(names: photos, height: 170)
                            .padding(.top, 4)
                    }
                    actions
                        .padding(.top, 6)
                }
            }

            ForEach(followUps) { entry in
                PostRow(connectsDown: hasBridge || entry.id != followUps.last?.id,
                        avatarSize: PostMetrics.smallAvatar) {
                    PostAvatar(kind: .thought(thread.emoji), size: PostMetrics.smallAvatar)
                } content: {
                    followUp(entry)
                }
            }

            if hasBridge {
                if let onContinue {
                    Button(action: onContinue) {
                        BridgePost(text: thread.bridge.nextQuestion)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("\(thread.displayTitle)에 생각을 이어 적습니다")
                } else {
                    BridgePost(text: thread.bridge.nextQuestion)
                }
            }
        }
        .padding(.horizontal, PostMetrics.side)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    /// 핵심으로 추린 생각이나 직전 생각 — 다시 들어올 때 맥락을 되살린다.
    private func followUp(_ entry: ThoughtEntry) -> some View {
        let isLast = entry.id == thread.lastEntry?.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if entry.layer > 0 { LayerBadge(entry: entry) }
                if isLast {
                    Text("직전 생각")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.subheadline)
                    .foregroundStyle(entry.layer >= 2 ? .primary : .secondary)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            if !entry.photos.isEmpty {
                PostPhotos(names: entry.photos, height: 80)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isLast ? String(localized: "직전 생각") : entry.layerLabel): \(entry.content)")
    }

    /// 첫 생각에 이어 적은 생각의 수 — 첫 생각 자신은 세지 않는다.
    private var replies: Int { max(thread.entryCount - 1, 0) }

    /// 말풍선. 이어 적은 생각이 없으면 숫자 없이 단추만.
    private var replyLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "bubble.left")
            if replies > 0 {
                Text("\(replies)")
            }
        }
    }

    /// 글 아래 한 줄 — 답글(이어 적은 생각) · 공유 · 붙인 자료 · 쌓인 생각 시간.
    private var actions: some View {
        HStack(spacing: 18) {
            if let onContinue {
                Button(action: onContinue) {
                    replyLabel
                        .frame(minWidth: 28, minHeight: 28, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("이어서 생각하기")
                .accessibilityValue(replies > 0 ? String(localized: "\(replies)개 생각") : "")
                .accessibilityHint("\(thread.displayTitle)에 생각을 이어 적습니다")
            } else {
                replyLabel
                    .accessibilityLabel("\(replies)개 생각")
            }
            ThreadShareButton(thread: thread)
                .buttonStyle(.plain)
            if thread.referenceCount > 0 {
                Label("\(thread.referenceCount)", systemImage: "paperclip")
                    .accessibilityLabel(Text("자료") + Text(verbatim: " \(thread.referenceCount)"))
            }
            if thread.totalThinkingSeconds >= 60 {
                Label(thread.formattedThinkingTime, systemImage: "clock")
                    .accessibilityLabel("누적 \(thread.formattedThinkingTime)")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            ThreadCardView(thread: ThoughtThread.sampleThreads[0], onContinue: {})
            Divider()
            ThreadCardView(thread: ThoughtThread.sampleThreads[1], onContinue: {})
        }
    }
}
