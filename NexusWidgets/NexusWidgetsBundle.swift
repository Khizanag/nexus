import WidgetKit
import SwiftUI

@main
struct NexusWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Control Center Widgets
        OpenAssistantControl()
        LogWaterControl()

        // Home Screen Widgets (for future)
        // TasksWidget()
        // HealthWidget()
    }
}
