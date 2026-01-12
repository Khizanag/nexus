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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    quickActionsSection
                        .padding(.bottom, 24)

                    SectionDivider()
                    featuresSection
                        .padding(.vertical, 20)

                    SectionDivider()
                    toolsSection
                        .padding(.vertical, 20)

                    SectionDivider()
                    recentTransactionsSection
                        .padding(.vertical, 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 80)
            }
            .background(Color.nexusBackground)
            .navigationTitle("Finance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddTransaction = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showTransactions) {
                TransactionsView()
            }
            .sheet(isPresented: $showBudgets) {
                BudgetView()
            }
            .sheet(isPresented: $showSubscriptions) {
                SubscriptionsView()
            }
            .sheet(isPresented: $showHouse) {
                HouseView()
            }
            .sheet(isPresented: $showStocks) {
                StocksView()
            }
            .sheet(isPresented: $showAddTransaction) {
                TransactionEditorView(transaction: nil)
            }
        }
    }
}

// MARK: - Quick Actions

private extension FinanceView {
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Add",
                    subtitle: "Transaction",
                    icon: "plus.circle.fill",
                    color: .nexusGreen
                ) {
                    showAddTransaction = true
                }

                QuickActionButton(
                    title: "View",
                    subtitle: "Transactions",
                    icon: "list.bullet.rectangle",
                    color: .nexusBlue
                ) {
                    showTransactions = true
                }

                QuickActionButton(
                    title: "Manage",
                    subtitle: "Budgets",
                    icon: "chart.pie.fill",
                    color: .nexusPurple
                ) {
                    showBudgets = true
                }
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Features Section

private extension FinanceView {
    var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Features")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                FeatureCard(
                    icon: "repeat.circle.fill",
                    title: "Subscriptions",
                    subtitle: "Track recurring payments",
                    color: .nexusOrange
                ) {
                    showSubscriptions = true
                }

                FeatureCard(
                    icon: "house.fill",
                    title: "House & Utilities",
                    subtitle: "Manage property expenses",
                    color: .nexusTeal
                ) {
                    showHouse = true
                }

                FeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Stocks & Investments",
                    subtitle: "Monitor your portfolio",
                    color: .nexusGreen
                ) {
                    showStocks = true
                }

                FeatureCard(
                    icon: "chart.pie.fill",
                    title: "Budgets",
                    subtitle: budgetSubtitle,
                    color: .nexusPurple
                ) {
                    showBudgets = true
                }
            }
        }
    }

    var budgetSubtitle: String {
        if budgets.isEmpty {
            return "Create spending limits"
        }
        return "\(budgets.count) active budget\(budgets.count == 1 ? "" : "s")"
    }
}

// MARK: - Tools Section

private extension FinanceView {
    var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tools")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            CurrencyCalculatorCard()
        }
    }
}

// MARK: - Recent Transactions Section

private extension FinanceView {
    var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.nexusHeadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("View All") {
                    showTransactions = true
                }
                .font(.nexusSubheadline)
                .foregroundStyle(Color.nexusPurple)
            }

            if transactions.isEmpty {
                emptyTransactionsState
            } else {
                VStack(spacing: 8) {
                    ForEach(transactions.prefix(5)) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }

    var emptyTransactionsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Transactions Yet")
                .font(.nexusHeadline)
            Text("Tap + to add your first transaction")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Supporting Views

private struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
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
            .padding(.vertical, 16)
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

private struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(color.opacity(0.15))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FinanceView()
        .preferredColorScheme(.dark)
}
