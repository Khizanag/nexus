import WidgetKit
import SwiftUI
import AppIntents

struct OpenAssistantControl: ControlWidget {
    static let kind = "com.khizanag.nexus.openAssistant"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LaunchAssistantIntent()) {
                Label("AI Assistant", systemImage: "sparkles")
            }
        }
        .displayName("AI Assistant")
        .description("Open Nexus AI Assistant")
    }
}

struct LaunchAssistantIntent: AppIntent {
    static let title: LocalizedStringResource = "Open AI Assistant"
    static let description: IntentDescription = "Opens the Nexus AI Assistant"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        WidgetDataStore.setPendingAction(.openAssistant)
        return .result()
    }
}
