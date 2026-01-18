import SwiftUI

struct NutritionGoalsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("dailyCalorieGoal") private var calorieGoal = 2000
    @AppStorage("dailyCarbsGoal") private var carbsGoal = 250
    @AppStorage("dailyProteinGoal") private var proteinGoal = 150
    @AppStorage("dailyFatsGoal") private var fatsGoal = 65

    var body: some View {
        NavigationStack {
            Form {
                caloriesSection
                macrosSection
                presetsSection
                infoSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle("Daily Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sections

private extension NutritionGoalsView {
    var caloriesSection: some View {
        Section {
            GoalSlider(
                title: "Daily Calories",
                icon: "flame.fill",
                color: .nexusOrange,
                value: Binding(
                    get: { Double(calorieGoal) },
                    set: { calorieGoal = Int($0) }
                ),
                range: 1000...4000,
                step: 50,
                unit: "kcal"
            )
        } header: {
            Text("Calories")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var macrosSection: some View {
        Section {
            GoalSlider(
                title: "Carbohydrates",
                icon: "leaf.fill",
                color: .nexusBlue,
                value: Binding(
                    get: { Double(carbsGoal) },
                    set: { carbsGoal = Int($0) }
                ),
                range: 50...500,
                step: 10,
                unit: "g"
            )

            GoalSlider(
                title: "Protein",
                icon: "fish.fill",
                color: .nexusRed,
                value: Binding(
                    get: { Double(proteinGoal) },
                    set: { proteinGoal = Int($0) }
                ),
                range: 30...300,
                step: 5,
                unit: "g"
            )

            GoalSlider(
                title: "Fats",
                icon: "drop.fill",
                color: .nexusPurple,
                value: Binding(
                    get: { Double(fatsGoal) },
                    set: { fatsGoal = Int($0) }
                ),
                range: 20...200,
                step: 5,
                unit: "g"
            )
        } header: {
            Text("Macronutrients")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var presetsSection: some View {
        Section {
            presetButton(
                title: "Weight Loss",
                subtitle: "1,500 kcal • Low carb, high protein",
                calories: 1500, carbs: 150, protein: 180, fats: 55
            )

            presetButton(
                title: "Maintenance",
                subtitle: "2,000 kcal • Balanced macros",
                calories: 2000, carbs: 250, protein: 150, fats: 65
            )

            presetButton(
                title: "Muscle Gain",
                subtitle: "2,500 kcal • High protein, moderate carbs",
                calories: 2500, carbs: 300, protein: 200, fats: 75
            )

            presetButton(
                title: "Athlete",
                subtitle: "3,000 kcal • High carb, high protein",
                calories: 3000, carbs: 400, protein: 200, fats: 80
            )
        } header: {
            Text("Quick Presets")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("About Daily Goals")
                    .font(.nexusHeadline)
                    .foregroundStyle(Color.nexusTextPrimary)

                Text("These goals help you track your daily nutrition intake. Adjust them based on your personal health objectives, activity level, and dietary needs.")
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextSecondary)

                Text("Consult a healthcare professional for personalized nutrition advice.")
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextTertiary)
                    .italic()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.nexusSurface)
    }
}

// MARK: - Helper Views

private extension NutritionGoalsView {
    func presetButton(title: String, subtitle: String, calories: Int, carbs: Int, protein: Int, fats: Int) -> some View {
        Button {
            applyPreset(calories: calories, carbs: carbs, protein: protein, fats: fats)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.nexusBody)
                    .foregroundStyle(Color.nexusTextPrimary)

                Text(subtitle)
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    func applyPreset(calories: Int, carbs: Int, protein: Int, fats: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            calorieGoal = calories
            carbsGoal = carbs
            proteinGoal = protein
            fatsGoal = fats
        }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Goal Slider

private struct GoalSlider: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.nexusCaption)
                    .foregroundStyle(color)

                Text(title)
                    .font(.nexusSubheadline)
                    .foregroundStyle(Color.nexusTextPrimary)

                Spacer()

                Text("\(Int(value)) \(unit)")
                    .font(.nexusHeadline)
                    .foregroundStyle(color)
            }

            Slider(value: $value, in: range, step: step)
                .tint(color)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NutritionGoalsView()
        .preferredColorScheme(.dark)
}
