import WidgetKit
import SwiftUI

// MARK: - 위젯 데이터 로더

struct WidgetDataLoader {
    static let appGroupID = "group.com.leeo.thinkflow"
    static let saveKey = "thought_threads_v1"

    static func loadThreads() -> [ThoughtThread] {
        let defaults = UserDefaults(suiteName: appGroupID)
        guard let data = defaults?.data(forKey: saveKey),
              let threads = try? JSONDecoder().decode([ThoughtThread].self, from: data) else {
            // 실데이터가 없으면 빈 상태를 그대로 보여준다 (샘플을 진짜처럼 띄우지 않음)
            return []
        }
        return threads
    }

    static func mostRecentThread() -> ThoughtThread? {
        loadThreads().sorted { $0.lastVisitedAt > $1.lastVisitedAt }.first
    }

    static func dormantThreads() -> [ThoughtThread] {
        loadThreads().filter { $0.daysSinceLastVisit >= 3 }
            .sorted { $0.daysSinceLastVisit > $1.daysSinceLastVisit }
    }
}

// MARK: - Timeline Entry

struct BridgeEntry: TimelineEntry {
    let date: Date
    let thread: ThoughtThread?
    let dormantThread: ThoughtThread?
}

// MARK: - Timeline Provider

struct BridgeTimelineProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> BridgeEntry {
        BridgeEntry(
            date: .now,
            thread: ThoughtThread.sampleThreads.first,
            dormantThread: nil
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> BridgeEntry {
        let recent = WidgetDataLoader.mostRecentThread()
        let dormant = WidgetDataLoader.dormantThreads().first
        return BridgeEntry(date: .now, thread: recent, dormantThread: dormant)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<BridgeEntry> {
        let recent = WidgetDataLoader.mostRecentThread()
        let dormant = WidgetDataLoader.dormantThreads().first
        let entry = BridgeEntry(date: .now, thread: recent, dormantThread: dormant)
        // 30분마다 갱신
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - 정제된 핵심 한 줄 (위젯 전용, 앱 카드와 동일한 레이어 색 규칙)

struct WidgetCoreLine: View {
    let entry: ThoughtEntry

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(entry.layerAccent)
                .frame(width: 5, height: 5)
            Text(entry.layerLabel)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(entry.layerAccent)
            Text(entry.content)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Small Widget (브릿지 미리보기)

struct SmallWidgetView: View {
    let entry: BridgeEntry

    var body: some View {
        if let thread = entry.thread {
            VStack(alignment: .leading, spacing: 6) {
                // 헤더
                HStack(spacing: 5) {
                    Text(thread.emoji)
                        .font(.callout)
                    Text(thread.title)
                        .font(.caption)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // 다음 질문 (끊어둔 문장)
                if !thread.bridge.nextQuestion.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("다음에 생각할 것", systemImage: "arrow.right.circle.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.orange)
                        Text(thread.bridge.nextQuestion)
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                    }
                }

                // 지금까지의 핵심 (있을 때만)
                if let core = thread.latestCore {
                    WidgetCoreLine(entry: core)
                }

                Spacer(minLength: 0)

                // 하단 CTA
                HStack {
                    Spacer()
                    Label("이어서 생각하기", systemImage: "pencil.line")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.gradient)
                        .clipShape(Capsule())
                }
            }
        } else {
            emptyView
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.largeTitle)
                .foregroundStyle(.orange.opacity(0.6))
            Text("새 생각을 시작하세요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Medium Widget (브릿지 전체 + 되살릴 생각)

struct MediumWidgetView: View {
    let entry: BridgeEntry

    var body: some View {
        if let thread = entry.thread {
            HStack(spacing: 12) {
                // 왼쪽: 메인 브릿지
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Text(thread.emoji)
                            .font(.callout)
                        Text(thread.title)
                            .font(.caption)
                            .fontWeight(.bold)
                            .lineLimit(1)
                    }

                    if !thread.bridge.nextQuestion.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("다음에 생각할 것", systemImage: "arrow.right.circle.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.orange)
                            Text(thread.bridge.nextQuestion)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // 지금까지의 핵심 (있을 때만)
                    if let core = thread.latestCore {
                        WidgetCoreLine(entry: core)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)

                // 오른쪽: 통계 + 되살릴 생각
                VStack(alignment: .leading, spacing: 8) {
                    // 진행 통계
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            progressRing(ratio: thread.progressionRatio, layer: thread.highestLayer)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(thread.entryCount)개 메모")
                                    .font(.system(size: 9))
                                Text(thread.formattedThinkingTime)
                                    .font(.system(size: 9))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // 되살릴 생각
                    if let dormant = entry.dormantThread {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 3) {
                                Image(systemName: "moon.zzz.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.purple)
                                Text("되살릴 생각")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.purple)
                            }
                            HStack(spacing: 3) {
                                Text(dormant.emoji)
                                    .font(.system(size: 10))
                                Text(dormant.title)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                            Text("\(dormant.daysSinceLastVisit)일째 잠자는 중")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.purple.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            emptyView
        }
    }

    private func progressRing(ratio: Double, layer: Int) -> some View {
        ZStack {
            Circle()
                .stroke(.gray.opacity(0.15), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(.orange.gradient, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("L\(layer)")
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(width: 26, height: 26)
    }

    private var emptyView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.largeTitle)
                    .foregroundStyle(.orange.opacity(0.6))
                Text("새 생각을 시작하세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Adaptive Widget View

struct ThinkFlowWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: BridgeEntry

    var body: some View {
        switch widgetFamily {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct ThinkFlowWidget: Widget {
    let kind: String = "widget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: BridgeTimelineProvider()
        ) { entry in
            ThinkFlowWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(Self.deepLinkURL(for: entry.thread))
        }
        .configurationDisplayName("이어생각")
        .description("멈춘 생각을 이어가세요. 헤밍웨이 브릿지를 홈 화면에서 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }

    // 탭하면 해당 스레드의 이어가기 시트가 바로 열리도록 스레드 id를 실어 보낸다
    static func deepLinkURL(for thread: ThoughtThread?) -> URL? {
        guard let thread else { return URL(string: "thinkflow://continue") }
        return URL(string: "thinkflow://continue?threadId=\(thread.id.uuidString)")
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    ThinkFlowWidget()
} timeline: {
    BridgeEntry(date: .now, thread: ThoughtThread.sampleThreads.first, dormantThread: nil)
}

#Preview(as: .systemMedium) {
    ThinkFlowWidget()
} timeline: {
    BridgeEntry(
        date: .now,
        thread: ThoughtThread.sampleThreads.first,
        dormantThread: ThoughtThread.sampleThreads.last
    )
}
