import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "이어생각 위젯" }
    static var description: IntentDescription { "가장 최근 생각 스레드의 브릿지를 보여줍니다." }
}
