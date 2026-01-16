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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !searchText.isEmpty {
                        searchResultsSection
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
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.nexusBackground)
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

// MARK: - Sections

private extension QuickLogView {
    var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Favorites", icon: "star.fill", color: .nexusOrange)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(favoriteProducts.prefix(4), id: \.id) { product in
                    QuickLogProductCard(product: product) {
                        selectProduct(product)
                    }
                }
            }
        }
    }

    var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Recent", icon: "clock.fill", color: .nexusBlue)

            VStack(spacing: 8) {
                ForEach(recentProducts, id: \.id) { product in
                    ProductRow(product: product, showFavorite: true) {
                        selectProduct(product)
                    }
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
        }
    }

    var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if searchResults.isEmpty {
                emptySearchState
            } else {
                sectionHeader(title: "Results", icon: "magnifyingglass", color: .nexusTextSecondary)

                VStack(spacing: 8) {
                    ForEach(searchResults, id: \.id) { product in
                        ProductRow(product: product, showFavorite: true) {
                            selectProduct(product)
                        }
                    }
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.nexusSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.nexusBorder, lineWidth: 1)
                        }
                }
            }
        }
    }

    var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.nexusTextTertiary)

            Text("No products found")
                .font(.nexusHeadline)
                .foregroundStyle(Color.nexusTextPrimary)

            Text("Try a different search or add a custom entry")
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)

            Button {
                onCustomEntry()
            } label: {
                Text("Add Custom Entry")
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background {
                        Capsule().fill(Color.nexusGreen)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    var customEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Custom", icon: "pencil", color: .nexusGreen)

            Button(action: onCustomEntry) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.nexusTitle2)
                        .foregroundStyle(Color.nexusGreen)

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
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.nexusSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.nexusGreen.opacity(0.3), lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)
        }
    }

    func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.nexusCaption)
                .foregroundStyle(color)
            Text(title)
                .font(.nexusHeadline)
                .foregroundStyle(Color.nexusTextPrimary)
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

// MARK: - Quick Log Product Card

private struct QuickLogProductCard: View {
    let product: ProductModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(product.name)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.nexusTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }

                Spacer()

                HStack {
                    Text("\(Int(product.calories)) kcal")
                        .font(.nexusCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.nexusOrange)

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .font(.nexusHeadline)
                        .foregroundStyle(Color.nexusGreen)
                }
            }
            .padding(12)
            .frame(height: 90)
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

#Preview {
    QuickLogView(
        mealType: .lunch,
        onProductSelect: { _ in },
        onCustomEntry: {}
    )
    .modelContainer(for: ProductModel.self, inMemory: true)
    .preferredColorScheme(.dark)
}
