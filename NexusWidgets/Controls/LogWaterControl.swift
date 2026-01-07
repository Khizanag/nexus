import WidgetKit
import SwiftUI
import AppIntents

struct LogWaterControl: ControlWidget {
    static let kind = "com.khizanag.nexus.logWater"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LogWaterIntent()) {
                Label("Log Water", systemImage: "drop.fill")
            }
        }
        .displayName("Log Water")
        .description("Quickly log 250ml of water")
    }
}

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description: IntentDescription = "Log 250ml of water"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        WidgetDataStore.setPendingAction(.logWater)
        return .result()
    }
}
