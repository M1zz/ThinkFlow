import SwiftUI

// MARK: - Progressive Summarization 레이어 시각 규칙 (앱 공통)

extension ThoughtEntry {
    /// 레이어별 강조색 — 메모=회색, 정리=파랑, 핵심=보라, 요약=주황
    var layerAccent: Color {
        switch layer {
        case 1: return .blue
        case 2: return .purple
        case 3: return .orange
        default: return Color.gray.opacity(0.5)
        }
    }
}

/// 레이어(메모/정리/핵심/요약)를 나타내는 작은 배지. 표시 전용.
struct LayerBadge: View {
    let entry: ThoughtEntry

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(entry.layerAccent)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(entry.layerLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(entry.layerAccent)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(entry.layerAccent.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("정리 단계 \(entry.layerLabel)")
    }
}

// MARK: - 지금까지의 흐름 (재진입 맥락 복원, 카드 공통)

/// 스레드를 다시 열 때 맥락을 복원해 주는 요약 블록.
/// 정제된 핵심(핵심/요약) + 직전 생각을 레이어 배지와 함께 보여준다.
/// 배경/패딩은 호출하는 카드 쪽에서 감싼다.
struct ThreadRecapView: View {
    let thread: ThoughtThread

    // 핵심(정제된 최신 생각) + 직전 생각 — 둘이 같으면 한 번만
    private var recapEntries: [ThoughtEntry] {
        var result: [ThoughtEntry] = []
        if let core = thread.latestCore {
            result.append(core)
        }
        if let last = thread.lastEntry, !result.contains(where: { $0.id == last.id }) {
            result.append(last)
        }
        return result
    }

    private var metaLine: String {
        var parts: [String] = ["\(thread.entryCount)개 생각"]
        let days = thread.daysSinceBridge
        if days > 0 {
            parts.append("\(days)일 전 끊어둠")
        }
        if thread.totalThinkingSeconds >= 60 {
            parts.append("누적 \(thread.formattedThinkingTime)")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        if !recapEntries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label("지금까지의 흐름", systemImage: "list.bullet.indent")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(metaLine)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityElement(children: .combine)

                ForEach(recapEntries) { entry in
                    ThreadRecapRow(entry: entry, isLast: entry.id == thread.lastEntry?.id)
                }
            }
        }
    }
}

/// 흐름 블록의 한 줄 — 레이어 배지 + 내용. 핵심은 진하게, 그 외는 흐리게.
struct ThreadRecapRow: View {
    let entry: ThoughtEntry
    let isLast: Bool

    private var isCore: Bool { entry.layer >= 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                LayerBadge(entry: entry)
                if isLast {
                    Text("직전 생각")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }
            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(isCore ? .primary : .secondary)
                .lineSpacing(3)
                .lineLimit(isCore ? 4 : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isLast ? "직전 생각" : entry.layerLabel): \(entry.content)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        LayerBadge(entry: ThoughtEntry(content: "", layer: 0))
        LayerBadge(entry: ThoughtEntry(content: "", layer: 1))
        LayerBadge(entry: ThoughtEntry(content: "", layer: 2))
        LayerBadge(entry: ThoughtEntry(content: "", layer: 3))
        Divider()
        ThreadRecapView(thread: ThoughtThread.sampleThreads[0])
    }
    .padding()
}
