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

    private var favoriteProducts: [ProductModel] {
        products.filter { $0.isFavorite }
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
            VStack(spacing: 20) {
                dateHeader
                summaryCard
                quickAccessSection
                mealSections
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
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

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.nexusHeadline)
                    .foregroundStyle(Calendar.current.isDateInToday(selectedDate) ? Color.nexusTextTertiary : Color.nexusTextSecondary)
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
        }
        .padding(.vertical, 8)
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
            VStack(alignment: .leading, spacing: 12) {
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
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
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
        VStack(spacing: 16) {
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
            Image(systemName: "plus")
                .font(.nexusTitle2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background {
                    Circle()
                        .fill(Color.nexusOrange)
                        .shadow(color: .nexusOrange.opacity(0.4), radius: 8, x: 0, y: 4)
                }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
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
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showGoals = true
            } label: {
                Image(systemName: "target")
                    .foregroundStyle(Color.nexusTextSecondary)
            }
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

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    NutritionHubView()
        .modelContainer(for: [NutritionEntryModel.self, ProductModel.self], inMemory: true)
        .preferredColorScheme(.dark)
}
