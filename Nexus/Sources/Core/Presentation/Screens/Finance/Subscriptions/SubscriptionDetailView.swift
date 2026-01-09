import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var subscription: SubscriptionModel

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showPaymentConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    statusCard
                    actionsCard
                    detailsCard

                    if let payments = subscription.payments, !payments.isEmpty {
                        paymentHistoryCard(payments: payments.sorted { $0.paidDate > $1.paidDate })
                    }

                    dangerZone
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle(subscription.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Text("Edit")
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditSubscriptionSheet(subscription: subscription)
            }
            .confirmationDialog("Mark as Paid?", isPresented: $showPaymentConfirmation, titleVisibility: .visible) {
                Button("Record Payment") {
                    markAsPaid()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will record a payment of \(subscription.formattedAmount) and advance the due date to \(subscription.calculateNextDueDate().formatted(date: .abbreviated, time: .omitted))")
            }
            .confirmationDialog("Delete Subscription?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteSubscription()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete this subscription and all payment history.")
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: subscription.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(categoryColor)
            }

            VStack(spacing: 4) {
                Text(subscription.formattedAmount)
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text(subscription.billingCycle.displayName)
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
            }

            if subscription.isInFreeTrial, let daysLeft = subscription.freeTrialDaysLeft {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                    Text("Free trial: \(daysLeft) days left")
                }
                .font(.nexusCaption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    Capsule().fill(Color.nexusGreen)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                StatusItem(
                    icon: "calendar",
                    title: "Next Due",
                    value: subscription.nextDueDate.formatted(date: .abbreviated, time: .omitted),
                    color: dueDateColor
                )

                Spacer()

                StatusItem(
                    icon: "clock",
                    title: "Status",
                    value: subscription.statusText,
                    color: statusColor
                )
            }

            Divider().background(Color.nexusBorder)

            HStack {
                StatusItem(
                    icon: "arrow.clockwise",
                    title: "Monthly",
                    value: subscription.formattedMonthlyAmount,
                    color: .primary
                )

                Spacer()

                StatusItem(
                    icon: "calendar.badge.clock",
                    title: "Yearly",
                    value: formatYearly(subscription.yearlyEquivalent),
                    color: .secondary
                )
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        HStack(spacing: 12) {
            ActionButton(
                icon: "checkmark.circle.fill",
                title: "Mark Paid",
                color: .nexusGreen,
                disabled: subscription.isPaused || !subscription.isActive
            ) {
                showPaymentConfirmation = true
            }

            ActionButton(
                icon: subscription.isPaused ? "play.fill" : "pause.fill",
                title: subscription.isPaused ? "Resume" : "Pause",
                color: .nexusOrange,
                disabled: !subscription.isActive
            ) {
                togglePause()
            }

            if let urlString = subscription.url, let url = URL(string: urlString) {
                Link(destination: url) {
                    VStack(spacing: 8) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 20))
                        Text("Manage")
                            .font(.nexusCaption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.nexusPurple.opacity(0.15))
                    }
                    .foregroundStyle(Color.nexusPurple)
                }
            }
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            DetailRow(label: "Category", value: subscription.category.displayName, icon: subscription.category.icon)
            Divider().background(Color.nexusBorder).padding(.leading, 44)

            DetailRow(label: "Started", value: subscription.startDate.formatted(date: .abbreviated, time: .omitted), icon: "calendar")
            Divider().background(Color.nexusBorder).padding(.leading, 44)

            DetailRow(label: "Reminder", value: "\(subscription.reminderDaysBefore) days before", icon: "bell.fill")

            if !subscription.notes.isEmpty {
                Divider().background(Color.nexusBorder).padding(.leading, 44)
                DetailRow(label: "Notes", value: subscription.notes, icon: "note.text")
            }

            if let url = subscription.url {
                Divider().background(Color.nexusBorder).padding(.leading, 44)
                DetailRow(label: "Website", value: url, icon: "link")
            }
        }
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    // MARK: - Payment History

    private func paymentHistoryCard(payments: [SubscriptionPaymentModel]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Payment History")
                    .font(.nexusHeadline)
                Spacer()
                Text("\(payments.count) payments")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(payments.prefix(10)) { payment in
                    PaymentRow(payment: payment)

                    if payment.id != payments.prefix(10).last?.id {
                        Divider().background(Color.nexusBorder).padding(.leading, 44)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: 12) {
            if subscription.isActive {
                Button {
                    cancelSubscription()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel Subscription")
                    }
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                    }
                }
            }

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Subscription")
                }
                .font(.nexusSubheadline)
                .fontWeight(.medium)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                }
            }
        }
    }

    // MARK: - Helpers

    private var categoryColor: Color {
        Color.named(subscription.color)
    }

    private var dueDateColor: Color {
        if subscription.isOverdue { return .red }
        if subscription.isDueSoon { return .orange }
        return .primary
    }

    private var statusColor: Color {
        switch subscription.statusText {
        case "Overdue": return .red
        case "Due Today", "Due Soon": return .orange
        case "Paused": return .gray
        case "Cancelled": return .gray
        case "Free Trial": return .green
        default: return .green
        }
    }

    private func formatYearly(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = subscription.currency
        if subscription.currency == "GEL" { formatter.currencySymbol = "₾" }
        return formatter.string(from: NSNumber(value: amount)) ?? "\(subscription.currency) \(amount)"
    }

    private func markAsPaid() {
        subscription.markAsPaid()
        try? modelContext.save()
    }

    private func togglePause() {
        subscription.isPaused.toggle()
        try? modelContext.save()
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

// MARK: - Supporting Views

private struct StatusItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
            }
            .font(.nexusCaption)
            .foregroundStyle(.secondary)

            Text(value)
                .font(.nexusSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}

private struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.nexusCaption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(disabled ? 0.05 : 0.15))
            }
            .foregroundStyle(disabled ? Color.gray.opacity(0.5) : color)
        }
        .disabled(disabled)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(label)
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.nexusSubheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct PaymentRow: View {
    let payment: SubscriptionPaymentModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
                .frame(width: 24)

            Text(payment.paidDate.formatted(date: .abbreviated, time: .omitted))
                .font(.nexusSubheadline)
                .foregroundStyle(.primary)

            Spacer()

            Text(formattedAmount)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = payment.currency
        if payment.currency == "GEL" { formatter.currencySymbol = "₾" }
        return formatter.string(from: NSNumber(value: payment.amount)) ?? "\(payment.currency) \(payment.amount)"
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

