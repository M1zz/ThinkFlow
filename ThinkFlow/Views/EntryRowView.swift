import SwiftUI
import UIKit

struct EntryRowView: View {

    let entry: ThoughtEntry
    var onLayerChange: ((Int) -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var copied = false

    // 레이어(Progressive Summarization) 메타데이터
    static let layerNames = ["메모", "정리", "핵심", "요약"]
    static let layerHints = ["날것의 생각", "한 번 정리함", "핵심만 추림", "최종 요약"]

    private func accent(for layer: Int) -> Color {
        switch layer {
        case 1: return .blue
        case 2: return .purple
        case 3: return .orange
        default: return .gray.opacity(0.5)
        }
    }

    private var layerAccent: Color { accent(for: entry.layer) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // 헤더
            HStack(spacing: 6) {
                // 레이어 승급 칩 (Progressive Summarization)
                layerBadge

                HStack(spacing: 6) {
                    Text(entry.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)

                    Text(entry.createdAt.formatted(.dateTime.month().day().hour().minute()))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityElement(children: .combine)

                Spacer()

                Button {
                    UIPasteboard.general.string = entry.content
                    UIAccessibility.post(notification: .announcement, argument: "복사되었습니다")
                    withAnimation(.spring(duration: 0.2)) { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline)
                        .foregroundStyle(copied ? Color.green : Color.secondary.opacity(0.5))
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel("복사")
                .accessibilityHint("이 생각을 클립보드에 복사합니다")
            }

            // 내용
            Text(entry.content)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(5)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(layerAccent)
                .frame(width: 3),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button {
                onEdit?()
            } label: {
                Label("수정", systemImage: "pencil")
            }
            Button {
                UIPasteboard.general.string = entry.content
            } label: {
                Label("복사", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    // MARK: - 레이어 승급 배지

    private var layerBadge: some View {
        Menu {
            Text("정리 단계")
            ForEach(Self.layerNames.indices, id: \.self) { lvl in
                Button {
                    onLayerChange?(lvl)
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "\(Self.layerNames[lvl]) 단계로 변경됨"
                    )
                } label: {
                    if entry.layer == lvl {
                        Label("\(Self.layerNames[lvl]) · \(Self.layerHints[lvl])", systemImage: "checkmark")
                    } else {
                        Text("\(Self.layerNames[lvl]) · \(Self.layerHints[lvl])")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(layerAccent)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text(entry.layerLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(layerAccent)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(layerAccent.opacity(0.12))
            .clipShape(Capsule())
        }
        .accessibilityLabel("정리 단계, 현재 \(entry.layerLabel)")
        .accessibilityHint("두 번 탭하면 단계를 바꿉니다")
    }
}

// MARK: - 엔트리 수정 시트

struct EntryEditSheet: View {

    @Environment(\.dismiss) private var dismiss

    let entry: ThoughtEntry
    var onSave: (String) -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(entry: ThoughtEntry, onSave: @escaping (String) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _text = State(initialValue: entry.content)
    }

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                        .font(.body)
                        .lineSpacing(4)
                }
                .padding(16)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("생각 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        onSave(text)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasContent)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        EntryRowView(entry: ThoughtEntry(content: "날것의 생각. 아직 정리되지 않은 상태.", layer: 0))
        EntryRowView(entry: ThoughtEntry(content: "핵심 인사이트: 보상 지연 시간의 격차가 깊은 사고를 방해한다", layer: 2))
        EntryRowView(entry: ThoughtEntry(content: "최종 요약: 외부 앵커와 진입 비용 최소화가 필수", layer: 3))
    }
    .padding()
}
