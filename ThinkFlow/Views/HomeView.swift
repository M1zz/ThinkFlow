import SwiftUI

struct HomeView: View {
    
    @Environment(ThoughtStore.self) private var store
    @State private var showNewThread = false
    @State private var selectedThread: ThoughtThread?
    @State private var showContinueSheet = false
    @State private var continueThread: ThoughtThread?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - 이어서 생각하기 (가장 중요한 영역)
                    if let recent = store.mostRecentThread {
                        resumeSection(thread: recent)
                    }
                    
                    // MARK: - 활발한 생각들
                    if !store.activeThreads.isEmpty {
                        threadSection(
                            title: "진행 중인 생각",
                            subtitle: "최근 3일 내 방문",
                            threads: store.activeThreads
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
                        showNewThread = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $showNewThread) {
                NewThreadSheet()
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
    
    // MARK: - 이어서 생각하기 카드 (Hero Section)
    @ViewBuilder
    private func resumeSection(thread: ThoughtThread) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.orange)
                Text("여기서 이어서")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(thread.bridge.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // 스레드 제목
                HStack(spacing: 8) {
                    Text(thread.emoji)
                        .font(.title2)
                    Text(thread.title)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                // 현재 상태 (여기까지 옴)
                if !thread.bridge.currentState.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("여기까지 왔어요", systemImage: "mappin.circle.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                        Text(thread.bridge.currentState)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // 다음 질문 (여기서부터 시작)
                if !thread.bridge.nextQuestion.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("다음에 생각할 것", systemImage: "arrow.right.circle.fill")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                        Text(thread.bridge.nextQuestion)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.08))
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
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
    
    // MARK: - 스레드 섹션
    @ViewBuilder
    private func threadSection(title: String, subtitle: String, threads: [ThoughtThread]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
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
