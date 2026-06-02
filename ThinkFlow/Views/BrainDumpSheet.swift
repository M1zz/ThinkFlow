import SwiftUI

struct BrainDumpSheet: View {

    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var rawText = ""
    @State private var phase: Phase = .dump
    @State private var parsedItems: [String] = []
    @State private var selectedIndex: Int? = nil
    @FocusState private var isTextFocused: Bool

    enum Phase { case dump, sort }

    private var parsedLines: [String] {
        rawText.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .dump: dumpPhase
                case .sort: sortPhase
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(phase == .dump ? "생각 꺼내기" : "어떤 것부터?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if phase == .dump {
                        Button("다 꺼냈어요") {
                            let lines = parsedLines
                            if lines.count == 1 {
                                // 하나면 바로 스레드로
                                startWithSelected(0, from: lines)
                            } else {
                                parsedItems = lines
                                withAnimation(.easeInOut(duration: 0.25)) { phase = .sort }
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(parsedLines.isEmpty)
                    }
                }
            }
        }
        .onAppear { isTextFocused = true }
    }

    // MARK: - Phase 1: 덤프

    private var dumpPhase: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("지금 머릿속에 있는 거 꺼내세요")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("하나든 열 개든 괜찮아요. 줄바꿈으로 생각을 구분하세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $rawText)
                        .focused($isTextFocused)
                        .frame(minHeight: 320)
                        .scrollContentBackground(.hidden)
                        .font(.body)
                        .lineSpacing(6)
                        .accessibilityLabel("생각 꺼내기 입력란")
                        .accessibilityHint("줄바꿈으로 생각을 여러 개로 구분합니다")

                    if !parsedLines.isEmpty {
                        HStack {
                            Spacer()
                            Text("\(parsedLines.count)개의 생각")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(20)
        }
    }

    // MARK: - Phase 2: 선별

    private var sortPhase: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("지금 당장 하나만 고른다면?")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("선택한 것은 바로 생각 스레드가 됩니다. 나머지는 보관됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                VStack(spacing: 8) {
                    ForEach(parsedItems.indices, id: \.self) { index in
                        dumpItemButton(index: index)
                    }
                }

                VStack(spacing: 10) {
                    if let idx = selectedIndex {
                        Button {
                            startWithSelected(idx)
                        } label: {
                            Text("이걸로 시작하기")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.orange.gradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button {
                        saveAllToDump()
                    } label: {
                        Text(selectedIndex == nil ? "전부 보관하기" : "선택 없이 전부 보관")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    // MARK: - 아이템 버튼

    @ViewBuilder
    private func dumpItemButton(index: Int) -> some View {
        let isSelected = selectedIndex == index
        Button {
            withAnimation(.spring(duration: 0.2)) {
                selectedIndex = isSelected ? nil : index
            }
        } label: {
            HStack(alignment: .top) {
                Text(parsedItems[index])
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.orange : Color.secondary.opacity(0.4))
                    .font(.body)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(isSelected ? Color.orange.opacity(0.08) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("두 번 탭하면 선택합니다")
    }

    // MARK: - Actions

    private func startWithSelected(_ index: Int, from items: [String]? = nil) {
        let source = items ?? parsedItems
        let selected = source[index]
        let others = source.enumerated()
            .filter { $0.offset != index }
            .map { $0.element }

        let title = ThoughtStore.extractTitle(from: selected)
        let thread = ThoughtThread(
            title: title.isEmpty ? selected : title,
            entries: [ThoughtEntry(content: selected)]
        )
        store.addThread(thread)
        store.addDumpItems(others)
        dismiss()
    }

    private func saveAllToDump() {
        store.addDumpItems(parsedItems)
        dismiss()
    }
}

#Preview {
    BrainDumpSheet()
        .environment(ThoughtStore())
}
