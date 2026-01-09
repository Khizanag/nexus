import SwiftUI
import SwiftData

struct SubscriptionsSummaryCard: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<SubscriptionModel> { $0.isActive && !$0.isPaused },
        sort: \SubscriptionModel.nextDueDate
    ) private var activeSubscriptions: [SubscriptionModel]

    @AppStorage("currency") private var preferredCurrency = "GEL"

    @State private var showSubscriptionsView = false
    @State private var exchangeRates: ExchangeRates?
    @State private var isLoadingRates = false

    private var targetCurrency: Currency {
        Currency(rawValue: preferredCurrency) ?? .gel
    }

    private var monthlyTotalConverted: Double {
        guard let rates = exchangeRates else {
            return activeSubscriptions
                .filter { $0.currency == preferredCurrency }
                .reduce(0) { $0 + $1.monthlyEquivalent }
        }

        let service = DefaultCurrencyService()
        return activeSubscriptions.reduce(0) { total, sub in
            let fromCurrency = Currency(rawValue: sub.currency) ?? .gel
            let converted = service.convert(
                amount: sub.monthlyEquivalent,
                from: fromCurrency,
                to: targetCurrency,
                rates: rates
            )
            return total + converted
        }
    }

    private var upcomingCount: Int {
        activeSubscriptions.filter { $0.daysUntilDue <= 7 && $0.daysUntilDue >= 0 }.count
    }

    private var overdueCount: Int {
        activeSubscriptions.filter { $0.isOverdue }.count
    }

    private var upcomingSubscriptions: [SubscriptionModel] {
        Array(activeSubscriptions
            .filter { $0.daysUntilDue >= 0 }
            .prefix(3))
    }

    private var uniqueSubscriptionIcons: [(icon: String, color: String, name: String)] {
        var seen = Set<String>()
        return activeSubscriptions.compactMap { sub in
            guard !seen.contains(sub.name) else { return nil }
            seen.insert(sub.name)
            return (sub.icon, sub.color, sub.name)
        }
    }

    private var hasMixedCurrencies: Bool {
        let currencies = Set(activeSubscriptions.map { $0.currency })
        return currencies.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if !activeSubscriptions.isEmpty {
                Divider().background(Color.nexusBorder)
                contentView
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
        .onTapGesture {
            showSubscriptionsView = true
        }
        .sheet(isPresented: $showSubscriptionsView) {
            SubscriptionsView()
        }
        .task {
            await loadExchangeRates()
        }
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.nexusPurple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.nexusPurple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Subscriptions")
                        .font(.nexusHeadline)

                    if !activeSubscriptions.isEmpty {
                        HStack(spacing: 8) {
                            Text("\(activeSubscriptions.count) active")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)

                            if overdueCount > 0 {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                    Text("\(overdueCount) overdue")
                                        .font(.nexusCaption)
                                        .foregroundStyle(.red)
                                }
                            } else if upcomingCount > 0 {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6, height: 6)
                                    Text("\(upcomingCount) due soon")
                                        .font(.nexusCaption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
    }

    private var contentView: some View {
        VStack(spacing: 10) {
            if !uniqueSubscriptionIcons.isEmpty {
                subscriptionIconsRow
            }

            if !activeSubscriptions.isEmpty {
                Divider().background(Color.nexusBorder)
                monthlyTotalRow
            }
        }
        .padding(12)
    }

    private var subscriptionIconsRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(uniqueSubscriptionIcons.prefix(6).enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.named(item.color).opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.named(item.color))
                    }

                    Text(item.name)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }

            if uniqueSubscriptionIcons.count > 6 {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Text("+\(uniqueSubscriptionIcons.count - 6)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Text("more")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthlyTotalRow: some View {
        HStack {
            Text("Monthly total:")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)

            Spacer()

            if isLoadingRates && hasMixedCurrencies {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedMonthly)
                        .font(.system(size: 16, weight: .bold, design: .rounded))

                    if hasMixedCurrencies && exchangeRates != nil {
                        Text("converted")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    } else if hasMixedCurrencies && exchangeRates == nil {
                        Text("(\(targetCurrency.rawValue) only)")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var formattedMonthly: String {
        targetCurrency.format(monthlyTotalConverted)
    }

    private func loadExchangeRates() async {
        guard hasMixedCurrencies else { return }

        isLoadingRates = true
        defer { isLoadingRates = false }

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
            // Try stale cached rates
            if let cached = CurrencyCache.getCachedRates(base: targetCurrency, context: modelContext) {
                exchangeRates = cached
            } else {
                // Use fallback hardcoded rates as last resort
                exchangeRates = service.getFallbackRates(base: targetCurrency)
            }
        }
    }
}

// MARK: - Subscription Mini Row

private struct SubscriptionMiniRow: View {
    let subscription: SubscriptionModel

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: subscription.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(categoryColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)

                Text(dueDateText)
                    .font(.nexusCaption)
                    .foregroundStyle(dueDateColor)
            }

            Spacer()

            Text(subscription.formattedAmount)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var categoryColor: Color {
        Color.named(subscription.color)
    }

    private var dueDateText: String {
        let days = subscription.daysUntilDue
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        if days < 0 { return "\(abs(days))d overdue" }
        if days <= 7 { return "Due in \(days)d" }
        return subscription.nextDueDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var dueDateColor: Color {
        let days = subscription.daysUntilDue
        if days < 0 { return .red }
        if days <= 3 { return .orange }
        return .secondary
    }
}

