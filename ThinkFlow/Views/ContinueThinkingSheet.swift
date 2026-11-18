import SwiftUI

struct ContinueThinkingSheet: View {

    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let thread: ThoughtThread
    /// 답글을 달 글. nil 이면 스레드의 큰 줄기에 이어 쓴다.
    var replyTo: ThoughtEntry?

    @State private var draft = ""
    @State private var draftPhotos: [String] = []
    @State private var newThoughts: [PendingThought] = []
    @State private var phase: Phase = .thinking
    @State private var nextStartingPoint = ""
    @State private var sessionStart = Date()
    @FocusState private var isThoughtFocused: Bool
    @FocusState private var isNextFocused: Bool
    @State private var showPaywall = false
    private var pro: ProStore { .shared }

    // 조사 결과·자료 (옵셔널) — 예: 클로드에게 물어본 결과 정리
    @State private var refDraft = ""
    @State private var refSource = ""
    @State private var newReferences: [PendingReference] = []
    @State private var showRefInput = false
    @FocusState private var isRefFocused: Bool

    /// 이번에 적었지만 아직 스레드에 올리지 않은 글.
    struct PendingThought {
        var text: String
        var photos: [String]
    }

    struct PendingReference: Identifiable {
        let id = UUID()
        var source: String
        var content: String
    }

    enum Phase { case thinking, bridging }

    /// 끊어둔 문장 — 열 때 입력 칸에 채워 둔다. 손대지 않은 채로는 쓴 것으로 치지 않는다.
    private var prefill: String {
        // 끊어둔 문장은 큰 줄기의 다음 글이다 — 특정 글에 답할 때는 채우지 않는다
        replyTo == nil ? thread.bridge.nextQuestion.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }
    /// 쓰는 칸 위에 보여 줄 앞선 글 — 답글이면 답할 그 글, 아니면 핵심 + 직전 생각.
    private var contextEntries: [ThoughtEntry] {
        replyTo.map { [$0] } ?? thread.recapEntries
    }
    /// 이번에 생각을 하나라도 올렸는가 — 올렸으면 끊어둔 문장은 글이 되어 스레드에 들어갔다.
    @State private var wroteThought = false

