import Foundation
import SwiftData

@Model
final class ProductModel {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var barcode: String = ""
    var calories: Double = 0
    var carbs: Double = 0
    var protein: Double = 0
    var fats: Double = 0
    var defaultServingSize: Double = 1
    var servingUnit: String = "serving"
    var isFavorite: Bool = false
    var usageCount: Int = 0
    var lastUsed: Date?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \NutritionEntryModel.product)
    var entries: [NutritionEntryModel]?

    init(
        id: UUID = UUID(),
        name: String = "",
        brand: String = "",
        barcode: String = "",
        calories: Double = 0,
        carbs: Double = 0,
        protein: Double = 0,
        fats: Double = 0,
        defaultServingSize: Double = 1,
        servingUnit: String = "serving",
        isFavorite: Bool = false,
        usageCount: Int = 0,
        lastUsed: Date? = nil,
        createdAt: Date = .now,
        entries: [NutritionEntryModel]? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.calories = calories
        self.carbs = carbs
        self.protein = protein
        self.fats = fats
        self.defaultServingSize = defaultServingSize
        self.servingUnit = servingUnit
        self.isFavorite = isFavorite
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.createdAt = createdAt
        self.entries = entries
    }
}
