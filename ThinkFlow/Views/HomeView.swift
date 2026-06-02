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
            .navigationTitle("이어생각")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBrainDump = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("생각 꺼내기")
                    .accessibilityHint("머릿속 생각을 적어 새 스레드를 만듭니다")
                }
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
        let lastEntry = thread.entries.sorted { $0.createdAt > $1.createdAt }.first

        NavigationLink(value: thread.id) {
            VStack(alignment: .leading, spacing: 16) {

                // 헤더
                HStack {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("여기서 이어서")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(thread.bridge.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    // 스레드 제목
                    HStack(spacing: 8) {
                        Text(thread.emoji)
                            .font(.title2)
                        Text(thread.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }

                    // 직전 생각 — 맥락 복원
                    if let last = lastEntry {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("직전 생각", systemImage: "clock.arrow.circlepath")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text(last.content)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // 끊어둔 문장 — 재진입 트리거 (가장 중요)
                    if !thread.bridge.nextQuestion.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("끊어둔 문장", systemImage: "arrow.turn.down.right")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                            Text(thread.bridge.nextQuestion)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            HStack(spacing: 0) {
                                Color.orange.opacity(0.4)
                                    .frame(width: 3)
                                Color.orange.opacity(0.07)
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // 이어서 생각하기 버튼
                    Button {
                        continueThread = thread
                    } label: {
                        HStack {
                            Image(systemName: "pencil.line")
                            Text("이어서 생각하기")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.orange.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("이어서 생각하기")
                    .accessibilityHint("\(thread.title)에 생각을 이어 적습니다")
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
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
