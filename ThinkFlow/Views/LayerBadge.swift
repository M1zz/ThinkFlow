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
                // 메모 단계의 흐린 회색은 글씨로는 너무 옅다 — 글씨만 보조 색으로
                .foregroundStyle(entry.layer == 0 ? Color.secondary : entry.layerAccent)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(entry.layerAccent.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("정리 단계 \(entry.layerLabel)")
    }
}

// MARK: - 다시 들어올 때 되살릴 맥락 (피드의 글 · 이어 쓰는 화면 공통)

extension ThoughtThread {
    /// 핵심(정제된 최신 생각) + 직전 생각 — 둘이 같으면 한 번만.
    var recapEntries: [ThoughtEntry] {
        var result: [ThoughtEntry] = []
        if let core = latestCore {
            result.append(core)
        }
        if let last = lastEntry, !result.contains(where: { $0.id == last.id }) {
            result.append(last)
        }
        return result
    }

    /// "4개 생각 · 2일 전 끊어둠 · 누적 45분"
    var metaLine: String {
        var parts: [String] = [String(localized: "\(entryCount)개 생각")]
        let days = daysSinceBridge
        if days > 0 {
            parts.append(String(localized: "\(days)일 전 끊어둠"))
        }
        if totalThinkingSeconds >= 60 {
            parts.append(String(localized: "누적 \(formattedThinkingTime)"))
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        LayerBadge(entry: ThoughtEntry(content: "", layer: 0))
        LayerBadge(entry: ThoughtEntry(content: "", layer: 1))
        LayerBadge(entry: ThoughtEntry(content: "", layer: 2))
        LayerBadge(entry: ThoughtEntry(content: "", layer: 3))
    }
    .padding()
}
