import SwiftUI
import UIKit

struct ThreadDetailView: View {
    
    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    let thread: ThoughtThread
    
    @State private var showContinueSheet = false
    @State private var showBridgeEditor = false
    @State private var showDeleteAlert = false
    @State private var sortNewestFirst = true
    @State private var allCopied = false
    @State private var editingEntry: ThoughtEntry?
    
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
                .accessibilityLabel("더 보기")
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
        .sheet(item: $editingEntry) { entry in
            EntryEditSheet(entry: entry) { newContent in
                store.updateEntryContent(
                    threadID: currentThread.id,
                    entryID: entry.id,
                    content: newContent
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
    
    // MARK: - 브릿지 섹션
    private var bridgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("끊어둔 문장", systemImage: "arrow.turn.down.right")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("수정", systemImage: "pencil") {
                    showBridgeEditor = true
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("끊어둔 문장 수정")
            }

            if !currentThread.bridge.nextQuestion.isEmpty {
                Text(currentThread.bridge.nextQuestion)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
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
            } else {
                Text("기세가 있을 때 문장을 끊어두세요.\n다음에 열면 뇌가 자동으로 이어받습니다.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineSpacing(3)
                    .padding(14)
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
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
    
    // MARK: - 엔트리 타임라인
    private var entriesSection: some View {
        let sorted = currentThread.entries.sorted {
            sortNewestFirst ? $0.createdAt > $1.createdAt : $0.createdAt < $1.createdAt
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("생각의 흐름")
                    .font(.title3)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                Spacer()

                // 전체 복사
                if !sorted.isEmpty {
                    Button {
                        let text = sorted.map { "[\($0.layerLabel)] \($0.content)" }
                            .joined(separator: "\n\n")
                        UIPasteboard.general.string = text
                        withAnimation { allCopied = true }
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation { allCopied = false }
                        }
                    } label: {
                        Label(allCopied ? "복사됨" : "전체 복사",
                              systemImage: allCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(allCopied ? .green : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }

                // 정렬 토글
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sortNewestFirst.toggle()
                    }
                } label: {
                    Label(sortNewestFirst ? "최신순" : "오래된순",
                          systemImage: sortNewestFirst ? "arrow.down" : "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if sorted.isEmpty {
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
                ForEach(sorted) { entry in
                    EntryRowView(
                        entry: entry,
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
        }
    }
}

#Preview {
    NavigationStack {
        ThreadDetailView(thread: ThoughtThread.sampleThreads[0])
            .environment(ThoughtStore())
    }
}
