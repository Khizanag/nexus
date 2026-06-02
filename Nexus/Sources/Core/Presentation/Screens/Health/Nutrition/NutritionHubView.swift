import SwiftUI
import SwiftData

struct NutritionHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [NutritionEntryModel]
    @Query(sort: \ProductModel.lastUsed, order: .reverse) private var products: [ProductModel]

    @AppStorage("dailyCalorieGoal") private var calorieGoal = 2000
    @AppStorage("dailyCarbsGoal") private var carbsGoal = 250
    @AppStorage("dailyProteinGoal") private var proteinGoal = 150
    @AppStorage("dailyFatsGoal") private var fatsGoal = 65

    @State private var selectedDate = Date()
    @State private var showQuickLog = false
    @State private var showAddEntry = false
    @State private var selectedMealType: MealType = .snack
    @State private var selectedEntry: NutritionEntryModel?
    @State private var showGoals = false
    @State private var showHistory = false
    @State private var showProductLibrary = false
    @State private var logTrigger = false

    private var todayEntries: [NutritionEntryModel] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var entriesByMeal: [MealType: [NutritionEntryModel]] {
        Dictionary(grouping: todayEntries) { $0.mealType }
    }

    private var totals: (calories: Double, carbs: Double, protein: Double, fats: Double) {
        let cals = todayEntries.reduce(0) { $0 + $1.calories }
        let carbs = todayEntries.reduce(0) { $0 + $1.carbs }
        let protein = todayEntries.reduce(0) { $0 + $1.protein }
        let fats = todayEntries.reduce(0) { $0 + $1.fats }
        return (cals, carbs, protein, fats)
    }

    private var recentProducts: [ProductModel] {
        Array(products.prefix(6))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                scrollContent
                floatingActionButton
            }
            .background(Color.nexusBackground)
            .navigationTitle("Nutrition")
            .toolbar { toolbarContent }
            .sensoryFeedback(.impact(weight: .medium), trigger: logTrigger)
            .sheet(isPresented: $showQuickLog) {
                QuickLogView(
                    mealType: selectedMealType,
                    onProductSelect: { product in
                        quickLogProduct(product)
                    },
                    onCustomEntry: {
                        showQuickLog = false
                        showAddEntry = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAddEntry) {
                NutritionEntryEditorView(
                    mealType: selectedMealType,
                    date: selectedDate
                )
            }
            .sheet(item: $selectedEntry) { entry in
                NutritionEntryEditorView(
                    entry: entry,
                    mealType: entry.mealType,
                    date: entry.date
                )
            }
            .sheet(isPresented: $showGoals) {
                NutritionGoalsView()
            }
            .sheet(isPresented: $showHistory) {
                NutritionHistoryView()
            }
            .sheet(isPresented: $showProductLibrary) {
                ProductLibraryView()
            }
        }
    }
}

// MARK: - Subviews

private extension NutritionHubView {
    var scrollContent: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                dateHeader
                summaryCard
                quickAccessSection
                mealSections
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, 100)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    var dateHeader: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.nexusHeadline)
                    .foregroundStyle(Color.nexusTextSecondary)
            }
            .accessibilityLabel("Previous day")

            Spacer()

            VStack(spacing: 2) {
                if Calendar.current.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.nexusHeadline)
                        .foregroundStyle(Color.nexusTextPrimary)
                } else if Calendar.current.isDateInYesterday(selectedDate) {
                    Text("Yesterday")
                        .font(.nexusHeadline)
                        .foregroundStyle(Color.nexusTextPrimary)
                } else {
                    Text(selectedDate, format: .dateTime.weekday(.wide))
                        .font(.nexusHeadline)
                        .foregroundStyle(Color.nexusTextPrimary)
                }

                Text(selectedDate, format: .dateTime.month().day())
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextSecondary)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.nexusHeadline)
                    .foregroundStyle(Calendar.current.isDateInToday(selectedDate) ? Color.nexusTextTertiary : Color.nexusTextSecondary)
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
            .accessibilityLabel("Next day")
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    var summaryCard: some View {
        NutritionSummaryCard(
            calories: totals.calories,
            calorieGoal: Double(calorieGoal),
            carbs: totals.carbs,
            carbsGoal: Double(carbsGoal),
            protein: totals.protein,
            proteinGoal: Double(proteinGoal),
            fats: totals.fats,
            fatsGoal: Double(fatsGoal)
        )
    }

    @ViewBuilder
    var quickAccessSection: some View {
        if !recentProducts.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("Quick Add")
                        .font(.nexusHeadline)
                        .foregroundStyle(Color.nexusTextPrimary)

                    Spacer()

                    Button {
                        showProductLibrary = true
                    } label: {
                        Text("See All")
                            .font(.nexusCaption)
                            .foregroundStyle(Color.nexusBlue)
                    }
                    .accessibilityLabel("See all products")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(recentProducts, id: \.id) { product in
                            QuickAddTile(product: product) {
                                quickLogProduct(product)
                            }
                        }
                    }
                }
            }
        }
    }

    var mealSections: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(MealType.allCases, id: \.self) { mealType in
                MealSectionCard(
                    mealType: mealType,
                    entries: entriesByMeal[mealType] ?? [],
                    onAddTap: {
                        selectedMealType = mealType
                        showQuickLog = true
                    },
                    onEntryTap: { entry in
                        selectedEntry = entry
                    }
                )
            }
        }
    }

    var floatingActionButton: some View {
        Button {
            selectedMealType = suggestedMealType
            showQuickLog = true
        } label: {
            Label("Log food", systemImage: "plus")
                .font(.nexusTitle2)
                .fontWeight(.semibold)
                .labelStyle(.iconOnly)
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.glassProminent)
        .padding(.trailing, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.lg)
        .accessibilityLabel("Log food")
        .accessibilityHint("Opens quick food logging")
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showHistory = true
            } label: {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color.nexusTextSecondary)
            }
            .accessibilityLabel("View history")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showGoals = true
            } label: {
                Image(systemName: "target")
                    .foregroundStyle(Color.nexusTextSecondary)
            }
            .accessibilityLabel("Set daily goals")
        }
    }
}

// MARK: - Actions

private extension NutritionHubView {
    var suggestedMealType: MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }

    func quickLogProduct(_ product: ProductModel) {
        let entry = NutritionEntryModel(
            name: product.name,
            calories: product.calories,
            carbs: product.carbs,
            protein: product.protein,
            fats: product.fats,
            servingSize: product.defaultServingSize,
            servingUnit: product.servingUnit,
            mealType: selectedMealType,
            date: selectedDate,
            product: product
        )

        modelContext.insert(entry)

        product.usageCount += 1
        product.lastUsed = Date()

        showQuickLog = false
        logTrigger.toggle()
    }
}

#Preview {
    NutritionHubView()
        .modelContainer(for: [NutritionEntryModel.self, ProductModel.self], inMemory: true)
}
