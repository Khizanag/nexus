import SwiftUI
import SwiftData

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SubscriptionModel.nextDueDate) private var subscriptions: [SubscriptionModel]
    @AppStorage("currency") private var preferredCurrency = "GEL"

    @State private var showAddSheet = false
    @State private var selectedSubscription: SubscriptionModel?
    @State private var filterCategory: SubscriptionCategory?
    @State private var showActiveOnly = true
    @State private var exchangeRates: ExchangeRates?
    @State private var hapticTrigger = false

    // MARK: - Computed

    private var targetCurrency: Currency {
        Currency(rawValue: preferredCurrency) ?? .gel
    }

    private var hasMixedCurrencies: Bool {
        let currencies = Set(filteredSubscriptions.filter { $0.isActive && !$0.isPaused }.map { $0.currency })
        return currencies.count > 1
    }

    private var filteredSubscriptions: [SubscriptionModel] {
        subscriptions
            .filter { sub in
                let categoryMatch = filterCategory == nil || sub.category == filterCategory
                let activeMatch = !showActiveOnly || (sub.isActive && !sub.isPaused)
                return categoryMatch && activeMatch
            }
            .sorted { lhs, rhs in
                if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue }
                let lhsDueSoon = lhs.daysUntilDue >= 0 && lhs.daysUntilDue <= 7
                let rhsDueSoon = rhs.daysUntilDue >= 0 && rhs.daysUntilDue <= 7
                if lhsDueSoon != rhsDueSoon { return lhsDueSoon }
                let lhsActive = lhs.isActive && !lhs.isPaused
                let rhsActive = rhs.isActive && !rhs.isPaused
                if lhsActive != rhsActive { return lhsActive }
                return lhs.nextDueDate < rhs.nextDueDate
            }
    }

    private var overdueSubscriptions: [SubscriptionModel] {
        filteredSubscriptions.filter { $0.isOverdue }
    }

    private var upcomingSubscriptions: [SubscriptionModel] {
        filteredSubscriptions
            .filter { $0.isActive && !$0.isPaused && $0.daysUntilDue >= 0 && $0.daysUntilDue <= 7 }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private var monthlyTotal: Double {
        let active = filteredSubscriptions.filter { $0.isActive && !$0.isPaused }
        let service = DefaultCurrencyService()
        let rates = exchangeRates ?? service.getFallbackRates(base: targetCurrency)
        return active.reduce(0) { total, sub in
            let from = Currency(rawValue: sub.currency) ?? .gel
            return total + service.convert(amount: sub.monthlyEquivalent, from: from, to: targetCurrency, rates: rates)
        }
    }

    private var yearlyTotal: Double { monthlyTotal * 12 }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                summarySection
                filterSection
                if !overdueSubscriptions.isEmpty { overdueSection }
                if !upcomingSubscriptions.isEmpty { upcomingSection }
                allSubscriptionsSection
            }
            .listStyle(.insetGrouped)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Color.nexusBackground)
            .navigationTitle("Subscriptions")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: .constant(""), placement: .navigationBarDrawer)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    GlassIconButton(systemImage: "plus", accessibilityLabel: "Add subscription") {
                        showAddSheet = true
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddSubscriptionSheet()
            }
            .sheet(item: $selectedSubscription) { sub in
                SubscriptionDetailView(subscription: sub)
            }
            .task { await loadExchangeRates() }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var summarySection: some View {
        Section {
            summaryCard
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var filterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    FilterChip(
                        title: "Active",
                        isSelected: showActiveOnly,
                        action: { showActiveOnly.toggle() }
                    )
                    FilterChip(
                        title: "All",
                        isSelected: filterCategory == nil && !showActiveOnly,
                        action: {
                            filterCategory = nil
                            showActiveOnly = false
                        }
                    )
                    ForEach(SubscriptionCategory.allCases) { category in
                        FilterChip(
                            title: category.displayName,
                            icon: category.icon,
                            isSelected: filterCategory == category,
                            action: { filterCategory = filterCategory == category ? nil : category }
                        )
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.xxs)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: DesignSystem.Spacing.md, bottom: 0, trailing: DesignSystem.Spacing.md))
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var overdueSection: some View {
        Section {
            ForEach(overdueSubscriptions) { sub in
                subscriptionRow(sub)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            markPaid(sub)
                        } label: {
                            Label("Mark Paid", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.nexusGreen)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            togglePause(sub)
                        } label: {
                            Label(sub.isPaused ? "Resume" : "Pause", systemImage: sub.isPaused ? "play.fill" : "pause.fill")
                        }
                        .tint(.nexusOrange)
                    }
            }
            .onDelete { offsets in deleteSubscriptions(overdueSubscriptions, at: offsets) }
        } header: {
            Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.nexusRed)
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        Section("Due This Week") {
            ForEach(upcomingSubscriptions) { sub in
                subscriptionRow(sub)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            markPaid(sub)
                        } label: {
                            Label("Mark Paid", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.nexusGreen)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            togglePause(sub)
                        } label: {
                            Label(sub.isPaused ? "Resume" : "Pause", systemImage: sub.isPaused ? "play.fill" : "pause.fill")
                        }
                        .tint(.nexusOrange)
                    }
            }
        }
    }

    @ViewBuilder
    private var allSubscriptionsSection: some View {
        Section("All Subscriptions") {
            if filteredSubscriptions.isEmpty {
                ContentUnavailableView(
                    "No subscriptions yet",
                    systemImage: "creditcard.fill",
                    description: Text("Add your first subscription to start tracking recurring expenses")
                )
                .listRowBackground(Color.nexusSurface)
            } else {
                ForEach(filteredSubscriptions) { sub in
                    subscriptionRow(sub)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                markPaid(sub)
                            } label: {
                                Label("Mark Paid", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.nexusGreen)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                togglePause(sub)
                            } label: {
                                Label(sub.isPaused ? "Resume" : "Pause", systemImage: sub.isPaused ? "play.fill" : "pause.fill")
                            }
                            .tint(.nexusOrange)
                        }
                }
                .onDelete { offsets in deleteSubscriptions(filteredSubscriptions, at: offsets) }
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("Monthly")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                        if hasMixedCurrencies {
                            Text("(converted)")
                                .font(.nexusCaption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Text(targetCurrency.format(monthlyTotal))
                        .font(.nexusDisplayNumber(.title2))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
                    Text("Yearly")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    Text(targetCurrency.format(yearlyTotal))
                        .font(.nexusDisplayNumber(.title2))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                StatPill(icon: "checkmark.circle.fill", value: "\(subscriptions.filter { $0.isActive && !$0.isPaused }.count)", label: "Active", color: .nexusGreen)
                Spacer()
                StatPill(icon: "clock.fill", value: "\(upcomingSubscriptions.count)", label: "Due Soon", color: .nexusOrange)
                Spacer()
                StatPill(icon: "exclamationmark.triangle.fill", value: "\(overdueSubscriptions.count)", label: "Overdue", color: .nexusRed)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - Row Builder

    private func subscriptionRow(_ subscription: SubscriptionModel) -> some View {
        Button {
            selectedSubscription = subscription
        } label: {
            SubscriptionRow(subscription: subscription)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(for: subscription))
    }

    // MARK: - Actions

    private func markPaid(_ subscription: SubscriptionModel) {
        subscription.markAsPaid()
        try? modelContext.save()
        hapticTrigger.toggle()
    }

    private func togglePause(_ subscription: SubscriptionModel) {
        subscription.isPaused.toggle()
        try? modelContext.save()
        hapticTrigger.toggle()
    }

    private func deleteSubscriptions(_ list: [SubscriptionModel], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(list[index])
        }
        try? modelContext.save()
    }

    private func loadExchangeRates() async {
        let service = DefaultCurrencyService()
        if let cached = CurrencyCache.getCachedRates(base: targetCurrency, context: modelContext), !cached.isStale {
            exchangeRates = cached
            return
        }
        do {
            let rates = try await service.fetchRatesFromAPI(base: targetCurrency)
            exchangeRates = rates
            CurrencyCache.saveCachedRates(rates, context: modelContext)
        } catch {
            if let cached = CurrencyCache.getCachedRates(base: targetCurrency, context: modelContext) {
                exchangeRates = cached
            } else {
                exchangeRates = service.getFallbackRates(base: targetCurrency)
            }
        }
    }

    private func rowAccessibilityLabel(for sub: SubscriptionModel) -> String {
        var parts = [sub.name, sub.formattedAmount, sub.billingCycle.displayName]
        if sub.isOverdue { parts.append("Overdue") }
        else if sub.isPaused { parts.append("Paused") }
        else { parts.append(dueDateDescription(for: sub)) }
        return parts.joined(separator: ", ")
    }

    private func dueDateDescription(for sub: SubscriptionModel) -> String {
        let days = sub.daysUntilDue
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days < 0 { return "\(abs(days)) days overdue" }
        return "Due in \(days) days"
    }
}

// MARK: - Subscription Row

struct SubscriptionRow: View {
    let subscription: SubscriptionModel

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            subscriptionIcon
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                HStack {
                    Text(subscription.name)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if subscription.isInFreeTrial {
                        Text("TRIAL")
                            .font(.nexusCaption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, 2)
                            .background { Capsule().fill(Color.nexusGreen) }
                    }
                }

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(subscription.billingCycle.displayName)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)

                    if subscription.isPaused {
                        Text("Paused")
                            .font(.nexusCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    } else if subscription.isOverdue {
                        Text("Overdue")
                            .font(.nexusCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    } else {
                        Text(dueDateText)
                            .font(.nexusCaption)
                            .foregroundStyle(dueDateColor)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
                Text(subscription.formattedAmount)
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)

                Text(subscription.billingCycle.shortName)
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xxs)
    }

    private var subscriptionIcon: some View {
        ZStack {
            Circle()
                .fill(categoryColor.opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: subscription.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(categoryColor)
        }
    }

    private var categoryColor: Color { Color.named(subscription.color) }

    private var dueDateText: String {
        let days = subscription.daysUntilDue
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days < 0 { return "\(abs(days))d overdue" }
        return "Due in \(days)d"
    }

    private var dueDateColor: Color {
        let days = subscription.daysUntilDue
        if days < 0 { return .red }
        if days <= 3 { return .orange }
        return .secondary
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.nexusCaption)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.nexusSubheadline)
                    .fontWeight(.bold)
                Text(label)
                    .font(.nexusCaption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}
