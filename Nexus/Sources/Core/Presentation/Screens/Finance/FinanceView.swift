import SwiftUI
import SwiftData

struct FinanceView: View {
    @Query(filter: #Predicate<BudgetModel> { $0.isActive }) private var budgets: [BudgetModel]
    @Query(sort: \TransactionModel.date, order: .reverse) private var transactions: [TransactionModel]

    @State private var showTransactions = false
    @State private var showBudgets = false
    @State private var showSubscriptions = false
    @State private var showHouse = false
    @State private var showStocks = false
    @State private var showAddTransaction = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            scrollContent
                .background(Color.nexusBackground)
                .navigationTitle("Finance")
                .toolbar { toolbarContent }
                .modifier(SheetModifier(
                    showTransactions: $showTransactions,
                    showBudgets: $showBudgets,
                    showSubscriptions: $showSubscriptions,
                    showHouse: $showHouse,
                    showStocks: $showStocks,
                    showAddTransaction: $showAddTransaction
                ))
        }
    }
}

// MARK: - Toolbar

private extension FinanceView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAddTransaction = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add transaction")
        }
    }
}

// MARK: - Main Content

private extension FinanceView {
    var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                quickActionsSection
                    .padding(.bottom, DesignSystem.Spacing.lg)

                SectionDivider()
                featuresSection
                    .padding(.vertical, DesignSystem.Spacing.md)

                SectionDivider()
                toolsSection
                    .padding(.vertical, DesignSystem.Spacing.md)

                SectionDivider()
                recentTransactionsSection
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, 80)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

// MARK: - Quick Actions

private extension FinanceView {
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Quick Actions")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)
                .padding(.top, DesignSystem.Spacing.md)

            GlassEffectContainer(spacing: DesignSystem.Spacing.sm) {
                quickActionButton(
                    title: "Add",
                    subtitle: "Transaction",
                    icon: "plus.circle.fill",
                    color: .nexusGreen,
                    action: { showAddTransaction = true }
                )
                quickActionButton(
                    title: "View",
                    subtitle: "Transactions",
                    icon: "list.bullet.rectangle",
                    color: .nexusBlue,
                    action: { showTransactions = true }
                )
                quickActionButton(
                    title: "Manage",
                    subtitle: "Budgets",
                    icon: "chart.pie.fill",
                    color: .nexusPurple,
                    action: { showBudgets = true }
                )
            }
        }
    }

    func quickActionButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Size.Icon.md, weight: .semibold))
                    .foregroundStyle(color)
                VStack(spacing: 2) {
                    Text(title)
                        .font(.nexusCaption)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.nexusCaption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("\(title) \(subtitle)")
    }
}

// MARK: - Features

private extension FinanceView {
    var featuresSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Features")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            VStack(spacing: DesignSystem.Spacing.xs) {
                featureCard(
                    icon: "repeat.circle.fill",
                    title: "Subscriptions",
                    subtitle: "Track recurring payments",
                    color: .nexusOrange,
                    action: { showSubscriptions = true }
                )
                featureCard(
                    icon: "house.fill",
                    title: "House & Utilities",
                    subtitle: "Manage property expenses",
                    color: .nexusTeal,
                    action: { showHouse = true }
                )
                featureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Stocks & Investments",
                    subtitle: "Monitor your portfolio",
                    color: .nexusGreen,
                    action: { showStocks = true }
                )
                featureCard(
                    icon: "chart.pie.fill",
                    title: "Budgets",
                    subtitle: budgetSubtitle,
                    color: .nexusPurple,
                    action: { showBudgets = true }
                )
            }
        }
    }

    func featureCard(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Size.Icon.md))
                    .foregroundStyle(color)
                    .frame(width: DesignSystem.Size.Button.compact, height: DesignSystem.Size.Button.compact)
                    .background(color.opacity(0.15), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: DesignSystem.Size.Icon.sm, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(DesignSystem.Spacing.sm)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }

    var budgetSubtitle: String {
        budgets.isEmpty
            ? "Create spending limits"
            : "\(budgets.count) active budget\(budgets.count == 1 ? "" : "s")"
    }
}

// MARK: - Tools

private extension FinanceView {
    var toolsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Tools")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            CurrencyCalculatorCard()
        }
    }
}

// MARK: - Recent Transactions

private extension FinanceView {
    var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            recentTransactionsHeader

            if transactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions Yet",
                    systemImage: "creditcard",
                    description: Text("Tap + to add your first transaction")
                )
            } else {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(transactions.prefix(5)) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }

    var recentTransactionsHeader: some View {
        HStack {
            Text("Recent Transactions")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button("View All") { showTransactions = true }
                .font(.nexusSubheadline)
                .foregroundStyle(Color.nexusPurple)
                .accessibilityLabel("View all transactions")
        }
    }
}

// MARK: - Sheet Modifier

private struct SheetModifier: ViewModifier {
    @Binding var showTransactions: Bool
    @Binding var showBudgets: Bool
    @Binding var showSubscriptions: Bool
    @Binding var showHouse: Bool
    @Binding var showStocks: Bool
    @Binding var showAddTransaction: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showTransactions) { TransactionsView() }
            .sheet(isPresented: $showBudgets) { BudgetView() }
            .sheet(isPresented: $showSubscriptions) { SubscriptionsView() }
            .sheet(isPresented: $showHouse) { HouseView() }
            .sheet(isPresented: $showStocks) { StocksView() }
            .sheet(isPresented: $showAddTransaction) { TransactionEditorView(transaction: nil) }
    }
}

// MARK: - Preview

#Preview {
    FinanceView()
}
