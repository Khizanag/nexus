import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var subscription: SubscriptionModel

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showPaymentConfirmation = false
    @State private var hapticTrigger = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                headerSection
                statusSection
                actionsSection
                detailsSection
                if let payments = subscription.payments, !payments.isEmpty {
                    paymentHistorySection(payments.sorted { $0.paidDate > $1.paidDate })
                }
                dangerSection
            }
            .listStyle(.insetGrouped)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Color.nexusBackground)
            .navigationTitle(subscription.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEditSheet = true }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditSubscriptionSheet(subscription: subscription)
            }
            .confirmationDialog("Mark as Paid?", isPresented: $showPaymentConfirmation, titleVisibility: .visible) {
                Button("Record Payment") { markAsPaid() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will record a payment of \(subscription.formattedAmount) and advance the due date to \(subscription.calculateNextDueDate().formatted(date: .abbreviated, time: .omitted))")
            }
            .confirmationDialog("Delete Subscription?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteSubscription() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete this subscription and all payment history.")
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: hapticTrigger)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: subscription.icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(categoryColor)
                        .accessibilityHidden(true)
                }

                VStack(spacing: DesignSystem.Spacing.xxs) {
                    Text(subscription.formattedAmount)
                        .font(.nexusDisplayNumber(.title))

                    Text(subscription.billingCycle.displayName)
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)
                }

                if subscription.isInFreeTrial, let daysLeft = subscription.freeTrialDaysLeft {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "gift.fill").accessibilityHidden(true)
                        Text("Free trial: \(daysLeft) days left")
                    }
                    .font(.nexusCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background { Capsule().fill(Color.nexusGreen) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .listRowBackground(Color.nexusSurface)
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            LabeledContent("Next Due") {
                Text(subscription.nextDueDate.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(dueDateColor)
            }
            .accessibilityLabel("Next due, \(subscription.nextDueDate.formatted(date: .abbreviated, time: .omitted))")

            LabeledContent("Status") {
                Text(subscription.statusText)
                    .foregroundStyle(statusColor)
            }

            LabeledContent("Monthly") {
                Text(subscription.formattedMonthlyAmount)
            }

            LabeledContent("Yearly") {
                Text(formattedYearly)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            GlassEffectContainer(spacing: DesignSystem.Spacing.sm) {
                Button {
                    showPaymentConfirmation = true
                } label: {
                    Label("Mark Paid", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.glass)
                .disabled(subscription.isPaused || !subscription.isActive)
                .tint(.nexusGreen)

                Button {
                    togglePause()
                } label: {
                    Label(subscription.isPaused ? "Resume" : "Pause", systemImage: subscription.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.glass)
                .disabled(!subscription.isActive)
                .tint(.nexusOrange)

                if let urlString = subscription.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Label("Manage", systemImage: "safari.fill")
                    }
                    .buttonStyle(.glass)
                    .tint(.nexusPurple)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xs, leading: DesignSystem.Spacing.md, bottom: DesignSystem.Spacing.xs, trailing: DesignSystem.Spacing.md))
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent {
                Text(subscription.category.displayName)
            } label: {
                Label("Category", systemImage: subscription.category.icon)
            }

            LabeledContent {
                Text(subscription.startDate.formatted(date: .abbreviated, time: .omitted))
            } label: {
                Label("Started", systemImage: "calendar")
            }

            LabeledContent {
                Text("\(subscription.reminderDaysBefore) days before")
            } label: {
                Label("Reminder", systemImage: "bell.fill")
            }

            if !subscription.notes.isEmpty {
                LabeledContent {
                    Text(subscription.notes)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Notes", systemImage: "note.text")
                }
            }

            if let url = subscription.url {
                LabeledContent {
                    Text(url)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                } label: {
                    Label("Website", systemImage: "link")
                }
            }
        }
    }

    // MARK: - Payment History

    private func paymentHistorySection(_ payments: [SubscriptionPaymentModel]) -> some View {
        Section {
            ForEach(payments.prefix(10)) { payment in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)

                    Text(payment.paidDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.nexusSubheadline)

                    Spacer()

                    Text(payment.amount.formatted(.currency(code: payment.currency)))
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(payment.paidDate.formatted(date: .abbreviated, time: .omitted)), \(payment.amount.formatted(.currency(code: payment.currency)))")
            }
        } header: {
            HStack {
                Text("Payment History")
                Spacer()
                Text("\(payments.count) payments")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.regular)
            }
        }
    }

    // MARK: - Danger

    private var dangerSection: some View {
        Section {
            if subscription.isActive {
                Button(role: .destructive) {
                    cancelSubscription()
                } label: {
                    Label("Cancel Subscription", systemImage: "xmark.circle.fill")
                }
                .foregroundStyle(.orange)
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Subscription", systemImage: "trash.fill")
            }
        }
    }

    // MARK: - Helpers

    private var categoryColor: Color { Color.named(subscription.color) }

    private var dueDateColor: Color {
        if subscription.isOverdue { return .red }
        if subscription.isDueSoon { return .orange }
        return .primary
    }

    private var statusColor: Color {
        switch subscription.statusText {
        case "Overdue": return .red
        case "Due Today", "Due Soon": return .orange
        case "Paused", "Cancelled": return .gray
        case "Free Trial": return .green
        default: return .green
        }
    }

    private var formattedYearly: String {
        subscription.yearlyEquivalent.formatted(.currency(code: subscription.currency))
    }

    private func markAsPaid() {
        subscription.markAsPaid()
        try? modelContext.save()
        hapticTrigger.toggle()
    }

    private func togglePause() {
        subscription.isPaused.toggle()
        try? modelContext.save()
        hapticTrigger.toggle()
    }

    private func cancelSubscription() {
        subscription.isActive = false
        try? modelContext.save()
    }

    private func deleteSubscription() {
        modelContext.delete(subscription)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Subscription Sheet

struct EditSubscriptionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var subscription: SubscriptionModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $subscription.name)

                    HStack {
                        TextField("Amount", value: $subscription.amount, format: .number)
                            .keyboardType(.decimalPad)

                        Picker("Currency", selection: $subscription.currency) {
                            Text("₾ GEL").tag("GEL")
                            Text("$ USD").tag("USD")
                            Text("€ EUR").tag("EUR")
                        }
                        .labelsHidden()
                    }

                    Picker("Billing Cycle", selection: $subscription.billingCycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.displayName).tag(cycle)
                        }
                    }

                    Picker("Category", selection: $subscription.category) {
                        ForEach(SubscriptionCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .onChange(of: subscription.category) { _, newCategory in
                        subscription.icon = newCategory.icon
                        subscription.color = newCategory.color
                    }
                }

                Section("Dates") {
                    DatePicker("Next Due Date", selection: $subscription.nextDueDate, displayedComponents: .date)
                    Stepper("Remind \(subscription.reminderDaysBefore) days before", value: $subscription.reminderDaysBefore, in: 1...14)
                }

                Section("Additional") {
                    TextField("Website URL", text: Binding(
                        get: { subscription.url ?? "" },
                        set: { subscription.url = $0.isEmpty ? nil : $0 }
                    ))
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)

                    TextField("Notes", text: $subscription.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
