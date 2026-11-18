import SwiftUI
import LeeoKit

struct HomeView: View {
    
    @Environment(ThoughtStore.self) private var store
    @State private var showBrainDump = false
    @State private var selectedThread: ThoughtThread?
    @State private var continueThread: ThoughtThread?
    @State private var exportFile: ExportFile?
    @State private var showSupport = false
    /// 무료 한도 · 잠긴 위젯에 부딪혔을 때 띄우는 페이월.
    @State private var paywallReason: PaywallReason?
    /// 구독 중인 사람에게 6개월째 · 갱신 7일 전에 한 번씩 서는 '구독 졸업' 평생가.
    @State private var showGraduation = false
    private var pro: ProStore { .shared }
    /// 접혀 있을 때 밀어 넣은 스레드 화면들.
    @State private var path: [ThoughtThread.ID] = []
    /// 아이폰 듀오를 폈을 때 결과 쪽 판에 펼쳐 둔 스레드. 없으면 가장 최근 스레드.
    @State private var shownThreadID: ThoughtThread.ID?
    @Environment(\.foldLayout) private var fold
    @Environment(\.horizontalSizeClass) private var sizeClass
    #if DEBUG
    @State private var screenshotThreadID: UUID?
    #endif

    struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    var body: some View {
        // 아이폰 듀오를 펴면 고르는 쪽(왼쪽 · 아래)에 이 목록, 결과 쪽(오른쪽 · 위)에 고른 스레드.
        // 접혀 있거나 보통 아이폰이면 목록만 그린다 — 지금 화면 그대로.
        Group {
            if isWidePad {
                // 넓은 아이패드: 접힌 선 없이 왼쪽 목록 | 오른쪽 고른 스레드.
                HStack(spacing: 0) {
                    home.frame(width: 400)
                    Divider().ignoresSafeArea()
                    FoldThreadPane(thread: shownThread)
                }
            } else {
                FoldSplitView {
                    home
                } result: {
                    FoldThreadPane(thread: shownThread)
                }
            }
        }
        .onChange(of: split) { _, unfolded in
            // 접힌 채 보던 스레드가 있으면 펴는 순간 결과 쪽으로 옮긴다.
            guard unfolded, let last = path.last else { return }
            shownThreadID = last
            path.removeAll()
        }
    }

    /// 넓은 아이패드 · 맥 창인가. Slide Over · 좁은 분할에서는 아이폰처럼 밀어 넣는다.
    private var isWidePad: Bool {
        #if os(macOS)
        true
        #elseif os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad && sizeClass == .regular
        #else
        false
        #endif
    }
    /// 두 칸으로 서는가: 펼친 듀오이거나 넓은 아이패드.
    private var split: Bool { fold.isUnfolded || isWidePad }

    private var shownThread: ThoughtThread? {
        store.threads.first { $0.id == shownThreadID } ?? store.mostRecentThread
    }

    /// 접혀 있으면 스레드 화면을 밀어 넣고, 펴져 있으면 결과 쪽 판에 펼친다.
    private func open(_ thread: ThoughtThread) {
        if split {
            shownThreadID = thread.id
        } else {
            path.append(thread.id)
        }
    }

    private var home: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: - 글쓰기 줄 (맨 위에서 바로 생각을 꺼낸다)
                    composerRow
                    Divider()

                    // MARK: - 첫 실행 / 빈 상태
                    if store.threads.isEmpty && store.dumpItems.isEmpty {
                        emptyState
                    }

                    // MARK: - 덤프 대기 중인 생각들
                    if !store.dumpItems.isEmpty {
                        dumpQueueSection
                    }

