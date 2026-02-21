import WidgetKit
import SwiftUI

@main
struct ThinkFlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        ThinkFlowWidget()
        ThinkingSessionLiveActivity()
    }
}
