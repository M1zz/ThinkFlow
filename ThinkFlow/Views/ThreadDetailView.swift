import SwiftUI

struct ThreadDetailView: View {
    
    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    let thread: ThoughtThread
    
    @State private var showContinueSheet = false
    @State private var showBridgeEditor = false
    @State private var showDeleteAlert = false
    @State private var sortNewestFirst = false
    @State private var editingEntry: ThoughtEntry?
    /// 답글을 달 글. 큰 줄기에 이어 쓸 때는 쓰지 않는다(showContinueSheet).
    @State private var replyTarget: ThoughtEntry?
    
    private var currentThread: ThoughtThread {
        store.threads.first { $0.id == thread.id } ?? thread
    }
    
    private var sortedEntries: [ThoughtEntry] {
        currentThread.entries.sorted {
            sortNewestFirst ? $0.createdAt > $1.createdAt : $0.createdAt < $1.createdAt
        }
    }

    /// 화면에 그릴 한 줄 — 글과, 그 글이 답글 나무의 어디에 있는지.
    private struct Node: Identifiable {
        let entry: ThoughtEntry
        let depth: Int
        let guides: [Bool]
        let connectsDown: Bool
        let replyCount: Int
        var id: UUID { entry.id }
    }

    /// 들여 쓰는 깊이의 한도. 더 깊은 답글은 같은 칸에 이어 붙인다 (좁은 화면에서 글 폭을 지킨다).
    private static let maxDepth = 3

    /// 큰 줄기의 글을 고른 순서대로 놓고, 글마다 그 답글을 쓴 순서대로 바로 아래에 붙인다.
    /// 답글은 큰 줄기의 순서를 뒤집어도 언제나 답한 글 아래에 선다 — 위계가 깨지지 않는다.
    private var nodes: [Node] {
        let entries = currentThread.entries
        let ids = Set(entries.map(\.id))
        let chronological = entries.sorted { $0.createdAt < $1.createdAt }
        // 답한 글이 지워져 없으면 큰 줄기로 본다
        let replies = Dictionary(grouping: chronological.filter { $0.parentID.map(ids.contains) ?? false },
                                 by: { $0.parentID! })
        let trunk = sortedEntries.filter { !($0.parentID.map(ids.contains) ?? false) }

        var result: [Node] = []
        func visit(_ entry: ThoughtEntry, depth: Int, guides: [Bool], trunkContinues: Bool) {
            let children = replies[entry.id] ?? []
            result.append(Node(
                entry: entry,
                depth: depth,
                guides: guides,
                connectsDown: !children.isEmpty || (depth == 0 && trunkContinues),
                replyCount: children.count
            ))
            for (index, child) in children.enumerated() {
                let hasNextSibling = index < children.count - 1
                if depth < Self.maxDepth {
                    // 맨 왼쪽 칸은 큰 줄기의 선도 함께 지난다
                    let continues = hasNextSibling || (depth == 0 && trunkContinues)
                    visit(child, depth: depth + 1, guides: guides + [continues], trunkContinues: trunkContinues)
                } else {
                    visit(child, depth: depth, guides: guides, trunkContinues: trunkContinues)
                }
            }
        }
        for (index, entry) in trunk.enumerated() {
            // 오래된순이면 마지막 글 아래에 끊어둔 문장이 이어진다
            visit(entry, depth: 0, guides: [], trunkContinues: index < trunk.count - 1 || !sortNewestFirst)
        }
        return result
    }

