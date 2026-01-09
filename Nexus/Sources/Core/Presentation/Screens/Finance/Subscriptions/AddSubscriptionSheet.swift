import SwiftUI
import SwiftData

struct AddSubscriptionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var searchText = ""

    // Custom subscription fields
    @State private var name = ""
    @State private var amount = ""
    @State private var currency = "GEL"
    @State private var billingCycle = BillingCycle.monthly
    @State private var category = SubscriptionCategory.other
    @State private var icon = "creditcard.fill"
    @State private var color = "blue"
    @State private var startDate = Date()
    @State private var nextDueDate = Date()
    @State private var reminderDays = 3
    @State private var notes = ""
    @State private var url = ""
    @State private var hasFreeTrial = false
    @State private var freeTrialEndDate = Date().addingTimeInterval(7 * 24 * 3600)

    private var filteredPopular: [PopularSubscription] {
        if searchText.isEmpty {
            return PopularSubscription.all
        }
        return PopularSubscription.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedByCategory: [SubscriptionCategory: [PopularSubscription]] {
        Dictionary(grouping: filteredPopular, by: { $0.category })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Popular").tag(0)
                    Text("Custom").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if selectedTab == 0 {
                    popularSubscriptionsView
                } else {
                    customSubscriptionForm
                }
            }
            .background(Color.nexusBackground)
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Popular Subscriptions

    private var popularSubscriptionsView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search subscriptions...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusSurface)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                    ForEach(SubscriptionCategory.allCases) { category in
                        if let subs = groupedByCategory[category], !subs.isEmpty {
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(subs) { popular in
                                        PopularSubscriptionRow(subscription: popular) {
                                            addPopularSubscription(popular)
                                        }

                                        if popular.id != subs.last?.id {
                                            Divider()
                                                .background(Color.nexusBorder)
                                                .padding(.leading, 60)
                                        }
                                    }
                                }
                                .background {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.nexusSurface)
                                }
                            } header: {
                                CategoryHeader(category: category)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Custom Form

    private var customSubscriptionForm: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)

                HStack {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)

                    Picker("Currency", selection: $currency) {
                        Text("₾ GEL").tag("GEL")
                        Text("$ USD").tag("USD")
                        Text("€ EUR").tag("EUR")
                    }
                    .labelsHidden()
                }

                Picker("Billing Cycle", selection: $billingCycle) {
                    ForEach(BillingCycle.allCases, id: \.self) { cycle in
                        Text(cycle.displayName).tag(cycle)
                    }
                }

                Picker("Category", selection: $category) {
                    ForEach(SubscriptionCategory.allCases) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
            }

            Section("Dates") {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("Next Due Date", selection: $nextDueDate, displayedComponents: .date)

                Stepper("Remind \(reminderDays) days before", value: $reminderDays, in: 1...14)
            }

            Section("Free Trial") {
                Toggle("Has Free Trial", isOn: $hasFreeTrial)

                if hasFreeTrial {
                    DatePicker("Trial Ends", selection: $freeTrialEndDate, displayedComponents: .date)
                }
            }

            Section("Additional") {
                TextField("Website URL", text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button {
                    addCustomSubscription()
                } label: {
                    HStack {
                        Spacer()
                        Text("Add Subscription")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(name.isEmpty || amount.isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func addPopularSubscription(_ popular: PopularSubscription) {
        let subscription = SubscriptionModel(
            name: popular.name,
            amount: popular.defaultAmount,
            currency: popular.defaultCurrency,
            billingCycle: popular.defaultCycle,
            category: popular.category,
            icon: popular.icon,
            color: popular.color,
            startDate: Date(),
            nextDueDate: calculateNextDueDate(from: Date(), cycle: popular.defaultCycle),
            url: popular.url
        )

        modelContext.insert(subscription)
        try? modelContext.save()
        dismiss()
    }

    private func addCustomSubscription() {
        guard let amountValue = Double(amount) else { return }

        let subscription = SubscriptionModel(
            name: name,
            amount: amountValue,
            currency: currency,
            billingCycle: billingCycle,
            category: category,
            icon: category.icon,
            color: category.color,
            startDate: startDate,
            nextDueDate: nextDueDate,
            reminderDaysBefore: reminderDays,
            notes: notes,
            url: url.isEmpty ? nil : url,
            freeTrialEndDate: hasFreeTrial ? freeTrialEndDate : nil
        )

        modelContext.insert(subscription)
        try? modelContext.save()
        dismiss()
    }

    private func calculateNextDueDate(from date: Date, cycle: BillingCycle) -> Date {
        let calendar = Calendar.current
        switch cycle {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .biannually:
            return calendar.date(byAdding: .month, value: 6, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case .custom(let days):
            return calendar.date(byAdding: .day, value: days, to: date) ?? date
        }
    }
}

// MARK: - Popular Subscription Row

private struct PopularSubscriptionRow: View {
    let subscription: PopularSubscription
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.named(subscription.color).opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: subscription.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.named(subscription.color))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(subscription.defaultCycle.displayName)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedAmount)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(subscription.defaultCycle.shortName)
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                }

                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.nexusPurple)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = subscription.defaultCurrency
        if subscription.defaultCurrency == "GEL" {
            formatter.currencySymbol = "₾"
        }
        return formatter.string(from: NSNumber(value: subscription.defaultAmount)) ?? "\(subscription.defaultCurrency) \(subscription.defaultAmount)"
    }
}

// MARK: - Category Header

private struct CategoryHeader: View {
    let category: SubscriptionCategory

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.named(category.color))

            Text(category.displayName)
                .font(.nexusHeadline)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nexusBackground)
    }
}

