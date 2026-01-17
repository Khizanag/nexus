import SwiftUI
import SwiftData

struct ProductEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let product: ProductModel?

    @State private var name = ""
    @State private var brand = ""
    @State private var barcode = ""
    @State private var calories: Double = 0
    @State private var carbs: Double = 0
    @State private var protein: Double = 0
    @State private var fats: Double = 0
    @State private var servingSize: Double = 1
    @State private var servingUnit = "serving"
    @State private var isFavorite = false

    @State private var showDeleteConfirmation = false

    private var isEditing: Bool { product != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    init(product: ProductModel? = nil) {
        self.product = product
    }

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                macrosSection
                servingSection
                favoriteSection

                if isEditing {
                    deleteSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle(isEditing ? "Edit Product" : "New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear { loadProductData() }
            .confirmationDialog(
                "Delete Product",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteProduct()
                }
            } message: {
                Text("Are you sure you want to delete this product?")
            }
        }
    }
}

// MARK: - Form Sections

private extension ProductEditorView {
    var basicInfoSection: some View {
        Section {
            TextField("Product name", text: $name)
                .font(.nexusBody)

            TextField("Brand (optional)", text: $brand)
                .font(.nexusBody)

            TextField("Barcode (optional)", text: $barcode)
                .font(.nexusBody)
                .keyboardType(.numberPad)
        } header: {
            Text("Product Info")
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
            Text("Nutrition per Serving")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var servingSection: some View {
        Section {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Serving")
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
                            Button(unit) { servingUnit = unit }
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
            Text("Serving Size")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
        }
        .listRowBackground(Color.nexusSurface)
    }

    var favoriteSection: some View {
        Section {
            Toggle(isOn: $isFavorite) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.nexusOrange)
                    Text("Add to Favorites")
                        .font(.nexusBody)
                }
            }
            .tint(.nexusOrange)
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
                    Text("Delete Product")
                        .font(.nexusBody)
                    Spacer()
                }
            }
        }
        .listRowBackground(Color.nexusRed.opacity(0.15))
    }

    var servingUnits: [String] {
        ["serving", "g", "oz", "cup", "tbsp", "tsp", "piece", "slice", "ml", "fl oz"]
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { saveProduct() }
                .disabled(!isValid)
        }
    }
}

// MARK: - Actions

private extension ProductEditorView {
    func loadProductData() {
        guard let product else { return }
        name = product.name
        brand = product.brand
        barcode = product.barcode
        calories = product.calories
        carbs = product.carbs
        protein = product.protein
        fats = product.fats
        servingSize = product.defaultServingSize
        servingUnit = product.servingUnit
        isFavorite = product.isFavorite
    }

    func saveProduct() {
        if let product {
            product.name = name.trimmingCharacters(in: .whitespaces)
            product.brand = brand.trimmingCharacters(in: .whitespaces)
            product.barcode = barcode.trimmingCharacters(in: .whitespaces)
            product.calories = calories
            product.carbs = carbs
            product.protein = protein
            product.fats = fats
            product.defaultServingSize = servingSize
            product.servingUnit = servingUnit
            product.isFavorite = isFavorite
        } else {
            let newProduct = ProductModel(
                name: name.trimmingCharacters(in: .whitespaces),
                brand: brand.trimmingCharacters(in: .whitespaces),
                barcode: barcode.trimmingCharacters(in: .whitespaces),
                calories: calories,
                carbs: carbs,
                protein: protein,
                fats: fats,
                defaultServingSize: servingSize,
                servingUnit: servingUnit,
                isFavorite: isFavorite
            )
            modelContext.insert(newProduct)
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        dismiss()
    }

    func deleteProduct() {
        if let product {
            modelContext.delete(product)
        }
        dismiss()
    }
}

#Preview {
    ProductEditorView()
        .modelContainer(for: ProductModel.self, inMemory: true)
        .preferredColorScheme(.dark)
}