    var body: some View {
        let sorted = sortedEntries

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text(currentThread.metaLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)

                // 끊어둔 문장은 스레드의 가장 새 글 자리에 선다 — 최신순이면 맨 위, 오래된순이면 맨 아래.
                if sortNewestFirst {
                    bridgeRow(connectsDown: !sorted.isEmpty)
                }

                if sorted.isEmpty {
                    emptyEntries
                } else {
                    ForEach(nodes) { node in
                        let entry = node.entry
                        EntryRowView(
                            entry: entry,
                            emoji: currentThread.emoji,
                            connectsDown: node.connectsDown,
                            depth: node.depth,
                            guides: node.guides,
                            replyCount: node.replyCount,
                            onReply: { replyTarget = entry },
                            onLayerChange: { newLayer in
                                store.updateEntryLayer(
                                    threadID: currentThread.id,
                                    entryID: entry.id,
                                    newLayer: newLayer
                                )
                            },
                            onEdit: {
                                editingEntry = entry
                            },
                            onDelete: {
                                store.deleteEntry(threadID: currentThread.id, entryID: entry.id)
                            }
                        )
                    }
                }

                if !sortNewestFirst {
                    bridgeRow(connectsDown: false)
                }
            }
            .padding(.horizontal, PostMetrics.side)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle("\(currentThread.emoji) \(currentThread.title)")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .barTrailing) {
                ThreadShareButton(thread: currentThread)
            }
            ToolbarItem(placement: .barTrailing) {
                Menu {
                    Button {
                        showBridgeEditor = true
                    } label: {
                        Label("브릿지 수정", systemImage: "bookmark")
                    }

                    if !sorted.isEmpty {
                        Button {
                            Clipboard.copy(sorted
                                .map { "[\($0.layerLabel)] \($0.content)" }
                                .joined(separator: "\n\n"))
                            Announce.say(String(localized: "복사되었습니다"))
                        } label: {
                            Label("전체 복사", systemImage: "doc.on.doc")
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sortNewestFirst.toggle()
                            }
                        } label: {
                            Label(sortNewestFirst ? String(localized: "최신순") : String(localized: "오래된순"),
                                  systemImage: sortNewestFirst ? "arrow.down" : "arrow.up")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("더 보기")
            }
        }
        .safeAreaInset(edge: .bottom) {
            replyBar
        }
        .sheet(isPresented: $showContinueSheet) {
            ContinueThinkingSheet(thread: currentThread)
        }
        .sheet(item: $replyTarget) { entry in
            ContinueThinkingSheet(thread: currentThread, replyTo: entry)
        }
        .sheet(isPresented: $showBridgeEditor) {
            BridgeEditorView(thread: currentThread)
        }
        .sheet(item: $editingEntry) { entry in
            EntryEditSheet(entry: entry) { newContent, newPhotos in
                store.updateEntryContent(
                    threadID: currentThread.id,
                    entryID: entry.id,
                    content: newContent,
                    photos: newPhotos
                )
            }
        }
        .alert("이 생각을 삭제할까요?", isPresented: $showDeleteAlert) {
            Button("삭제", role: .destructive) {
                store.deleteThread(id: thread.id)
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("'\(currentThread.title)' 스레드의 모든 메모와 브릿지가 삭제됩니다.")
        }
        .onAppear {
            store.startSession(threadID: thread.id)
        }
        .onDisappear {
            store.endSession()
        }
    }

    // MARK: - 끊어둔 문장 (누르면 그 문장에서 이어 쓴다. 비어 있으면 적어 둔다)

    private func bridgeRow(connectsDown: Bool) -> some View {
        let question = currentThread.bridge.nextQuestion
        return Button {
            if question.isEmpty {
                showBridgeEditor = true
            } else {
                showContinueSheet = true
            }
        } label: {
            if question.isEmpty {
                PostRow(connectsDown: connectsDown, avatarSize: PostMetrics.smallAvatar) {
                    PostAvatar(kind: .bridge, size: PostMetrics.smallAvatar)
                } content: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("끊어둔 문장")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text("기세가 있을 때 문장을 끊어두세요.\n다음에 열면 뇌가 자동으로 이어받습니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .multilineTextAlignment(.leading)
                    }
                }
            } else {
                BridgePost(text: question, connectsDown: connectsDown, prominent: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(question.isEmpty ? String(localized: "끊어둔 문장 수정") : String(localized: "이어서 생각하기"))
    }

    // MARK: - 아직 적은 것이 없을 때

    private var emptyEntries: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("아직 기록이 없어요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("'이어서 생각하기'를 눌러 첫 기록을 남겨보세요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - 답글 막대 (이어서 생각하기)

    private var replyBar: some View {
        Button {
            showContinueSheet = true
        } label: {
            HStack(spacing: 10) {
                PostAvatar(kind: .thought(currentThread.emoji), size: 26)
                Text("이어서 생각하기")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.raisedBackground, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, PostMetrics.side)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview {
    NavigationStack {
        ThreadDetailView(thread: ThoughtThread.sampleThreads[0])
            .environment(ThoughtStore())
    }
}