                    // MARK: - 피드: 한 줄 타임라인. 가장 최근에 글을 쓴 스레드가 맨 위
                    // (열어 보기만 해서는 올라오지 않는다)
                    let feed = store.threads.sorted { $0.lastWrittenAt > $1.lastWrittenAt }
                    ForEach(feed) { thread in
                        post(thread)

                        // 응원 부탁 (생각을 꽤 쌓아 온 Pro 에게만, 드물게) — 첫 글 아래
                        if thread.id == feed.first?.id, pro.hasPro {
                            LeeoTipAskSlot<ThinkFlowSpec>(tipJar: ThinkFlowTip.tipJar,
                                                          reached: ThinkFlowTipMoments.reachedNow(in: store.threads))
                                .padding(.horizontal, PostMetrics.side)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color.appBackground)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .barTrailing) {
                    contactMenu
                }
                ToolbarItem(placement: .barTrailing) {
                    exportMenu
                }
                ToolbarItem(placement: .barTrailing) {
                    #if os(macOS)
                    SettingsLink {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("설정")
                    #else
                    Button {
                        showSupport = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("설정")
                    .accessibilityHint("지원 및 앱 정보를 엽니다")
                    #endif
                }
            }
            .sheet(isPresented: $showBrainDump) {
                BrainDumpSheet()
            }
            .sheet(item: $continueThread) { thread in
                ContinueThinkingSheet(thread: thread)
            }
            .exportFile(item: $exportFile) { $0.url }
            .sheet(isPresented: $showSupport) {
                ThinkFlowSupportView()
            }
            .sheet(item: $paywallReason) { reason in
                ProPaywallView(reason: reason)
            }
            .sheet(isPresented: $showGraduation) {
                ProGraduationSheet()
            }
            .navigationDestination(for: ThoughtThread.ID.self) { threadID in
                if let thread = store.threads.first(where: { $0.id == threadID }) {
                    ThreadDetailView(thread: thread)
                }
            }
            #if DEBUG
            .navigationDestination(item: $screenshotThreadID) { threadID in
                if let thread = store.threads.first(where: { $0.id == threadID }) {
                    ThreadDetailView(thread: thread)
                }
            }
            #endif
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .focusedSceneValue(\.newThought) { showBrainDump = true }
        // Siri · Spotlight 에서 고른 생각을 연다 (→ OpenThoughtIntent).
        .onChange(of: store.openRequestID, initial: true) { _, id in
            guard let id else { return }
            store.openRequestID = nil
            guard let thread = store.threads.first(where: { $0.id == id }) else { return }
            showBrainDump = false
            continueThread = nil
            open(thread)
        }
        // 구독 졸업은 다른 창이 떠 있지 않을 때만. 떠 있으면 다음에 열 때로 미룬다.
        .onChange(of: pro.graduationIsDue, initial: true) { _, due in
            guard due, !isPresentingSheet else { return }
            pro.markGraduationOffered()
            showGraduation = true
        }
        #if DEBUG
        .onAppear { openScreenshotScene() }
        #endif
    }

    private var isPresentingSheet: Bool {
        showBrainDump || continueThread != nil || exportFile != nil || showSupport || paywallReason != nil
    }

    #if DEBUG
    /// 스토어 스크린샷 전용 — `-ScreenshotScene` 이 가리키는 화면을 바로 연다 (ScreenshotScene.swift)
    private func openScreenshotScene() {
        switch ScreenshotScene.scene {
        case "continue", "bridge": continueThread = store.mostRecentThread
        case "thread": screenshotThreadID = store.mostRecentThread?.id
        case "dump": showBrainDump = true
        case "paywall": paywallReason = .settings
        default: break
        }
    }
    #endif

    // MARK: - 위젯·라이브 액티비티 딥링크 (thinkflow://continue?threadId=...)

