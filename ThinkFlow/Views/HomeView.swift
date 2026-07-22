import SwiftUI
import UIKit

struct HomeView: View {
    
    @Environment(ThoughtStore.self) private var store
    @State private var showBrainDump = false
    @State private var selectedThread: ThoughtThread?
    @State private var continueThread: ThoughtThread?
    @State private var exportFile: ExportFile?

    struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    var body: some View {
        NavigationStack {
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
            .navigationDestination(for: ThoughtThread.ID.self) { threadID in
                if let thread = store.threads.first(where: { $0.id == threadID }) {
                    ThreadDetailView(thread: thread)
                }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // MARK: - 위젯·라이브 액티비티 딥링크 (thinkflow://continue?threadId=...)

    private func handleDeepLink(_ url: URL) {
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
        .accessibilityHint("머릿속 생각을 적어 새 스레드를 만듭니다")
    }

    // MARK: - 빈 상태 (첫 실행)

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52))
                .foregroundStyle(.orange.gradient)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("생각을 이어 나가 보세요")
                    .font(.title3)
                    .fontWeight(.bold)
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
            store.promoteDumpItemToThread(id: item.id)
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
        NavigationLink(value: thread.id) {
            ThreadCardView(
                thread: thread,
                isResume: true,
                onContinue: { continueThread = thread }
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 스레드 섹션
    @ViewBuilder
    private func threadSection(title: String, subtitle: String, threads: [ThoughtThread]) -> some View {
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
                NavigationLink(value: thread.id) {
                    ThreadCardView(
                        thread: thread,
                        onContinue: {
                            continueThread = thread
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
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
