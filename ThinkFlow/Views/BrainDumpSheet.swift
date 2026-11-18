import SwiftUI
import AppIntents

struct BrainDumpSheet: View {

    @Environment(ThoughtStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var rawText = ""
    /// 함께 올릴 사진 — 시작하는 생각의 첫 글에 붙는다.
    @State private var photos: [String] = []
    @State private var phase: Phase = .dump
    @State private var parsedItems: [String] = []
    @State private var selectedIndex: Int? = nil
    @FocusState private var isTextFocused: Bool
    /// 칸이 다 차서 시작하지 못한 생각. 페이월이 닫히면 Pro 면 시작하고, 아니면 목록에 남긴다.
    @State private var heldStart: HeldStart?
    @State private var showPaywall = false
    private var pro: ProStore { .shared }

    enum Phase { case dump, sort }

    struct HeldStart {
        let index: Int
        let items: [String]
    }

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
            .background(Color.appBackground)
            .navigationTitle(phase == .dump ? String(localized: "생각 꺼내기") : String(localized: "어떤 것부터?"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .barLeading) {
                    Button("취소", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .barConfirm) {
                    if phase == .dump {
                        Button("다 꺼냈어요", systemImage: "checkmark") {
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
        .sheet(isPresented: $showPaywall, onDismiss: resumeHeldStart) {
            ProPaywallView(reason: .threadLimit)
        }
        .onAppear {
            isTextFocused = true
            #if DEBUG
            if ScreenshotScene.scene == "dump" { rawText = ScreenshotScene.seed?.dumpText ?? "" }
            #endif
        }
    }

    // MARK: - Phase 1: 덤프

    private var dumpPhase: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PostRow {
                    PostAvatar(kind: .thought("💭"))
                } content: {
                    VStack(alignment: .leading, spacing: 2) {
                        PostAuthor()
                        PostEditor(text: $rawText,
                                   placeholder: String(localized: "지금 머릿속에 있는 거 꺼내세요"),
                                   minHeight: 280,
                                   focus: $isTextFocused)
                            .accessibilityLabel("생각 꺼내기 입력란")
                            .accessibilityHint("줄바꿈으로 생각을 여러 개로 구분합니다")
                        if !photos.isEmpty {
                            PostPhotos(names: photos, height: 110) { name in photos.removeAll { $0 == name } }
                        }
                        PhotoPickerButton(photos: $photos)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("하나든 열 개든 괜찮아요. 줄바꿈으로 생각을 구분하세요.")
                    Spacer(minLength: 8)
                    if !parsedLines.isEmpty {
                        Text("\(parsedLines.count)개의 생각")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, PostMetrics.side)
            .padding(.vertical, 16)
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
                                .frame(maxWidth: .infinity)
                                .postButtonStyle()
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        saveAllToDump()
                    } label: {
                        Text(selectedIndex == nil ? String(localized: "전부 보관하기") : String(localized: "선택 없이 전부 보관"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, PostMetrics.side)
            .padding(.vertical, 16)
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
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.4))
                    .font(.body)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(Color.raisedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 1.5)
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("두 번 탭하면 선택합니다")
    }

    // MARK: - Actions

    private func startWithSelected(_ index: Int, from items: [String]? = nil) {
        let source = items ?? parsedItems
        // 칸이 다 찼다 — 쏟아낸 것을 잃지 않게 붙잡아 두고 페이월을 띄운다.
        guard pro.canStartThread(existing: store.threads.count) else {
            heldStart = HeldStart(index: index, items: source)
            showPaywall = true
            return
        }
        let selected = source[index]
        let others = source.enumerated()
            .filter { $0.offset != index }
            .map { $0.element }

        let title = ThoughtStore.extractTitle(from: selected)
        let thread = ThoughtThread(
            title: title.isEmpty ? selected : title,
            entries: [ThoughtEntry(content: selected, photos: photos)]
        )
        store.addThread(thread)
        store.addDumpItems(others)
        dismiss()
    }

    /// 페이월이 닫혔다. Pro 가 됐으면 고른 생각을 시작하고, 아니면 전부 '정리 안 된 생각들'에 남긴다.
    private func resumeHeldStart() {
        guard let held = heldStart else { return }
        heldStart = nil
        if pro.canStartThread(existing: store.threads.count) {
            startWithSelected(held.index, from: held.items)
        } else {
            store.addDumpItems(held.items, photos: photos)
            dismiss()
        }
    }

    private func saveAllToDump() {
        store.addDumpItems(parsedItems, photos: photos)
        // Siri 가 "생각 던져 두기" 를 이 사람이 자주 하는 일로 알게 한다.
        let intent = DumpThoughtIntent()
        intent.thought = parsedItems.joined(separator: "\n")
        IntentDonationManager.shared.donate(intent: intent)
        dismiss()
    }
}

#Preview {
    BrainDumpSheet()
        .environment(ThoughtStore())
}
