import SwiftUI
import UIKit
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

    /// 넓은 아이패드인가. Slide Over · 좁은 분할에서는 아이폰처럼 밀어 넣는다.
    private var isWidePad: Bool {
        #if os(iOS)
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
                VStack(spacing: 24) {

                    // MARK: - 첫 실행 / 빈 상태
                    if store.threads.isEmpty && store.dumpItems.isEmpty {
                        emptyState
                    }

                    // MARK: - 덤프 대기 중인 생각들
                    if !store.dumpItems.isEmpty {
                        dumpQueueSection
                    }

                    // MARK: - 이어서 생각하기 (가장 중요한 영역)
                    if let recent = store.mostRecentThread {
                        resumeSection(thread: recent)
                    }

                    // MARK: - 응원 부탁 (생각을 꽤 쌓아 온 Pro 에게만, 드물게)
                    if pro.hasPro {
                        LeeoTipAskSlot<ThinkFlowSpec>(tipJar: ThinkFlowTip.tipJar,
                                                      reached: ThinkFlowTipMoments.reachedNow(in: store.threads))
                    }
                    
                    // MARK: - 활발한 생각들 (히어로 카드에 이미 표시된 것 제외)
                    let heroID = store.mostRecentThread?.id
                    let remainingActive = store.activeThreads.filter { $0.id != heroID }
                    if !remainingActive.isEmpty {
                        threadSection(
                            title: "진행 중인 생각",
                            subtitle: "최근 3일 내 방문",
                            threads: remainingActive
                        )
                    }
                    
                    // MARK: - 잠자는 생각들
                    if !store.dormantThreads.isEmpty {
                        threadSection(
                            title: "되살릴 생각",
                            subtitle: "3일 이상 방치됨",
                            threads: store.dormantThreads
                        )
                    }
                    
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    contactMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    exportMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSupport = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("설정")
                    .accessibilityHint("지원 및 앱 정보를 엽니다")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                addThoughtButton
            }
            .sheet(isPresented: $showBrainDump) {
                BrainDumpSheet()
            }
            .sheet(item: $continueThread) { thread in
                ContinueThinkingSheet(thread: thread)
            }
            .sheet(item: $exportFile) { file in
                ShareSheet(items: [file.url])
            }
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
    
    // MARK: - 생각 꺼내기 플로팅 버튼 (우측 하단)

    private var addThoughtButton: some View {
        Button {
            showBrainDump = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(.orange.gradient, in: Circle())
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel("생각 꺼내기")
        .keyboardShortcut("n")
        .accessibilityHint("머릿속 생각을 적어 새 스레드를 만듭니다")
    }

    // MARK: - 빈 상태 (첫 실행)

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52))
                .foregroundStyle(.orange.gradient)
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
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.orange.gradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 덤프 대기 목록

    private var dumpQueueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("아직 정리 안 된 생각들")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("탭하면 생각 스레드가 됩니다")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(store.dumpItems) { item in
                dumpItemRow(item)
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
            HStack(alignment: .top, spacing: 10) {
                Text(item.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.right.circle")
                    .foregroundStyle(.tertiary)
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
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

    // MARK: - 이어서 생각하기 카드 (Hero Section)
    @ViewBuilder
    private func resumeSection(thread: ThoughtThread) -> some View {
        Button { open(thread) } label: {
            ThreadCardView(
                thread: thread,
                isResume: true,
                onContinue: { continueThread = thread }
            )
        }
        .buttonStyle(.plain)
        .foldShown(split && thread.id == shownThread?.id)
        // 카드 안의 '이어서 생각하기' 단추가 카드 링크에 묻혀도 동작으로 닿게
        .accessibilityAction(named: Text("이어서 생각하기")) { continueThread = thread }
    }
    
    // MARK: - 스레드 섹션
    @ViewBuilder
    private func threadSection(title: LocalizedStringKey, subtitle: LocalizedStringKey, threads: [ThoughtThread]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(threads) { thread in
                Button { open(thread) } label: {
                    ThreadCardView(
                        thread: thread,
                        onContinue: {
                            continueThread = thread
                        }
                    )
                }
                .buttonStyle(.plain)
                .foldShown(split && thread.id == shownThread?.id)
                .accessibilityAction(named: Text("이어서 생각하기")) { continueThread = thread }
            }
        }
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
                        .foregroundStyle(.orange.gradient)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)
                    Text("생각을 이어 나가 보세요")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

private extension View {
    /// 펼친 화면에서 결과 쪽에 열린 카드에 테두리를 세운다.
    func foldShown(_ isShown: Bool) -> some View {
        overlay {
            if isShown {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.orange, lineWidth: 2)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityAddTraits(isShown ? .isSelected : [])
    }
}

// MARK: - 시스템 공유 시트 (파일 내보내기용)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    HomeView()
        .environment(ThoughtStore())
}
