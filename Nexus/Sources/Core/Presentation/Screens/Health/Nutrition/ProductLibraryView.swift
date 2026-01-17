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
            VStack(spacing: 0) {
                tabPicker
                productList
            }
            .background(Color.nexusBackground)
            .navigationTitle("Products")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search products")
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

private enum ProductTab: String, CaseIterable {
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
        .padding()
    }

    var productList: some View {
        List {
            if filteredProducts.isEmpty {
                emptyState
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
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.nexusTextTertiary)

            Text(emptyStateTitle)
                .font(.nexusHeadline)
                .foregroundStyle(Color.nexusTextPrimary)

            Text(emptyStateMessage)
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }

    var emptyStateTitle: String {
        if !searchText.isEmpty { return "No Results" }
        switch selectedTab {
        case .recent: return "No Recent Products"
        case .favorites: return "No Favorites"
        case .all: return "No Products Yet"
        }
    }

    var emptyStateMessage: String {
        if !searchText.isEmpty { return "Try a different search term" }
        switch selectedTab {
        case .recent: return "Products you've logged will appear here"
        case .favorites: return "Star products to add them to favorites"
        case .all: return "Save products when logging entries"
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
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Product Library Row

private struct ProductLibraryRow: View {
    let product: ProductModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.name)
                            .font(.nexusBody)
                            .foregroundStyle(Color.nexusTextPrimary)

                        if product.isFavorite {
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

                    HStack(spacing: 8) {
                        Text("C: \(Int(product.carbs))g")
                            .foregroundStyle(Color.nexusBlue)
                        Text("P: \(Int(product.protein))g")
                            .foregroundStyle(Color.nexusRed)
                        Text("F: \(Int(product.fats))g")
                            .foregroundStyle(Color.nexusPurple)
                    }
                    .font(.system(size: 11))
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
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.nexusSurface)
    }
}

#Preview {
    ProductLibraryView()
        .modelContainer(for: ProductModel.self, inMemory: true)
        .preferredColorScheme(.dark)
}