    private func handleDeepLink(_ url: URL) {
        // 잠긴 위젯을 누른 사람 — 무엇이 잠겼는지 그 자리에서 보여 준다.
        if url == ProAccess.paywallURL {
            showBrainDump = false
            continueThread = nil
            paywallReason = pro.hasPro ? nil : .widget
            return
        }
        guard url.scheme == "thinkflow", url.host == "continue" else { return }

        let threadID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "threadId" })?
            .value
            .flatMap(UUID.init(uuidString:))

        let target = threadID.flatMap { id in store.threads.first { $0.id == id } }
            ?? store.mostRecentThread
        guard let target else { return }

        showBrainDump = false
        continueThread = target
    }

    // MARK: - 개발자 문의 메뉴

    private var contactMenu: some View {
        Menu {
            Link(destination: URL(string: "mailto:leeo@kakao.com")!) {
                Label("이메일로 문의하기", systemImage: "envelope")
            }
            Link(destination: URL(string: "https://instagram.com/lee25_ios")!) {
                Label("인스타그램 DM (@lee25_ios)", systemImage: "paperplane")
            }
        } label: {
            Image(systemName: "info.circle")
        }
        .accessibilityLabel("개발자에게 문의")
        .accessibilityHint("버그 제보와 기능 제안을 이메일이나 인스타그램 DM으로 보냅니다")
    }

    // MARK: - 내보내기 (백업) 메뉴

    private var exportMenu: some View {
        Menu {
            Button {
                exportMarkdown()
            } label: {
                Label("마크다운으로 내보내기", systemImage: "doc.text")
            }
            Button {
                exportJSON()
            } label: {
                Label("JSON으로 내보내기", systemImage: "curlybraces")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(store.threads.isEmpty && store.dumpItems.isEmpty)
        .accessibilityLabel("내보내기")
        .accessibilityHint("모든 생각을 파일로 내보내 백업합니다")
    }

    private func exportMarkdown() {
        let markdown = ThoughtExporter.markdown(threads: store.threads, dumpItems: store.dumpItems)
        guard let data = markdown.data(using: .utf8),
              let url = try? ThoughtExporter.writeTemporaryFile(
                named: "이어생각-\(ThoughtExporter.fileDateStamp()).md",
                contents: data
              ) else { return }
        exportFile = ExportFile(url: url)
    }

    private func exportJSON() {
        guard let data = try? ThoughtExporter.jsonData(threads: store.threads, dumpItems: store.dumpItems),
              let url = try? ThoughtExporter.writeTemporaryFile(
                named: "이어생각-\(ThoughtExporter.fileDateStamp()).json",
                contents: data
              ) else { return }
        exportFile = ExportFile(url: url)
    }
    
    // MARK: - 글쓰기 줄 (피드 맨 위)

    private var composerRow: some View {
        Button {
            showBrainDump = true
        } label: {
            PostRow {
                PostAvatar(kind: .thought("💭"))
            } content: {
                VStack(alignment: .leading, spacing: 2) {
                    PostAuthor()
                    Text("무슨 생각이에요?")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, PostMetrics.side)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("생각 꺼내기")
        .accessibilityAddTraits(.isButton)
        .keyboardShortcut("n")
        .accessibilityHint("머릿속 생각을 적어 새 스레드를 만듭니다")
    }

    // MARK: - 빈 상태 (첫 실행)

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("생각을 이어 나가 보세요")
                    .font(.title3)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                Text("머릿속에 떠다니는 생각을 꺼내 두면\n다음에 이어서 더 깊이 생각할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                showBrainDump = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("첫 생각 꺼내기")
                }
                .postButtonStyle()
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PostMetrics.side)
        .padding(.vertical, 60)
    }

    // MARK: - 덤프 대기 목록 (아직 올리지 않은 글)

    private var dumpQueueSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "아직 정리 안 된 생각들", subtitle: "탭하면 생각 스레드가 됩니다")
            ForEach(store.dumpItems) { item in
                dumpItemRow(item)
                Divider()
            }
        }
    }

    @ViewBuilder
    private func dumpItemRow(_ item: DumpItem) -> some View {
        Button {
            // 칸이 다 찼으면 생각은 목록에 그대로 두고 페이월을 띄운다.
            if pro.canStartThread(existing: store.threads.count) {
                store.promoteDumpItemToThread(id: item.id)
            } else {
                paywallReason = .threadLimit
            }
        } label: {
            PostRow(avatarSize: PostMetrics.smallAvatar) {
                PostAvatar(kind: .thought("💭"), size: PostMetrics.smallAvatar)
                    .opacity(0.55)
            } content: {
                HStack(alignment: .top, spacing: 10) {
                    Text(item.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if !item.photos.isEmpty {
                        Image(systemName: "photo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("사진")
                    }
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, PostMetrics.side)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("두 번 탭하면 생각 스레드로 만듭니다")
        .accessibilityAction(named: "삭제") {
            store.deleteDumpItem(id: item.id)
        }
        .contextMenu {
            Button(role: .destructive) {
                store.deleteDumpItem(id: item.id)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    // MARK: - 피드의 글 하나

    @ViewBuilder
    private func post(_ thread: ThoughtThread) -> some View {
        Button { open(thread) } label: {
            ThreadCardView(thread: thread, onContinue: { continueThread = thread })
        }
        .buttonStyle(.plain)
        .foldShown(split && thread.id == shownThread?.id)
        // 글 안의 답글 단추 · 끊어둔 문장이 글 링크에 묻혀도 동작으로 닿게
        .accessibilityAction(named: Text("이어서 생각하기")) { continueThread = thread }
        Divider()
    }

    // MARK: - 피드 구획 제목

    private func sectionHeader(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PostMetrics.side)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - 아이폰 듀오 결과 쪽

/// 펼친 화면의 결과 쪽 판. 고른 스레드를 접혔을 때 밀어 넣던 그 화면 그대로 보여 준다.
private struct FoldThreadPane: View {
    let thread: ThoughtThread?

    var body: some View {
        NavigationStack {
            if let thread {
                ThreadDetailView(thread: thread)
                    .id(thread.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                    Text("생각을 이어 나가 보세요")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
            }
        }
    }
}

private extension View {
    /// 펼친 화면에서 결과 쪽에 열린 글의 바탕을 살짝 눌러 둔다.
    func foldShown(_ isShown: Bool) -> some View {
        background(isShown ? Color.primary.opacity(0.06) : Color.clear)
            .accessibilityAddTraits(isShown ? .isSelected : [])
    }
}

#Preview {
    HomeView()
        .environment(ThoughtStore())
}
