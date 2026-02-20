import SwiftUI

struct EntryRowView: View {
    
    let entry: ThoughtEntry
    var onLayerChange: ((Int) -> Void)?
    
    @State private var showLayerPicker = false
    
    private var layerAccent: Color {
        switch entry.layer {
        case 0: return .gray
        case 1: return .blue
        case 2: return .purple
        case 3: return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 타임라인 헤더
            HStack(spacing: 8) {
                // 레이어 뱃지
                Button {
                    showLayerPicker.toggle()
                } label: {
                    Text(entry.layerLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(layerAccent.opacity(0.15))
                        .foregroundStyle(layerAccent)
                        .clipShape(Capsule())
                }
                
                Text(entry.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Text(entry.createdAt.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            
            // 내용
            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(entry.layer >= 2 ? .primary : .secondary)
                .fontWeight(entry.layer >= 2 ? .medium : .regular)
                .lineSpacing(3)
            
            // Progressive Summarization 레이어 선택
            if showLayerPicker {
                layerPicker
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(14)
        .background(layerAccent.opacity(entry.layer >= 2 ? 0.06 : 0.02))
        .overlay(
            Rectangle()
                .fill(layerAccent)
                .frame(width: 3),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.2), value: showLayerPicker)
    }
    
    // MARK: - 레이어 선택기
    private var layerPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Progressive Summarization 레이어")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { layer in
                    let labels = ["메모", "정리", "핵심", "요약"]
                    let colors: [Color] = [.gray, .blue, .purple, .orange]
                    
                    Button {
                        withAnimation {
                            onLayerChange?(layer)
                            showLayerPicker = false
                        }
                    } label: {
                        Text(labels[layer])
                            .font(.caption)
                            .fontWeight(entry.layer == layer ? .bold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(entry.layer == layer ? colors[layer].opacity(0.2) : .clear)
                            .foregroundStyle(colors[layer])
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(colors[layer].opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(.top, 4)
    }
}

#Preview {
    VStack(spacing: 12) {
        EntryRowView(
            entry: ThoughtEntry(content: "이것은 날것의 메모입니다. 아직 정리되지 않은 상태.", layer: 0)
        )
        EntryRowView(
            entry: ThoughtEntry(content: "정리된 메모. 구조가 잡히기 시작함.", layer: 1)
        )
        EntryRowView(
            entry: ThoughtEntry(content: "핵심 인사이트: 보상 지연 시간의 격차가 깊은 사고를 방해한다", layer: 2)
        )
        EntryRowView(
            entry: ThoughtEntry(content: "최종 요약: 깊은 사고를 위해서는 외부 앵커와 진입 비용 최소화가 필수", layer: 3)
        )
    }
    .padding()
}
