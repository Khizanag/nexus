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

    private var targetCurrency: Currency {
        Currency(rawValue: preferredCurrency) ?? .gel
    }

    private var hasMixedCurrencies: Bool {
        let currencies = Set(filteredSubscriptions.filter { $0.isActive && !$0.isPaused }.map { $0.currency })
        return currencies.count > 1
    }

    private var filteredSubscriptions: [SubscriptionModel] {
        subscriptions
            .filter { subscription in
                let categoryMatch = filterCategory == nil || subscription.category == filterCategory
                let activeMatch = !showActiveOnly || (subscription.isActive && !subscription.isPaused)
                return categoryMatch && activeMatch
            }
            .sorted { lhs, rhs in
                // 1. Overdue first
                if lhs.isOverdue != rhs.isOverdue {
                    return lhs.isOverdue
                }
                // 2. Due soon (within 7 days) before others
                let lhsDueSoon = lhs.daysUntilDue >= 0 && lhs.daysUntilDue <= 7
                let rhsDueSoon = rhs.daysUntilDue >= 0 && rhs.daysUntilDue <= 7
                if lhsDueSoon != rhsDueSoon {
                    return lhsDueSoon
                }
                // 3. Active before paused/inactive
                let lhsActive = lhs.isActive && !lhs.isPaused
                let rhsActive = rhs.isActive && !rhs.isPaused
                if lhsActive != rhsActive {
                    return lhsActive
                }
                // 4. By next due date
                return lhs.nextDueDate < rhs.nextDueDate
            }
    }

    private var monthlyTotal: Double {
        let activeSubscriptions = filteredSubscriptions.filter { $0.isActive && !$0.isPaused }

        guard let rates = exchangeRates else {
            // Fallback: use hardcoded rates if no exchange rates loaded
            let service = DefaultCurrencyService()
            let fallbackRates = service.getFallbackRates(base: targetCurrency)
            return activeSubscriptions.reduce(0) { total, sub in
                let fromCurrency = Currency(rawValue: sub.currency) ?? .gel
                return total + service.convert(
                    amount: sub.monthlyEquivalent,
                    from: fromCurrency,
                    to: targetCurrency,
                    rates: fallbackRates
                )
            }
        }

        let service = DefaultCurrencyService()
        return activeSubscriptions.reduce(0) { total, sub in
            let fromCurrency = Currency(rawValue: sub.currency) ?? .gel
            return total + service.convert(
                amount: sub.monthlyEquivalent,
                from: fromCurrency,
                to: targetCurrency,
                rates: rates
            )
        }
    }

    private var yearlyTotal: Double {
        monthlyTotal * 12
    }

    private var upcomingSubscriptions: [SubscriptionModel] {
        filteredSubscriptions
            .filter { $0.isActive && !$0.isPaused && $0.daysUntilDue <= 7 && $0.daysUntilDue >= 0 }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private var overdueSubscriptions: [SubscriptionModel] {
        filteredSubscriptions.filter { $0.isOverdue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCard
                    filterSection

                    if !overdueSubscriptions.isEmpty {
                        overdueSection
                    }

                    if !upcomingSubscriptions.isEmpty {
                        upcomingSection
                    }

                    allSubscriptionsSection
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle("Subscriptions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddSubscriptionSheet()
            }
            .sheet(item: $selectedSubscription) { subscription in
                SubscriptionDetailView(subscription: subscription)
            }
            .task {
                await loadExchangeRates()
            }
        }
    }

    private func loadExchangeRates() async {
        let service = DefaultCurrencyService()

        // Try cached rates first
        if let cached = CurrencyCache.getCachedRates(base: targetCurrency, context: modelContext),
           !cached.isStale {
            exchangeRates = cached
            return
        }

        // Try fetching from API
        do {
            let rates = try await service.fetchRatesFromAPI(base: targetCurrency)
            exchangeRates = rates
            CurrencyCache.saveCachedRates(rates, context: modelContext)
        } catch {
            // Use stale cached rates or fallback
            if let cached = CurrencyCache.getCachedRates(base: targetCurrency, context: modelContext) {
                exchangeRates = cached
            } else {
                exchangeRates = service.getFallbackRates(base: targetCurrency)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Monthly")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                        if hasMixedCurrencies {
                            Text("(converted)")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Text(formatAmount(monthlyTotal))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Yearly")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    Text(formatAmount(yearlyTotal))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Divider().background(Color.nexusBorder)

            HStack {
                StatPill(
                    icon: "checkmark.circle.fill",
                    value: "\(subscriptions.filter { $0.isActive && !$0.isPaused }.count)",
                    label: "Active",
                    color: .nexusGreen
                )

                Spacer()

                StatPill(
                    icon: "clock.fill",
                    value: "\(upcomingSubscriptions.count)",
                    label: "Due Soon",
                    color: .nexusOrange
                )

                Spacer()

                StatPill(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(overdueSubscriptions.count)",
                    label: "Overdue",
                    color: .nexusRed
                )
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
                        action: {
                            filterCategory = filterCategory == category ? nil : category
                        }
                    )
                }
            }
        }
    }

    // MARK: - Overdue Section

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.nexusRed)
                Text("Overdue")
                    .font(.nexusHeadline)
            }

            VStack(spacing: 0) {
                ForEach(overdueSubscriptions) { subscription in
                    SubscriptionRow(subscription: subscription) {
                        selectedSubscription = subscription
                    }

                    if subscription.id != overdueSubscriptions.last?.id {
                        Divider().background(Color.nexusBorder).padding(.leading, 60)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.nexusRed.opacity(0.3), lineWidth: 1)
                    }
            }
        }
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(Color.nexusOrange)
                Text("Due This Week")
                    .font(.nexusHeadline)
            }

            VStack(spacing: 0) {
                ForEach(upcomingSubscriptions) { subscription in
                    SubscriptionRow(subscription: subscription) {
                        selectedSubscription = subscription
                    }

                    if subscription.id != upcomingSubscriptions.last?.id {
                        Divider().background(Color.nexusBorder).padding(.leading, 60)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
            }
        }
    }

    // MARK: - All Subscriptions

    private var allSubscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Subscriptions")
                .font(.nexusHeadline)

            if filteredSubscriptions.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredSubscriptions) { subscription in
                        SubscriptionRow(subscription: subscription) {
                            selectedSubscription = subscription
                        }

                        if subscription.id != filteredSubscriptions.last?.id {
                            Divider().background(Color.nexusBorder).padding(.leading, 60)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.nexusSurface)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No subscriptions yet")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            Text("Add your first subscription to start tracking your recurring expenses")
                .font(.nexusCaption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                showAddSheet = true
            } label: {
                Label("Add Subscription", systemImage: "plus")
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background {
                        Capsule().fill(Color.nexusPurple)
                    }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        let currency = Currency(rawValue: preferredCurrency) ?? .gel
        return currency.format(amount)
    }
}

// MARK: - Subscription Row

struct SubscriptionRow: View {
    let subscription: SubscriptionModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                subscriptionIcon

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(subscription.name)
                            .font(.nexusSubheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        if subscription.isInFreeTrial {
                            Text("TRIAL")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule().fill(Color.nexusGreen)
                                }
                        }
                    }

                    HStack(spacing: 6) {
                        Text(subscription.billingCycle.displayName)
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)

                        if subscription.isPaused {
                            Text("Paused")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.orange)
                        } else if subscription.isOverdue {
                            Text("Overdue")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.red)
                        } else {
                            Text(dueDateText)
                                .font(.nexusCaption)
                                .foregroundStyle(dueDateColor)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(subscription.formattedAmount)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(subscription.billingCycle.shortName)
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private var categoryColor: Color {
        Color.named(subscription.color)
    }

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

// MARK: - Supporting Views

private struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(title)
                    .font(.nexusCaption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? Color.nexusPurple : Color.nexusSurface)
                    .overlay {
                        Capsule()
                            .strokeBorder(isSelected ? Color.clear : Color.nexusBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}
