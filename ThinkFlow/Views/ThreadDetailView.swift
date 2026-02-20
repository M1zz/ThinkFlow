import SwiftUI

struct ThreadDetailView: View {
    
    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    let thread: ThoughtThread
    
    @State private var showContinueSheet = false
    @State private var showBridgeEditor = false
    @State private var showDeleteAlert = false
    
    private var currentThread: ThoughtThread {
        store.threads.first { $0.id == thread.id } ?? thread
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: - 헤밍웨이 브릿지 (항상 상단)
                bridgeSection
                
                // MARK: - 통계
                statsRow
                
                // MARK: - 엔트리 타임라인
                entriesSection
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(currentThread.emoji) \(currentThread.title)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showBridgeEditor = true
                    } label: {
                        Label("브릿지 수정", systemImage: "bookmark")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showContinueSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil.line")
                    Text("이어서 생각하기")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.orange.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showContinueSheet) {
            ContinueThinkingSheet(thread: currentThread)
        }
        .sheet(isPresented: $showBridgeEditor) {
            BridgeEditorView(thread: currentThread)
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
    
    // MARK: - 브릿지 섹션
    private var bridgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.orange)
                Text("사고의 북마크")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("수정", systemImage: "pencil") {
                    showBridgeEditor = true
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
            
            if !currentThread.bridge.currentState.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("여기까지 왔어요", systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                    Text(currentThread.bridge.currentState)
                        .font(.subheadline)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            if !currentThread.bridge.nextQuestion.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("다음에 생각할 것", systemImage: "arrow.right.circle.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                    Text(currentThread.bridge.nextQuestion)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            if currentThread.bridge.currentState.isEmpty && currentThread.bridge.nextQuestion.isEmpty {
                Text("아직 브릿지가 없습니다. 생각을 멈출 때 '다음에 이어서 생각할 것'을 남겨보세요.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(12)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
    
    // MARK: - 통계
    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(label: "메모", value: "\(currentThread.entryCount)개", icon: "note.text")
            Divider().frame(height: 30)
            statItem(label: "사고 시간", value: currentThread.formattedThinkingTime, icon: "clock")
            Divider().frame(height: 30)
            statItem(label: "깊이", value: "L\(currentThread.highestLayer)", icon: "layers.bottom.fill")
            Divider().frame(height: 30)
            statItem(label: "시작일", value: currentThread.createdAt.formatted(.dateTime.month().day()), icon: "calendar")
        }
        .padding(.vertical, 12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func statItem(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 엔트리 타임라인
    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("생각의 흐름")
                    .font(.headline)
                Spacer()
                Text("최신순")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            let sortedEntries = currentThread.entries.sorted { $0.createdAt > $1.createdAt }
            
            if sortedEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("아직 기록이 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("'이어서 생각하기'를 눌러 첫 기록을 남겨보세요")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(sortedEntries) { entry in
                    EntryRowView(
                        entry: entry,
                        onLayerChange: { newLayer in
                            store.updateEntryLayer(
                                threadID: currentThread.id,
                                entryID: entry.id,
                                newLayer: newLayer
                            )
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ThreadDetailView(thread: ThoughtThread.sampleThreads[0])
            .environment(ThoughtStore())
    }
}
