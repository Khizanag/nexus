import Foundation
import SwiftData

@Model
final class HealthEntryModel {
    var id: UUID = UUID()
    var type: HealthMetricType = HealthMetricType.weight
    var value: Double = 0
    var unit: String = ""
    var date: Date = Date()
    var notes: String = ""
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        type: HealthMetricType = .weight,
        value: Double = 0,
        unit: String = "",
        date: Date = .now,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
    }
}

enum HealthMetricType: String, Codable, CaseIterable {
    case weight
    case waterIntake
    case sleep
    case steps
    case calories
    case heartRate
    case bloodPressure
    case mood
    case energy

    var displayName: String {
        switch self {
        case .weight: "Weight"
        case .waterIntake: "Water Intake"
        case .sleep: "Sleep"
        case .steps: "Steps"
        case .calories: "Calories"
        case .heartRate: "Heart Rate"
        case .bloodPressure: "Blood Pressure"
        case .mood: "Mood"
        case .energy: "Energy Level"
        }
    }

    var icon: String {
        switch self {
        case .weight: "scalemass.fill"
        case .waterIntake: "drop.fill"
        case .sleep: "moon.fill"
        case .steps: "figure.walk"
        case .calories: "flame.fill"
        case .heartRate: "heart.fill"
        case .bloodPressure: "waveform.path.ecg"
        case .mood: "face.smiling"
        case .energy: "bolt.fill"
        }
    }

    var defaultUnit: String {
        switch self {
        case .weight: "kg"
        case .waterIntake: "ml"
        case .sleep: "hours"
        case .steps: "steps"
        case .calories: "kcal"
        case .heartRate: "bpm"
        case .bloodPressure: "mmHg"
        case .mood: "1-10"
        case .energy: "1-10"
        }
    }

    var color: String {
        switch self {
        case .weight: "purple"
        case .waterIntake: "blue"
        case .sleep: "indigo"
        case .steps: "green"
        case .calories: "orange"
        case .heartRate: "red"
        case .bloodPressure: "pink"
        case .mood: "yellow"
        case .energy: "teal"
        }
    }
}
