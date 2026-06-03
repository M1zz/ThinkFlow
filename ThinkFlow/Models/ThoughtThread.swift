import Foundation

// MARK: - 사고 엔트리 (하나의 생각 기록)
struct ThoughtEntry: Identifiable, Codable {
    let id: UUID
    var content: String
    var layer: Int // Progressive Summarization 레이어 (0: 날것, 1: 볼드, 2: 하이라이트, 3: 요약)
    let createdAt: Date
    
    init(id: UUID = UUID(), content: String, layer: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.layer = layer
        self.createdAt = createdAt
    }
    
    var layerLabel: String {
        switch layer {
        case 0: return "메모"
        case 1: return "정리"
        case 2: return "핵심"
        case 3: return "요약"
        default: return "메모"
        }
    }
    
    var layerColor: String {
        switch layer {
        case 0: return "entryLayer0"
        case 1: return "entryLayer1"
        case 2: return "entryLayer2"
        case 3: return "entryLayer3"
        default: return "entryLayer0"
        }
    }
}

// MARK: - 헤밍웨이 브릿지 (사고의 북마크)
struct HemingwayBridge: Codable, Equatable {
    var nextQuestion: String   // 다음 질문: 다음에 이어서 생각할 것 (끊어둔 문장)
    var updatedAt: Date

    init(nextQuestion: String = "", updatedAt: Date = Date()) {
        self.nextQuestion = nextQuestion
        self.updatedAt = updatedAt
    }
}

// MARK: - 생각 스레드 (하나의 사고 흐름)
struct ThoughtThread: Identifiable, Codable {
    let id: UUID
    var title: String
    var emoji: String
    var bridge: HemingwayBridge
    var entries: [ThoughtEntry]
    let createdAt: Date
    var lastVisitedAt: Date
    var totalThinkingSeconds: Int // 누적 사고 시간
    
    init(
        id: UUID = UUID(),
        title: String,
        emoji: String = "💭",
        bridge: HemingwayBridge = HemingwayBridge(),
        entries: [ThoughtEntry] = [],
        createdAt: Date = Date(),
        lastVisitedAt: Date = Date(),
        totalThinkingSeconds: Int = 0
    ) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.bridge = bridge
        self.entries = entries
        self.createdAt = createdAt
        self.lastVisitedAt = lastVisitedAt
        self.totalThinkingSeconds = totalThinkingSeconds
    }
    
    var daysSinceLastVisit: Int {
        Calendar.current.dateComponents([.day], from: lastVisitedAt, to: Date()).day ?? 0
    }
    
    var formattedThinkingTime: String {
        let hours = totalThinkingSeconds / 3600
        let minutes = (totalThinkingSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        } else {
            return "\(minutes)분"
        }
    }
    
    var entryCount: Int {
        entries.count
    }
    
    var highestLayer: Int {
        entries.map(\.layer).max() ?? 0
    }
    
    // 가장 최근 엔트리의 Progressive Summarization 진행도
    var progressionRatio: Double {
        guard !entries.isEmpty else { return 0 }
        let maxLayer = 3.0
        let avgLayer = Double(entries.map(\.layer).reduce(0, +)) / Double(entries.count)
        return avgLayer / maxLayer
    }

    // 시간순(과거 → 최신) 정렬된 엔트리
    var chronologicalEntries: [ThoughtEntry] {
        entries.sorted { $0.createdAt < $1.createdAt }
    }

    // 최신순(최신 → 과거) 정렬된 엔트리
    var reverseChronologicalEntries: [ThoughtEntry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    // 직전 생각 (가장 최근 엔트리)
    var lastEntry: ThoughtEntry? {
        reverseChronologicalEntries.first
    }

    // 첫 생각 (가장 오래된 엔트리)
    var firstEntry: ThoughtEntry? {
        chronologicalEntries.first
    }

    // 화면에 보여줄 제목 — 저장된 제목이 첫 생각의 앞부분이 잘린 형태면
    // 첫 생각의 첫 문장 전체를 복원해서 보여준다 (저장 데이터는 그대로 둠).
    var displayTitle: String {
        guard let content = firstEntry?.content else { return title }
        let firstSentence = content
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let candidate = firstSentence.isEmpty ? content : firstSentence
        if candidate.count > title.count && candidate.hasPrefix(title) {
            return candidate
        }
        return title
    }

    // 정제된 핵심 생각 (핵심/요약 레이어). 가장 최근 것이 마지막.
    var distilledEntries: [ThoughtEntry] {
        chronologicalEntries.filter { $0.layer >= 2 }
    }

    // 가장 최근의 정제된 핵심 (없으면 nil)
    var latestCore: ThoughtEntry? {
        distilledEntries.last
    }

    // 재진입 시 맥락 복원에 쓸 요약 — 며칠 전에 끊었는지
    var daysSinceBridge: Int {
        Calendar.current.dateComponents([.day], from: bridge.updatedAt, to: Date()).day ?? 0
    }
}

// MARK: - 덤프 아이템 (아직 정리되지 않은 생각 조각)
struct DumpItem: Identifiable, Codable {
    let id: UUID
    var content: String
    let createdAt: Date

    init(id: UUID = UUID(), content: String, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - 샘플 데이터
extension ThoughtThread {
    static let sampleThreads: [ThoughtThread] = [
        ThoughtThread(
            title: "숏폼 vs 딥워크",
            emoji: "🧠",
            bridge: HemingwayBridge(
                nextQuestion: "그렇다면 '의도적 지루함'을 설계하면 깊은 사고가 회복될까?",
                updatedAt: Date().addingTimeInterval(-3600)
            ),
            entries: [
                ThoughtEntry(content: "숏폼은 30초 안에 보상을 주는 구조. 깊은 생각은 보상까지 시간이 오래 걸림. 이 격차가 문제의 본질인 것 같다.", layer: 0, createdAt: Date().addingTimeInterval(-86400 * 3)),
                ThoughtEntry(content: "핵심: 보상 지연 시간의 격차가 깊은 사고를 방해한다", layer: 2, createdAt: Date().addingTimeInterval(-86400 * 2)),
                ThoughtEntry(content: "Cal Newport의 Deep Work 연구 - 주의력은 근육처럼 훈련 가능. 하루 4시간이 깊은 사고의 상한선이라는 주장.", layer: 1, createdAt: Date().addingTimeInterval(-86400)),
            ],
            createdAt: Date().addingTimeInterval(-86400 * 5),
            lastVisitedAt: Date().addingTimeInterval(-3600),
            totalThinkingSeconds: 2700
        ),
        ThoughtThread(
            title: "1인 개발자 성장 모델",
            emoji: "🚀",
            bridge: HemingwayBridge(
                nextQuestion: "상위 20% 앱에 집중하는 게 나을까, 롱테일 전략이 나을까?",
                updatedAt: Date().addingTimeInterval(-86400)
            ),
            entries: [
                ThoughtEntry(content: "20개 앱 중 실제로 의미 있는 수익을 내는 건 3-4개. 나머지는 학습 자산이자 SEO 역할.", layer: 0, createdAt: Date().addingTimeInterval(-86400 * 7)),
            ],
            createdAt: Date().addingTimeInterval(-86400 * 10),
            lastVisitedAt: Date().addingTimeInterval(-86400),
            totalThinkingSeconds: 1800
        )
    ]
}
