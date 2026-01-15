import Foundation
import SwiftData

@Model
final class NutritionEntryModel {
    var id: UUID = UUID()
    var name: String = ""
    var calories: Double = 0
    var carbs: Double = 0
    var protein: Double = 0
    var fats: Double = 0
    var servingSize: Double = 1
    var servingUnit: String = "serving"
    var mealType: MealType = MealType.snack
    var date: Date = Date()
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify)
    var product: ProductModel?

    init(
        id: UUID = UUID(),
        name: String = "",
        calories: Double = 0,
        carbs: Double = 0,
        protein: Double = 0,
        fats: Double = 0,
        servingSize: Double = 1,
        servingUnit: String = "serving",
        mealType: MealType = .snack,
        date: Date = .now,
        notes: String = "",
        createdAt: Date = .now,
        product: ProductModel? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.carbs = carbs
        self.protein = protein
        self.fats = fats
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.mealType = mealType
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
        self.product = product
    }
}

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack

    var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sun.horizon.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        }
    }

    var color: String {
        switch self {
        case .breakfast: "orange"
        case .lunch: "blue"
        case .dinner: "purple"
        case .snack: "green"
        }
    }

    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        case .snack: 3
        }
    }
}

enum MacroType: String, CaseIterable {
    case calories
    case carbs
    case protein
    case fats

    var displayName: String {
        switch self {
        case .calories: "Calories"
        case .carbs: "Carbs"
        case .protein: "Protein"
        case .fats: "Fats"
        }
    }

    var shortName: String {
        switch self {
        case .calories: "kcal"
        case .carbs: "g"
        case .protein: "g"
        case .fats: "g"
        }
    }

    var icon: String {
        switch self {
        case .calories: "flame.fill"
        case .carbs: "leaf.fill"
        case .protein: "fish.fill"
        case .fats: "drop.fill"
        }
    }

    var color: String {
        switch self {
        case .calories: "orange"
        case .carbs: "blue"
        case .protein: "red"
        case .fats: "purple"
        }
    }
}
