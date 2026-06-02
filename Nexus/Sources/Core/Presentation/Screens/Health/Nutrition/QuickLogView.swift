import SwiftUI
import SwiftData

struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProductModel.lastUsed, order: .reverse) private var allProducts: [ProductModel]

    let mealType: MealType
    let onProductSelect: (ProductModel) -> Void
    let onCustomEntry: () -> Void

    @State private var searchText = ""

    private var recentProducts: [ProductModel] {
        Array(allProducts.prefix(8))
    }

    private var favoriteProducts: [ProductModel] {
        allProducts.filter { $0.isFavorite }
    }

    private var searchResults: [ProductModel] {
        guard !searchText.isEmpty else { return [] }
        return allProducts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.brand.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                listContent
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle("Add to \(mealType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search products")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - List Content

private extension QuickLogView {
    @ViewBuilder
    var listContent: some View {
        if !searchText.isEmpty {
            searchSection
        } else {
            if !favoriteProducts.isEmpty {
                favoritesSection
            }
            if !recentProducts.isEmpty {
                recentSection
            }
            customEntrySection
        }
    }

    @ViewBuilder
    var searchSection: some View {
        if searchResults.isEmpty {
            Section {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)

                Button {
                    onCustomEntry()
                } label: {
                    Label("Add Custom Entry", systemImage: "plus.circle.fill")
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.nexusGreen)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.nexusSurface)
                .accessibilityLabel("Add custom entry")
            }
        } else {
            Section {
                ForEach(searchResults, id: \.id) { product in
                    ProductRow(product: product, showFavorite: true) {
                        selectProduct(product)
                    }
                    .listRowBackground(Color.nexusSurface)
                }
            } header: {
                Label("Results", systemImage: "magnifyingglass")
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusTextSecondary)
            }
        }
    }

    var favoritesSection: some View {
        Section {
            ForEach(favoriteProducts.prefix(4), id: \.id) { product in
                ProductRow(product: product, showFavorite: false) {
                    selectProduct(product)
                }
                .listRowBackground(Color.nexusSurface)
            }
        } header: {
            Label("Favorites", systemImage: "star.fill")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusOrange)
        }
    }

    var recentSection: some View {
        Section {
            ForEach(recentProducts, id: \.id) { product in
                ProductRow(product: product, showFavorite: true) {
                    selectProduct(product)
                }
                .listRowBackground(Color.nexusSurface)
            }
        } header: {
            Label("Recent", systemImage: "clock.fill")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusBlue)
        }
    }

    var customEntrySection: some View {
        Section {
            Button(action: onCustomEntry) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.nexusTitle2)
                        .foregroundStyle(Color.nexusGreen)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom Entry")
                            .font(.nexusHeadline)
                            .foregroundStyle(Color.nexusTextPrimary)

                        Text("Manually enter nutrition info")
                            .font(.nexusCaption)
                            .foregroundStyle(Color.nexusTextSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.nexusCaption)
                        .foregroundStyle(Color.nexusTextTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, DesignSystem.Spacing.xxs)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.nexusSurface)
            .accessibilityLabel("Add custom entry")
            .accessibilityHint("Manually enter nutrition information")
        } header: {
            Label("Custom", systemImage: "pencil")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusGreen)
        }
    }
}

// MARK: - Actions

private extension QuickLogView {
    func selectProduct(_ product: ProductModel) {
        onProductSelect(product)
        dismiss()
    }
}

#Preview {
    QuickLogView(
        mealType: .lunch,
        onProductSelect: { _ in },
        onCustomEntry: {}
    )
    .modelContainer(for: ProductModel.self, inMemory: true)
}
