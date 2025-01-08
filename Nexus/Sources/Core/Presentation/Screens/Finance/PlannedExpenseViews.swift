import SwiftUI
import SwiftData

// MARK: - Planned Expense Row

struct PlannedExpenseRow: View {
    @Bindable var expense: PlannedExpenseModel
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    expense.isPaid.toggle()
                    expense.paidDate = expense.isPaid ? Date() : nil
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: expense.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(expense.isPaid ? Color.nexusGreen : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: expense.icon)
                .font(.system(size: 16))
                .foregroundStyle(expense.isPaid ? .secondary : .primary)
                .frame(width: 32, height: 32)
                .background {
                    Circle().fill(Color.nexusSurface)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name)
                    .font(.nexusSubheadline)
                    .strikethrough(expense.isPaid)
                    .foregroundStyle(expense.isPaid ? .secondary : .primary)

                if expense.isRecurring {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                            .font(.system(size: 10))
                        Text("Recurring")
                    }
                    .font(.nexusCaption2)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(formatCurrency(expense.amount))
                .font(.nexusSubheadline)
                .fontWeight(.medium)
                .foregroundStyle(expense.isPaid ? .secondary : .primary)

            if expense.isPaid {
                Text("Paid")
                    .font(.nexusCaption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background { Capsule().fill(Color.nexusGreen) }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface.opacity(expense.isPaid ? 0.5 : 1))
        }
        .contextMenu {
            Button {
                withAnimation {
                    expense.isPaid.toggle()
                    expense.paidDate = expense.isPaid ? Date() : nil
                }
            } label: {
                Label(expense.isPaid ? "Mark as Unpaid" : "Mark as Paid",
                      systemImage: expense.isPaid ? "circle" : "checkmark.circle.fill")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Add Planned Expense Sheet

struct AddPlannedExpenseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let budget: BudgetModel

    @State private var name = ""
    @State private var amount = ""
    @State private var selectedIcon = "dollarsign.circle.fill"
    @State private var isRecurring = true
    @State private var notes = ""

    @FocusState private var amountFocused: Bool

    private var isValid: Bool {
        !name.isEmpty && (Double(amount) ?? 0) > 0
    }

    private let iconOptions = [
        "tv.fill",
        "music.note",
        "film.fill",
        "gamecontroller.fill",
        "icloud.fill",
        "newspaper.fill",
        "book.fill",
        "dumbbell.fill",
        "car.fill",
        "house.fill",
        "phone.fill",
        "wifi",
        "creditcard.fill",
        "gift.fill",
        "heart.fill",
        "star.fill"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    amountCard
                    detailsSection
                    iconSection
                    settingsSection
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle("Add Planned Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveExpense() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Sections

private extension AddPlannedExpenseSheet {
    var amountCard: some View {
        VStack(spacing: 12) {
            Text("Expected Amount")
                .font(.nexusSubheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField("0", text: $amount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($amountFocused)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
        .onTapGesture { amountFocused = true }
    }

    var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                HStack {
                    Text("Name")
                        .font(.nexusSubheadline)
                    Spacer()
                    TextField("e.g., Netflix", text: $name)
                        .font(.nexusSubheadline)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().background(Color.nexusBorder)

                HStack {
                    Text("Notes")
                        .font(.nexusSubheadline)
                    Spacer()
                    TextField("Optional", text: $notes)
                        .font(.nexusSubheadline)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
        }
    }

    var iconSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Icon")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(iconOptions, id: \.self) { icon in
                    iconButton(icon)
                }
            }
        }
    }

    func iconButton(_ icon: String) -> some View {
        let isSelected = selectedIcon == icon

        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedIcon = icon
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 50, height: 50)
                .background {
                    if isSelected {
                        Circle().fill(Color.nexusPurple)
                    } else {
                        Circle()
                            .fill(Color.nexusSurface)
                            .overlay {
                                Circle().strokeBorder(Color.nexusBorder, lineWidth: 1)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            Toggle(isOn: $isRecurring) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                        .foregroundStyle(Color.nexusBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recurring")
                        Text("Repeats each budget period")
                            .font(.nexusCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(Color.nexusBlue)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: - Actions

private extension AddPlannedExpenseSheet {
    func saveExpense() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }

        let expense = PlannedExpenseModel(
            name: name,
            amount: amountValue,
            icon: selectedIcon,
            isRecurring: isRecurring,
            notes: notes,
            budget: budget
        )

        modelContext.insert(expense)
        dismiss()
    }
}

// MARK: - Planned Expenses Summary Card

struct PlannedExpensesSummaryCard: View {
    let plannedTotal: Double
    let paidTotal: Double
    let budgetAmount: Double

    private var remainingForOther: Double {
        budgetAmount - plannedTotal
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Budget Allocation")
                    .font(.nexusHeadline)
                Spacer()
            }

            HStack(spacing: 0) {
                if plannedTotal > 0 {
                    Rectangle()
                        .fill(Color.nexusPurple)
                        .frame(width: max(4, CGFloat(plannedTotal / budgetAmount) * 200))
                }
                if remainingForOther > 0 {
                    Rectangle()
                        .fill(Color.nexusSurface)
                        .frame(width: max(4, CGFloat(remainingForOther / budgetAmount) * 200))
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)

            HStack(spacing: 20) {
                legendItem(color: .nexusPurple, label: "Planned", value: plannedTotal)
                legendItem(color: .nexusSurface, label: "Available", value: remainingForOther)
            }

            if paidTotal > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.nexusGreen)
                    Text("\(formatCurrency(paidTotal)) already paid")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }

    private func legendItem(color: Color, label: String, value: Double) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.nexusCaption2)
                    .foregroundStyle(.secondary)
                Text(formatCurrency(value))
                    .font(.nexusSubheadline)
                    .fontWeight(.medium)
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
