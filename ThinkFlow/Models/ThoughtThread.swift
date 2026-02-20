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
    var currentState: String   // 현재 상태: 여기까지 생각함
    var nextQuestion: String   // 다음 질문: 다음에 이어서 생각할 것
    var updatedAt: Date
    
    init(currentState: String = "", nextQuestion: String = "", updatedAt: Date = Date()) {
        self.currentState = currentState
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
}

// MARK: - 샘플 데이터
extension ThoughtThread {
    static let sampleThreads: [ThoughtThread] = [
        ThoughtThread(
            title: "숏폼 vs 딥워크",
            emoji: "🧠",
            bridge: HemingwayBridge(
                currentState: "숏폼 콘텐츠가 주의력을 분산시키는 메커니즘까지 정리함. 도파민 보상 회로와 연결.",
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
                currentState: "앱 20개 운영하면서 느낀 패턴들 정리 중. 80/20 법칙이 앱 포트폴리오에도 적용됨.",
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
