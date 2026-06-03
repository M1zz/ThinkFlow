import SwiftUI

struct HomeView: View {
    
    @Environment(ThoughtStore.self) private var store
    @State private var showBrainDump = false
    @State private var selectedThread: ThoughtThread?
    @State private var continueThread: ThoughtThread?
    
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
            .overlay(alignment: .bottomTrailing) {
                addThoughtButton
            }
            .sheet(isPresented: $showBrainDump) {
                BrainDumpSheet()
            }
            .sheet(item: $continueThread) { thread in
                ContinueThinkingSheet(thread: thread)
            }
            .navigationDestination(for: ThoughtThread.ID.self) { threadID in
                if let thread = store.threads.first(where: { $0.id == threadID }) {
                    ThreadDetailView(thread: thread)
                }
            }
        }
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

#Preview {
    HomeView()
        .environment(ThoughtStore())
}
