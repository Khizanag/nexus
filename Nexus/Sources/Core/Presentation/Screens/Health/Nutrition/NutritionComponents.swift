import SwiftUI
import SwiftData

// MARK: - Nutrition Summary Card

struct NutritionSummaryCard: View {
    let calories: Double
    let calorieGoal: Double
    let carbs: Double
    let carbsGoal: Double
    let protein: Double
    let proteinGoal: Double
    let fats: Double
    let fatsGoal: Double

    private var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return calories / calorieGoal
    }

    var body: some View {
        NexusCard {
            HStack(spacing: 20) {
                calorieRing
                Spacer()
                macroRings
            }
        }
    }
}

// MARK: - Summary Card Subviews

private extension NutritionSummaryCard {
    var calorieRing: some View {
        VStack(spacing: 4) {
            NutritionProgressRing(
                progress: calorieProgress,
                color: .nexusOrange,
                lineWidth: 12,
                icon: "flame.fill",
                showLabel: true,
                label: "kcal",
                value: formatNumber(calories)
            )
            .frame(width: 110, height: 110)

            Text("\(formatNumber(max(calorieGoal - calories, 0))) left")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
    }

    var macroRings: some View {
        VStack(spacing: 12) {
            MiniMacroRing(
                current: carbs,
                goal: carbsGoal,
                color: .nexusBlue,
                icon: "leaf.fill",
                label: "Carbs"
            )
            MiniMacroRing(
                current: protein,
                goal: proteinGoal,
                color: .nexusRed,
                icon: "fish.fill",
                label: "Protein"
            )
            MiniMacroRing(
                current: fats,
                goal: fatsGoal,
                color: .nexusPurple,
                icon: "drop.fill",
                label: "Fats"
            )
        }
    }

    func formatNumber(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Meal Section Card

struct MealSectionCard: View {
    let mealType: MealType
    let entries: [NutritionEntryModel]
    let onAddTap: () -> Void
    let onEntryTap: (NutritionEntryModel) -> Void

    @State private var isExpanded = true

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NexusCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                if isExpanded {
                    content
                }
            }
        }
    }
}

// MARK: - Meal Section Subviews

private extension MealSectionCard {
    var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: mealType.icon)
                    .font(.nexusHeadline)
                    .foregroundStyle(mealTypeColor)

                Text(mealType.displayName)
                    .font(.nexusHeadline)
                    .foregroundStyle(Color.nexusTextPrimary)

                Spacer()

                Text("\(Int(totalCalories)) kcal")
                    .font(.nexusSubheadline)
                    .foregroundStyle(Color.nexusTextSecondary)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    var content: some View {
        VStack(spacing: 8) {
            if entries.isEmpty {
                emptyState
            } else {
                ForEach(entries, id: \.id) { entry in
                    NutritionEntryRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture { onEntryTap(entry) }
                }
            }
            addButton
        }
    }

    var emptyState: some View {
        Text("No entries yet")
            .font(.nexusCaption)
            .foregroundStyle(Color.nexusTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    var addButton: some View {
        Button(action: onAddTap) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Food")
            }
            .font(.nexusSubheadline)
            .foregroundStyle(mealTypeColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(mealTypeColor.opacity(0.1))
            }
        }
        .buttonStyle(.plain)
    }

    var mealTypeColor: Color {
        switch mealType.color {
        case "orange": .nexusOrange
        case "blue": .nexusBlue
        case "purple": .nexusPurple
        case "green": .nexusGreen
        default: .nexusTextSecondary
        }
    }
}

// MARK: - Nutrition Entry Row

struct NutritionEntryRow: View {
    let entry: NutritionEntryModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.nexusBody)
                    .foregroundStyle(Color.nexusTextPrimary)
                    .lineLimit(1)

                Text(servingText)
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextTertiary)
            }

            Spacer()

            HStack(spacing: 16) {
                macroLabel(value: entry.carbs, label: "C", color: .nexusBlue)
                macroLabel(value: entry.protein, label: "P", color: .nexusRed)
                macroLabel(value: entry.fats, label: "F", color: .nexusPurple)

                Text("\(Int(entry.calories))")
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.nexusOrange)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    private var servingText: String {
        if entry.servingSize == 1 {
            return "1 \(entry.servingUnit)"
        }
        return "\(String(format: "%.1f", entry.servingSize)) \(entry.servingUnit)"
    }

    private func macroLabel(value: Double, label: String, color: Color) -> some View {
        Text("\(label)\(Int(value))")
            .font(.nexusCaption)
            .foregroundStyle(color)
    }
}

// MARK: - Product Row

struct ProductRow: View {
    let product: ProductModel
    var showFavorite: Bool = true
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.name)
                            .font(.nexusBody)
                            .foregroundStyle(Color.nexusTextPrimary)
                            .lineLimit(1)

                        if showFavorite, product.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.nexusOrange)
                        }
                    }

                    if !product.brand.isEmpty {
                        Text(product.brand)
                            .font(.nexusCaption)
                            .foregroundStyle(Color.nexusTextTertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(product.calories)) kcal")
                        .font(.nexusSubheadline)
                        .foregroundStyle(Color.nexusOrange)

                    Text("per \(product.servingUnit)")
                        .font(.nexusCaption)
                        .foregroundStyle(Color.nexusTextTertiary)
                }

                Image(systemName: "plus.circle.fill")
                    .font(.nexusTitle3)
                    .foregroundStyle(Color.nexusGreen)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Add Tile

struct QuickAddTile: View {
    let product: ProductModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(product.name)
                        .font(.nexusCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.nexusTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    if product.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.nexusOrange)
                    }
                }

                Spacer()

                Text("\(Int(product.calories)) kcal")
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusOrange)
            }
            .padding(10)
            .frame(width: 100, height: 80)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Macro Input Field

struct MacroInputField: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var value: Double
    var unit: String = "g"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.nexusCaption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextSecondary)
            }

            HStack {
                TextField("0", value: $value, format: .number)
                    .font(.nexusHeadline)
                    .foregroundStyle(Color.nexusTextPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)

                Text(unit)
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.nexusSurfaceSecondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(color.opacity(0.3), lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: - Previews

#Preview("Summary Card") {
    NutritionSummaryCard(
        calories: 1450,
        calorieGoal: 2000,
        carbs: 180,
        carbsGoal: 250,
        protein: 95,
        proteinGoal: 150,
        fats: 55,
        fatsGoal: 65
    )
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}

#Preview("Entry Row") {
    VStack {
        NutritionEntryRow(
            entry: NutritionEntryModel(
                name: "Chicken Breast",
                calories: 165,
                carbs: 0,
                protein: 31,
                fats: 3.6,
                servingSize: 100,
                servingUnit: "g"
            )
        )
        NutritionEntryRow(
            entry: NutritionEntryModel(
                name: "Brown Rice",
                calories: 216,
                carbs: 45,
                protein: 5,
                fats: 1.8,
                servingSize: 1,
                servingUnit: "cup"
            )
        )
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
