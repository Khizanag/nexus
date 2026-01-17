import SwiftUI
import SwiftData

struct NutritionEntryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: NutritionEntryModel?
    let initialMealType: MealType
    let initialDate: Date

    @State private var name = ""
    @State private var calories: Double = 0
    @State private var carbs: Double = 0
    @State private var protein: Double = 0
    @State private var fats: Double = 0
    @State private var servingSize: Double = 1
    @State private var servingUnit = "serving"
    @State private var mealType: MealType = .snack
    @State private var date: Date = .now
    @State private var notes = ""
    @State private var saveAsProduct = false
    @State private var productBrand = ""

    @State private var showDeleteConfirmation = false

    private var isEditing: Bool { entry != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    init(
        entry: NutritionEntryModel? = nil,
        mealType: MealType = .snack,
        date: Date = .now
    ) {
        self.entry = entry
        self.initialMealType = mealType
        self.initialDate = date
    }

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                macrosSection
                servingSection
                mealSection
                notesSection

                if !isEditing {
                    saveAsProductSection
                }

                if isEditing {
                    deleteSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle(isEditing ? "Edit Entry" : "Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear { loadEntryData() }
            .confirmationDialog(
                "Delete Entry",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
            } message: {
                Text("Are you sure you want to delete this entry?")
            }
        }
    }
}

// MARK: - Form Sections

private extension NutritionEntryEditorView {
    var basicInfoSection: some View {
        Section {
            TextField("Food name", text: $name)
                .font(.nexusBody)
        } header: {
            Text("Name")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var macrosSection: some View {
        Section {
            VStack(spacing: 16) {
                MacroInputField(
                    title: "Calories",
                    icon: "flame.fill",
                    color: .nexusOrange,
                    value: $calories,
                    unit: "kcal"
                )

                HStack(spacing: 12) {
                    MacroInputField(
                        title: "Carbs",
                        icon: "leaf.fill",
                        color: .nexusBlue,
                        value: $carbs
                    )
                    MacroInputField(
                        title: "Protein",
                        icon: "fish.fill",
                        color: .nexusRed,
                        value: $protein
                    )
                    MacroInputField(
                        title: "Fats",
                        icon: "drop.fill",
                        color: .nexusPurple,
                        value: $fats
                    )
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Nutrition Info")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var servingSection: some View {
        Section {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Serving Size")
                        .font(.nexusCaption)
                        .foregroundStyle(Color.nexusTextSecondary)

                    TextField("1", value: $servingSize, format: .number)
                        .font(.nexusHeadline)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.nexusSurfaceSecondary)
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Unit")
                        .font(.nexusCaption)
                        .foregroundStyle(Color.nexusTextSecondary)

                    Menu {
                        ForEach(servingUnits, id: \.self) { unit in
                            Button(unit) {
                                servingUnit = unit
                            }
                        }
                    } label: {
                        HStack {
                            Text(servingUnit)
                                .font(.nexusHeadline)
                                .foregroundStyle(Color.nexusTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.nexusCaption)
                                .foregroundStyle(Color.nexusTextTertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.nexusSurfaceSecondary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Serving")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var mealSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(MealType.allCases, id: \.self) { type in
                        mealTypeButton(type)
                    }
                }

                DatePicker("Date", selection: $date, displayedComponents: [.date])
                    .font(.nexusBody)
                    .foregroundStyle(Color.nexusTextPrimary)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Meal")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var notesSection: some View {
        Section {
            TextField("Add notes...", text: $notes, axis: .vertical)
                .font(.nexusBody)
                .lineLimit(3...6)
        } header: {
            Text("Notes")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var saveAsProductSection: some View {
        Section {
            Toggle(isOn: $saveAsProduct) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(Color.nexusGreen)
                    Text("Save to Product Library")
                        .font(.nexusBody)
                }
            }
            .tint(.nexusGreen)

            if saveAsProduct {
                TextField("Brand (optional)", text: $productBrand)
                    .font(.nexusBody)
            }
        } header: {
            Text("Save for Later")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Entry")
                        .font(.nexusBody)
                    Spacer()
                }
            }
        }
        .listRowBackground(Color.nexusRed.opacity(0.15))
    }
}

// MARK: - Helper Views

private extension NutritionEntryEditorView {
    func mealTypeButton(_ type: MealType) -> some View {
        let isSelected = mealType == type
        let color = mealTypeColor(for: type)

        return Button {
            mealType = type
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.nexusHeadline)
                Text(type.displayName)
                    .font(.system(size: 10))
            }
            .foregroundStyle(isSelected ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color : color.opacity(0.15))
            }
        }
        .buttonStyle(.plain)
    }

    func mealTypeColor(for type: MealType) -> Color {
        switch type.color {
        case "orange": .nexusOrange
        case "blue": .nexusBlue
        case "purple": .nexusPurple
        case "green": .nexusGreen
        default: .nexusTextSecondary
        }
    }

    var servingUnits: [String] {
        ["serving", "g", "oz", "cup", "tbsp", "tsp", "piece", "slice", "ml", "fl oz"]
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveEntry()
            }
            .disabled(!isValid)
        }
    }
}

// MARK: - Actions

private extension NutritionEntryEditorView {
    func loadEntryData() {
        if let entry {
            name = entry.name
            calories = entry.calories
            carbs = entry.carbs
            protein = entry.protein
            fats = entry.fats
            servingSize = entry.servingSize
            servingUnit = entry.servingUnit
            mealType = entry.mealType
            date = entry.date
            notes = entry.notes
        } else {
            mealType = initialMealType
            date = initialDate
        }
    }

    func saveEntry() {
        if let entry {
            entry.name = name.trimmingCharacters(in: .whitespaces)
            entry.calories = calories
            entry.carbs = carbs
            entry.protein = protein
            entry.fats = fats
            entry.servingSize = servingSize
            entry.servingUnit = servingUnit
            entry.mealType = mealType
            entry.date = date
            entry.notes = notes
        } else {
            let newEntry = NutritionEntryModel(
                name: name.trimmingCharacters(in: .whitespaces),
                calories: calories,
                carbs: carbs,
                protein: protein,
                fats: fats,
                servingSize: servingSize,
                servingUnit: servingUnit,
                mealType: mealType,
                date: date,
                notes: notes
            )
            modelContext.insert(newEntry)

            if saveAsProduct {
                let product = ProductModel(
                    name: name.trimmingCharacters(in: .whitespaces),
                    brand: productBrand.trimmingCharacters(in: .whitespaces),
                    calories: calories,
                    carbs: carbs,
                    protein: protein,
                    fats: fats,
                    defaultServingSize: servingSize,
                    servingUnit: servingUnit,
                    usageCount: 1,
                    lastUsed: Date()
                )
                modelContext.insert(product)
                newEntry.product = product
            }
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        dismiss()
    }

    func deleteEntry() {
        if let entry {
            modelContext.delete(entry)
        }
        dismiss()
    }
}

#Preview {
    NutritionEntryEditorView(mealType: .lunch, date: .now)
        .modelContainer(for: [NutritionEntryModel.self, ProductModel.self], inMemory: true)
        .preferredColorScheme(.dark)
}
