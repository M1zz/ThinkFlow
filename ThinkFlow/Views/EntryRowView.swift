import SwiftUI

struct EntryRowView: View {

    let entry: ThoughtEntry
    /// 이 글이 속한 스레드의 이모지 — 내 생각의 얼굴로 쓴다.
    var emoji: String = "💭"
    /// 아래에 이어지는 글이 있으면 얼굴 아래로 선을 잇는다.
    var connectsDown = false
    /// 어느 글에 단 답글인가 — 깊이만큼 들여 쓰고 윗글에서 내려오는 선을 잇는다 (→ ThreadGuides).
    var depth = 0
    var guides: [Bool] = []
    /// 이 글에 바로 달린 답글 수.
    var replyCount = 0
    /// 이 글에 답글 달기.
    var onReply: (() -> Void)?
    var onLayerChange: ((Int) -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var copied = false

    // 레이어(Progressive Summarization) 메타데이터
    static let layerNames = [String(localized: "메모"), String(localized: "정리"), String(localized: "핵심"), String(localized: "요약")]
    static let layerHints = [String(localized: "날것의 생각"), String(localized: "한 번 정리함"), String(localized: "핵심만 추림"), String(localized: "최종 요약")]

    private func accent(for layer: Int) -> Color {
        switch layer {
        case 1: return .blue
        case 2: return .purple
        case 3: return .orange
        default: return .gray.opacity(0.5)
        }
    }

    // 자료(조사 결과)는 생각과 시각적으로 구분되는 청록색을 쓴다.
    private var rowAccent: Color {
        entry.isReference ? .teal : accent(for: entry.layer)
    }

    /// 내 생각은 '나', 붙여 둔 자료는 그 출처가 글쓴이다 — 내 스레드에 달린 남의 답글처럼 읽힌다.
    private var authorName: String {
        entry.isReference ? (entry.source ?? String(localized: "자료")) : String(localized: "나")
    }

    private var avatarSize: CGFloat {
        depth == 0 ? PostMetrics.avatar : ThreadGuides.avatar
    }

    var body: some View {
        PostRow(connectsDown: connectsDown, avatarSize: avatarSize, gap: 16) {
            PostAvatar(kind: entry.isReference ? .reference : .thought(emoji), size: avatarSize)
        } content: {
            VStack(alignment: .leading, spacing: 6) {

                // 글쓴이 줄 — 이름 · 정리 단계(자료는 자료 표시) · 올린 때
                HStack(spacing: 6) {
                    PostAuthor(name: authorName)
                    // 기본 단계(메모)는 딱지를 붙이지 않는다 — 그냥 이어지는 생각이다
                    if !entry.isReference {
                        if entry.layer > 0 { layerBadge }
                    } else if entry.source != nil {
                        referenceBadge
                    }
                    Text(entry.createdAt.postAge)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityLabel(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Spacer(minLength: 0)
                }

                // 내용 — 사진만 올린 글이면 글 줄은 없다
                if !entry.content.isEmpty {
                    Text(entry.content)
                        .font(.body)
                        .foregroundStyle(entry.isReference ? .secondary : .primary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !entry.photos.isEmpty {
                    PostPhotos(names: entry.photos)
                }

                // 글 아래 한 줄 — 답글 · 정리 단계 · 수정 · 복사
                HStack(spacing: 22) {
                    Button {
                        onReply?()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "bubble.left")
                            if replyCount > 0 {
                                Text("\(replyCount)")
                            }
                        }
                        .frame(minWidth: 28, minHeight: 28, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("이어서 생각하기")
                    .accessibilityValue(replyCount > 0 ? String(localized: "\(replyCount)개 생각") : "")

                    if !entry.isReference {
                        layerMenu {
                            Image(systemName: "square.stack.3d.up")
                                .frame(minWidth: 28, minHeight: 28, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                    }

                    Button {
                        onEdit?()
                    } label: {
                        Image(systemName: "pencil")
                            .frame(minWidth: 28, minHeight: 28, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("수정")

                    Button {
                        Clipboard.copy(entry.content)
                        Announce.say(String(localized: "복사되었습니다"))
                        withAnimation(.spring(duration: 0.2)) { copied = true }
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation { copied = false }
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copied ? Color.green : Color.secondary)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(minWidth: 28, minHeight: 28, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("복사")
                    .accessibilityHint(entry.isReference ? String(localized: "이 자료를 클립보드에 복사합니다") : String(localized: "이 생각을 클립보드에 복사합니다"))
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, CGFloat(depth) * ThreadGuides.step)
        .background(alignment: .topLeading) {
            if depth > 0 {
                ThreadGuides(depth: depth, guides: guides)
                    .stroke(Color.primary.opacity(0.14), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onEdit?()
            } label: {
                Label("수정", systemImage: "pencil")
            }
            Button {
                Clipboard.copy(entry.content)
            } label: {
                Label("복사", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    // MARK: - 레이어 승급 배지

    private var layerBadge: some View {
        layerMenu {
            HStack(spacing: 4) {
                Circle()
                    .fill(rowAccent)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text(entry.layerLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(rowAccent)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(rowAccent.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    /// 정리 단계를 고르는 메뉴. 딱지(올린 단계)와 글 아래 아이콘이 같은 메뉴를 연다.
    private func layerMenu<L: View>(@ViewBuilder label: () -> L) -> some View {
        Menu {
            Text("정리 단계")
            ForEach(Self.layerNames.indices, id: \.self) { lvl in
                Button {
                    onLayerChange?(lvl)
                    Announce.say(String(localized: "\(Self.layerNames[lvl]) 단계로 변경됨")
                    )
                } label: {
                    if entry.layer == lvl {
                        Label("\(Self.layerNames[lvl]) · \(Self.layerHints[lvl])", systemImage: "checkmark")
                    } else {
                        Text("\(Self.layerNames[lvl]) · \(Self.layerHints[lvl])")
                    }
                }
            }
        } label: {
            label()
        }
        .accessibilityLabel("정리 단계, 현재 \(entry.layerLabel)")
        .accessibilityHint("두 번 탭하면 단계를 바꿉니다")
    }

    // MARK: - 자료 출처 배지 (조사 결과)

    private var referenceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "paperclip")
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text("자료")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(rowAccent)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(rowAccent.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.source.map { String(localized: "조사 자료, 출처 \($0)") } ?? String(localized: "조사 자료"))
    }
}

// MARK: - 엔트리 수정 시트

struct EntryEditSheet: View {

    @Environment(\.dismiss) private var dismiss

    let entry: ThoughtEntry
    var onSave: (String, [String]) -> Void

    @State private var text: String
    @State private var photos: [String]
    @FocusState private var isFocused: Bool

    init(entry: ThoughtEntry, onSave: @escaping (String, [String]) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _text = State(initialValue: entry.content)
        _photos = State(initialValue: entry.photos)
    }

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                        .font(.body)
                        .lineSpacing(4)
                    if !photos.isEmpty {
                        PostPhotos(names: photos, height: 110) { name in photos.removeAll { $0 == name } }
                    }
                    // 자료는 글로만 붙인다
                    if !entry.isReference {
                        PhotoPickerButton(photos: $photos)
                    }
                }
                .padding(.horizontal, PostMetrics.side)
                .padding(.vertical, 8)
            }
            .navigationTitle("생각 수정")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .barLeading) {
                    Button("취소", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .barConfirm) {
                    Button("저장", systemImage: "checkmark") {
                        onSave(text, photos)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasContent)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        EntryRowView(entry: ThoughtEntry(content: "날것의 생각. 아직 정리되지 않은 상태.", layer: 0), connectsDown: true)
        EntryRowView(entry: ThoughtEntry(content: "핵심 인사이트: 보상 지연 시간의 격차가 깊은 사고를 방해한다", layer: 2), connectsDown: true)
        EntryRowView(entry: ThoughtEntry(content: "도파민 보상의 즉시성이 클수록 만족 지연 능력이 약해진다. 숏폼은 가변 보상 스케줄로 이 회로를 강하게 자극한다.", kind: .reference, source: "Claude"), connectsDown: true)
        EntryRowView(entry: ThoughtEntry(content: "최종 요약: 외부 앵커와 진입 비용 최소화가 필수", layer: 3))
    }
    .padding()
}
