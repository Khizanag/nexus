import SwiftUI
import SwiftData

struct ProductLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProductModel.lastUsed, order: .reverse) private var products: [ProductModel]

    @State private var searchText = ""
    @State private var selectedTab: ProductTab = .recent
    @State private var showAddProduct = false
    @State private var selectedProduct: ProductModel?
    @State private var favoriteTrigger = false

    private var filteredProducts: [ProductModel] {
        let baseProducts: [ProductModel]
        switch selectedTab {
        case .recent:
            baseProducts = products.sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        case .favorites:
            baseProducts = products.filter { $0.isFavorite }
        case .all:
            baseProducts = products.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        guard !searchText.isEmpty else { return baseProducts }
        return baseProducts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.brand.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                listContent
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle("Products")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search products")
            .safeAreaInset(edge: .top, spacing: 0) {
                tabPicker
            }
            .sensoryFeedback(.impact(weight: .light), trigger: favoriteTrigger)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAddProduct) {
                ProductEditorView()
            }
            .sheet(item: $selectedProduct) { product in
                ProductEditorView(product: product)
            }
        }
    }
}

// MARK: - Tab Type

enum ProductTab: String, CaseIterable {
    case recent = "Recent"
    case favorites = "Favorites"
    case all = "All"
}

// MARK: - Subviews

private extension ProductLibraryView {
    var tabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(ProductTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(Color.nexusBackground)
    }

    @ViewBuilder
    var listContent: some View {
        if filteredProducts.isEmpty {
            emptyState
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } else {
            ForEach(filteredProducts, id: \.id) { product in
                ProductLibraryRow(product: product) {
                    selectedProduct = product
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteProduct(product)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        toggleFavorite(product)
                    } label: {
                        Label(
                            product.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: product.isFavorite ? "star.slash" : "star.fill"
                        )
                    }
                    .tint(.nexusOrange)
                }
                .listRowBackground(Color.nexusSurface)
            }
        }
    }

    @ViewBuilder
    var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView(
                emptyStateTitle,
                systemImage: "bookmark.slash",
                description: Text(emptyStateMessage)
            )
        }
    }

    var emptyStateTitle: String {
        switch selectedTab {
        case .recent: "No Recent Products"
        case .favorites: "No Favorites"
        case .all: "No Products Yet"
        }
    }

    var emptyStateMessage: String {
        switch selectedTab {
        case .recent: "Products you've logged will appear here"
        case .favorites: "Star products to add them to favorites"
        case .all: "Save products when logging entries"
        }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showAddProduct = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add product")
        }
    }
}

// MARK: - Actions

private extension ProductLibraryView {
    func deleteProduct(_ product: ProductModel) {
        modelContext.delete(product)
    }

    func toggleFavorite(_ product: ProductModel) {
        product.isFavorite.toggle()
        favoriteTrigger.toggle()
    }
}

// MARK: - Product Library Row

private struct ProductLibraryRow: View {
    let product: ProductModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(product.name)
                            .font(.nexusBody)
                            .foregroundStyle(Color.nexusTextPrimary)

                        if product.isFavorite {
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

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("C: \(Int(product.carbs))g")
                            .foregroundStyle(Color.nexusBlue)
                        Text("P: \(Int(product.protein))g")
                            .foregroundStyle(Color.nexusRed)
                        Text("F: \(Int(product.fats))g")
                            .foregroundStyle(Color.nexusPurple)
                    }
                    .font(.nexusCaption2)
                    .accessibilityHidden(true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(product.calories)) kcal")
                        .font(.nexusSubheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.nexusOrange)

                    Text("per \(product.servingUnit)")
                        .font(.nexusCaption)
                        .foregroundStyle(Color.nexusTextTertiary)
                }
                .accessibilityHidden(true)
            }
            .padding(.vertical, DesignSystem.Spacing.xxs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint("Edit product")
    }

    private var rowAccessibilityLabel: String {
        var parts = [product.name]
        if !product.brand.isEmpty { parts.append(product.brand) }
        parts.append("\(Int(product.calories)) calories per \(product.servingUnit)")
        if product.isFavorite { parts.append("Favorite") }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    ProductLibraryView()
        .modelContainer(for: ProductModel.self, inMemory: true)
}