    private var draftIsEmpty: Bool {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        // 사진을 붙였으면 글이 없어도 올릴 수 있다
        return draftPhotos.isEmpty && (text.isEmpty || (newThoughts.isEmpty && text == prefill))
    }
    private var refDraftIsEmpty: Bool {
        refDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    // 추가된 생각이 하나라도 있거나, 입력 중인 글이 있으면 진행 가능
    private var hasThought: Bool {
        !newThoughts.isEmpty || !draftIsEmpty
    }
    // 붙여둔 자료가 있거나, 입력 중인 자료가 있는지
    private var hasReference: Bool {
        !newReferences.isEmpty || !refDraftIsEmpty
    }
    // 생각이든 자료든 저장할 내용이 있으면 진행/닫기 보호
    private var hasAnyInput: Bool {
        hasThought || hasReference
    }
    private var hasNextPoint: Bool {
        !nextStartingPoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch phase {
                    case .thinking: thinkingPhase
                    case .bridging: bridgingPhase
                    }
                }
                .padding(.horizontal, PostMetrics.side)
                .padding(.vertical, 16)
            }
            .background(Color.appBackground)
            .navigationTitle(phase == .thinking ? String(localized: "이어서 생각하기") : String(localized: "문장 끊어두기"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .barLeading) {
                    // 입력이 없을 때만 그냥 닫기. 입력이 있으면 '다음'으로 문장을 끊어둬야 닫힌다.
                    if phase == .thinking && !hasAnyInput {
                        Button("닫기", systemImage: "xmark") { dismiss() }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .barConfirm) {
                    if phase == .thinking {
                        Button("다음", systemImage: "arrow.right") {
                            saveEntries()
                            goToBridging()
                        }
                        .fontWeight(.semibold)
                        .disabled(!hasAnyInput)
                    } else {
                        Button("완료", systemImage: "checkmark") {
                            saveBridge()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .interactiveDismissDisabled(hasAnyInput || phase == .bridging)
        .sheet(isPresented: $showPaywall) {
            // 생각하던 중에 Pro 가 열리면 지금 세션부터 잠금 화면에 띄운다.
            ProPaywallView(reason: .liveActivity) { store.showSessionActivity() }
        }
        .onAppear {
            sessionStart = Date()
            store.startSession(threadID: thread.id)
            if draft.isEmpty { draft = prefill }
            isThoughtFocused = true
            #if DEBUG
            switch ScreenshotScene.scene {
            case "continue": if let seeded = ScreenshotScene.seed?.draft { draft = seeded }
            case "bridge":
                phase = .bridging
                nextStartingPoint = ScreenshotScene.seed?.bridgeDraft ?? ""
            default: break
            }
            #endif
        }
        .onDisappear {
            // 어떤 경로로 닫히든(완료/닫기/스와이프) 세션을 한 번만 마감
            store.endSession()
        }
    }

    // MARK: - Phase 1: 생각 쓰기 — 지금까지의 스레드 아래에 답글을 잇는다

    private var thinkingPhase: some View {
        VStack(alignment: .leading, spacing: 20) {

            // 맥락 → 끊어둔 문장 → 이번에 적은 생각 → 쓰는 칸이 한 줄로 이어진다
            VStack(alignment: .leading, spacing: 0) {

                // 지금까지의 맥락 — 정제된 핵심 + 직전 생각
                ForEach(contextEntries) { entry in
                    contextRow(entry)
                }

                // 이번에 추가한 생각들
                ForEach(Array(newThoughts.enumerated()), id: \.offset) { index, thought in
                    addedThoughtRow(index: index, thought: thought)
                }

                // 쓰는 칸
                PostRow(connectsDown: true) {
                    PostAvatar(kind: .thought(thread.emoji))
                } content: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            PostAuthor()
                            Spacer()
                            if !newThoughts.isEmpty {
                                Text("\(newThoughts.count)개 추가됨")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        // 끊어둔 문장이 칸에 채워져 있다 — 그 문장에서 바로 이어 쓴다
                        if !prefill.isEmpty && newThoughts.isEmpty {
                            Text("여기서 끊어뒀어요")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.top, 2)
                        }
                        PostEditor(text: $draft,
                                   placeholder: String(localized: "지금 이어지는 생각"),
                                   minHeight: newThoughts.isEmpty ? 140 : 90,
                                   focus: $isThoughtFocused)
                            .accessibilityLabel(newThoughts.isEmpty ? String(localized: "지금 이어지는 생각") : String(localized: "생각 더 추가"))
                        if !draftPhotos.isEmpty {
                            PostPhotos(names: draftPhotos, height: 110) { name in draftPhotos.removeAll { $0 == name } }
                        }
                        HStack {
                            PhotoPickerButton(photos: $draftPhotos)
                            Spacer()
                            Text("\(draft.count)자")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 스레드에 하나 더 — 생각이 바뀔 때마다 끊어서 올린다
                PostRow(avatarSize: PostMetrics.smallAvatar) {
                    PostAvatar(kind: .thought(thread.emoji), size: PostMetrics.smallAvatar)
                        .opacity(0.5)
                } content: {
                    Button {
                        addDraft()
                    } label: {
                        Text("생각 추가")
                            .font(.subheadline)
                            .frame(minHeight: PostMetrics.smallAvatar)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(draftIsEmpty ? .tertiary : .primary)
                    .disabled(draftIsEmpty)
                    .accessibilityHint("입력한 생각을 한 덩어리로 추가하고 다음 생각을 적습니다")
                }
            }

            Text("생각이 바뀔 때마다 따로 추가하면 나중에 정리하기 쉬워요.")
                .font(.caption)
                .foregroundStyle(.secondary)

            referenceSection

            sessionTimer
        }
    }

    /// 지금까지의 맥락 한 줄 — 흐리게, 스레드의 앞선 글로.
    private func contextRow(_ entry: ThoughtEntry) -> some View {
        let isLast = entry.id == thread.lastEntry?.id
        return PostRow(connectsDown: true) {
            PostAvatar(kind: entry.isReference ? .reference : .thought(thread.emoji))
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    PostAuthor(name: entry.isReference ? (entry.source ?? String(localized: "자료")) : String(localized: "나"),
                               date: entry.createdAt)
                    if entry.layer > 0 { LayerBadge(entry: entry) }
                }
                if !entry.content.isEmpty {
                    Text(entry.content)
                        .font(.subheadline)
                        .foregroundStyle(entry.layer >= 2 ? .primary : .secondary)
                        .lineSpacing(3)
                        .lineLimit(4)
                }
                if !entry.photos.isEmpty {
                    PostPhotos(names: entry.photos, height: 80)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isLast ? String(localized: "직전 생각") : entry.layerLabel): \(entry.content)")
    }

    // MARK: - 조사 결과·자료 붙이기 (옵셔널) — 내 스레드에 달리는 다른 글쓴이의 답글

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            // 이번에 붙인 자료들
            ForEach(Array(newReferences.enumerated()), id: \.element.id) { index, ref in
                addedReferenceRow(index: index, ref: ref)
            }

            if showRefInput {
                PostRow {
                    PostAvatar(kind: .reference)
                } content: {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("출처 (예: Claude, 검색) — 선택", text: $refSource)
                            .font(.subheadline.weight(.semibold))
                            .accessibilityLabel("자료 출처")

                        PostEditor(text: $refDraft,
                                   placeholder: String(localized: "조사 결과·자료"),
                                   minHeight: 110,
                                   focus: $isRefFocused)
                            .accessibilityLabel("자료 내용")
                            .accessibilityHint("조사하거나 정리한 내용을 붙여넣습니다")

                        HStack {
                            Button("취소") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showRefInput = false
                                    refDraft = ""
                                    refSource = ""
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                addReferenceDraft()
                            } label: {
                                Text("자료 추가")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .tint(.teal)
                            .disabled(refDraftIsEmpty)
                            .accessibilityHint("입력한 자료를 이 생각 흐름에 붙입니다")
                        }
                    }
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showRefInput = true }
                    isRefFocused = true
                } label: {
                    PostRow {
                        PostAvatar(kind: .reference)
                    } content: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("조사 결과·자료 붙이기")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.teal)
                            Text("예: 클로드에게 물어본 결과 정리")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("생각과 별개로 조사하거나 정리한 자료를 붙여둘 수 있습니다")
            }
        }
    }

    // 이번 세션에 붙인 자료 한 줄 (삭제 가능)
    @ViewBuilder
    private func addedReferenceRow(index: Int, ref: PendingReference) -> some View {
        let source = ref.source.trimmingCharacters(in: .whitespaces)
        PostRow {
            PostAvatar(kind: .reference)
        } content: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    PostAuthor(name: source.isEmpty ? String(localized: "자료") : source)
                    Text(ref.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    removeReference(at: index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(index + 1)번째 자료 삭제")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("붙인 자료 \(index + 1): \(ref.content)")
    }

    // 이번 세션에 추가한 생각 한 줄 (삭제 가능)
    @ViewBuilder
    private func addedThoughtRow(index: Int, thought: PendingThought) -> some View {
        PostRow(connectsDown: true) {
            PostAvatar(kind: .thought(thread.emoji))
        } content: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    PostAuthor()
                    if !thought.text.isEmpty {
                        Text(thought.text)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !thought.photos.isEmpty {
                        PostPhotos(names: thought.photos, height: 110)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    removeThought(at: index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(index + 1)번째 생각 삭제")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("추가한 생각 \(index + 1): \(thought.text)")
    }

    // MARK: - Phase 2: 문장 끊어두기

    private var bridgingPhase: some View {
        VStack(alignment: .leading, spacing: 20) {

            // 안내
            VStack(alignment: .leading, spacing: 8) {
                Text("기세가 있을 때 끊어두세요")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("막혀서 멈추는 게 아니라, 아직 쓸 게 있을 때 여기서 끊어두세요.\n다음에 열면 뇌가 자동으로 이어받습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }

            // 미완성 문장 입력
            VStack(alignment: .leading, spacing: 8) {
                Label("이어질 문장 끊기", systemImage: "arrow.turn.down.right")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)

                TextEditor(text: $nextStartingPoint)
                    .focused($isNextFocused)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .lineSpacing(4)
                    .accessibilityLabel("이어질 문장 끊기")
                    .accessibilityHint("다음에 이어서 생각할 미완성 문장을 적습니다")

                if nextStartingPoint.isEmpty {
                    Text("예: \"숏폼이 뇌를 망치는 이유는 보상 주기 때문인데, 그렇다면—\"")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(.orange.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(hasNextPoint ? 0.3 : 0.1), lineWidth: 1.5)
            )
        }
        .onAppear { isNextFocused = true }
    }

    // MARK: - 세션 타이머

    private var sessionTimer: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple.opacity(0.5))
                Text(sessionStart, style: .timer)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("생각 중...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("사고 세션 진행 중")

            // 무료는 앱 안 타이머만. 폰을 잠가도 시간이 보이게 하려면 Pro.
            if !pro.featuresOpen {
                Button {
                    showPaywall = true
                } label: {
                    Label("잠금 화면에도 생각 시간 띄우기", systemImage: "lock.iphone")
                        .font(.body)
                        .frame(minHeight: 44)
                }
                .tint(.purple)
                .accessibilityHint("이어생각 Pro를 소개하는 화면을 엽니다")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    // 입력 중인 글을 한 덩어리 생각으로 추가하고 다음 입력을 받는다.
    private func addDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        // 손대지 않은 끊어둔 문장은 올리지 않는다
        guard !draftIsEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            newThoughts.append(PendingThought(text: trimmed, photos: draftPhotos))
            draft = ""
            draftPhotos = []
        }
        isThoughtFocused = true
        Announce.say(String(localized: "생각 추가됨"))
    }

    private func removeThought(at index: Int) {
        guard newThoughts.indices.contains(index) else { return }
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            newThoughts.remove(at: index)
        }
    }

    // 입력 중인 자료를 한 덩어리로 붙이고 입력란을 비운다.
    private func addReferenceDraft() {
        let trimmed = refDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let source = refSource.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(.easeInOut(duration: 0.2)) {
            newReferences.append(PendingReference(source: source, content: trimmed))
            refDraft = ""
            refSource = ""
            showRefInput = false
        }
        Announce.say(String(localized: "자료 추가됨"))
    }

    private func removeReference(at index: Int) {
        guard newReferences.indices.contains(index) else { return }
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            newReferences.remove(at: index)
        }
    }

    // '다음'을 누르면 입력 중인 글·자료까지 모두 각각의 엔트리로 저장한다.
    private func saveEntries() {
        addDraft()
        // 큰 줄기에 생각을 올렸을 때만 끊어둔 문장이 글이 된 것으로 본다
        wroteThought = replyTo == nil && !newThoughts.isEmpty
        for thought in newThoughts {
            store.addEntry(to: thread.id, content: thought.text, parentID: replyTo?.id, photos: thought.photos)
        }
        addReferenceDraft()
        for ref in newReferences {
            store.addReference(to: thread.id, content: ref.content, source: ref.source, parentID: replyTo?.id)
        }
    }

    private func goToBridging() {
        // 생각을 올렸으면 끊어둔 문장은 이미 글이 됐다 — 다음 문장은 빈 칸에서. 자료만 붙였으면 그대로 둔다.
        nextStartingPoint = wroteThought ? "" : thread.bridge.nextQuestion
        withAnimation(.easeInOut(duration: 0.25)) { phase = .bridging }
        Announce.say(String(localized: "문장 끊어두기 단계입니다. 다음에 이어갈 문장을 적으세요.")
        )
    }

    private func saveBridge() {
        let point = nextStartingPoint.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateBridge(for: thread.id, nextQuestion: point)
        // 세션 마감은 onDisappear에서 일괄 처리
    }
}

#Preview {
    ContinueThinkingSheet(thread: ThoughtThread.sampleThreads[0])
        .environment(ThoughtStore())
}
