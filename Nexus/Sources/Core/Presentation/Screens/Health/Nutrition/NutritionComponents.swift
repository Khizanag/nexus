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
        GlassCard {
            HStack(spacing: DesignSystem.Spacing.lg) {
                calorieRing
                Spacer()
                macroRings
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }
}

// MARK: - Summary Card Subviews

private extension NutritionSummaryCard {
    var calorieRing: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
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
            .accessibilityLabel("Calories: \(Int(calories)) of \(Int(calorieGoal))")
            .accessibilityValue("\(Int(calorieProgress * 100)) percent")

            Text("\(formatNumber(max(calorieGoal - calories, 0))) left")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
                .accessibilityHidden(true)
        }
    }

    var macroRings: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
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

    var accessibilitySummary: String {
        "\(Int(calories)) of \(Int(calorieGoal)) calories. " +
        "Carbs: \(Int(carbs))g of \(Int(carbsGoal))g. " +
        "Protein: \(Int(protein))g of \(Int(proteinGoal))g. " +
        "Fats: \(Int(fats))g of \(Int(fatsGoal))g."
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
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
            if reduceMotion {
                isExpanded.toggle()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        } label: {
            HStack {
                Image(systemName: mealType.icon)
                    .font(.nexusHeadline)
                    .foregroundStyle(mealTypeColor)
                    .accessibilityHidden(true)

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
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mealType.displayName), \(Int(totalCalories)) calories")
        .accessibilityHint(isExpanded ? "Collapse" : "Expand")
    }

    var content: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            if entries.isEmpty {
                emptyState
            } else {
                ForEach(entries, id: \.id) { entry in
                    Button {
                        onEntryTap(entry)
                    } label: {
                        NutritionEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(entryAccessibilityLabel(entry))
                    .accessibilityHint("Edit entry")
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
            .padding(.vertical, DesignSystem.Spacing.xs)
            .accessibilityLabel("No entries for \(mealType.displayName)")
    }

    var addButton: some View {
        Button(action: onAddTap) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .accessibilityHidden(true)
                Text("Add Food")
            }
            .font(.nexusSubheadline)
            .foregroundStyle(mealTypeColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(mealTypeColor.opacity(0.1))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add food to \(mealType.displayName)")
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

    func entryAccessibilityLabel(_ entry: NutritionEntryModel) -> String {
        "\(entry.name), \(Int(entry.calories)) calories, " +
        "carbs \(Int(entry.carbs))g, protein \(Int(entry.protein))g, fats \(Int(entry.fats))g"
    }
}

// MARK: - Nutrition Entry Row

struct NutritionEntryRow: View {
    let entry: NutritionEntryModel

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
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

            HStack(spacing: DesignSystem.Spacing.md) {
                macroLabel(value: entry.carbs, label: "C", color: .nexusBlue)
                macroLabel(value: entry.protein, label: "P", color: .nexusRed)
                macroLabel(value: entry.fats, label: "F", color: .nexusPurple)

                Text("\(Int(entry.calories))")
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.nexusOrange)
                    .frame(width: 50, alignment: .trailing)
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, DesignSystem.Spacing.xxs)
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
            HStack(spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(product.name)
                            .font(.nexusBody)
                            .foregroundStyle(Color.nexusTextPrimary)
                            .lineLimit(1)

                        if showFavorite, product.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.nexusCaption2)
                                .foregroundStyle(Color.nexusOrange)
                                .accessibilityLabel("Favorite")
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
                .accessibilityHidden(true)

                Image(systemName: "plus.circle.fill")
                    .font(.nexusTitle3)
                    .foregroundStyle(Color.nexusGreen)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DesignSystem.Spacing.xxs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(productAccessibilityLabel)
        .accessibilityHint("Log to current meal")
    }

    private var productAccessibilityLabel: String {
        var parts = [product.name]
        if !product.brand.isEmpty { parts.append(product.brand) }
        parts.append("\(Int(product.calories)) calories per \(product.servingUnit)")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Quick Add Tile

struct QuickAddTile: View {
    let product: ProductModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
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
                            .font(.nexusCaption2)
                            .foregroundStyle(Color.nexusOrange)
                            .accessibilityHidden(true)
                    }
                }

                Spacer()

                Text("\(Int(product.calories)) kcal")
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusOrange)
                    .accessibilityHidden(true)
            }
            .padding(DesignSystem.Spacing.sm)
            .frame(width: 100, height: 80)
            .glassBackground(
                in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(product.name), \(Int(product.calories)) calories")
        .accessibilityHint("Quick log to current meal")
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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.nexusCaption)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
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
                    .accessibilityLabel(title)
                    .accessibilityValue("\(Int(value)) \(unit)")

                Text(unit)
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.sm - 2)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md - 2)
                    .fill(Color.nexusSurfaceSecondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md - 2)
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
}
