import SwiftUI
import SwiftData

struct BudgetEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let budget: BudgetModel?

    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var category: TransactionCategory = .food
    @State private var period: BudgetPeriod = .monthly
    @State private var currency: Currency = .usd
    @State private var alertThreshold: Double = 0.8
    @State private var rolloverEnabled: Bool = false
    @State private var isActive: Bool = true

    @FocusState private var amountFocused: Bool

    private var isEditing: Bool { budget != nil }

    private var isValid: Bool {
        !name.isEmpty && (Double(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    amountSection
                    detailsSection
                    categorySection
                    settingsSection

                    if isEditing {
                        deleteButton
                    }
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle(isEditing ? "Edit Budget" : "New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") { saveBudget() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear { loadBudget() }
        }
    }

    private func loadBudget() {
        guard let budget else { return }
        name = budget.name
        amount = String(format: "%.0f", budget.amount)
        category = budget.category
        period = budget.period
        currency = Currency(rawValue: budget.currency) ?? .usd
        alertThreshold = budget.alertThreshold
        rolloverEnabled = budget.rolloverEnabled
        isActive = budget.isActive
    }

    private func saveBudget() {
        guard let amountValue = Double(amount), amountValue > 0 else { return }

        if let existingBudget = budget {
            existingBudget.name = name
            existingBudget.amount = amountValue
            existingBudget.category = category
            existingBudget.period = period
            existingBudget.currency = currency.rawValue
            existingBudget.alertThreshold = alertThreshold
            existingBudget.rolloverEnabled = rolloverEnabled
            existingBudget.isActive = isActive
            existingBudget.colorHex = category.color
        } else {
            let newBudget = BudgetModel(
                name: name,
                amount: amountValue,
                currency: currency.rawValue,
                category: category,
                period: period,
                isActive: isActive,
                colorHex: category.color,
                icon: category.icon,
                rolloverEnabled: rolloverEnabled,
                alertThreshold: alertThreshold
            )
            modelContext.insert(newBudget)
        }

        dismiss()
    }
}

// MARK: - Amount Section

private extension BudgetEditorView {
    var amountSection: some View {
        ConcentricCard(color: categoryColor) {
            VStack(spacing: 16) {
                Text("Budget Amount")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.white.opacity(0.8))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currency.symbol)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    TextField("0", text: $amount)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .focused($amountFocused)
                }

                Text("per \(period.shortName.lowercased())")
                    .font(.nexusCaption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .onTapGesture { amountFocused = true }
    }

    var categoryColor: Color {
        switch category.color {
        case "orange": .nexusOrange
        case "blue": .nexusBlue
        case "pink": .nexusPink
        case "purple": .nexusPurple
        case "red": .nexusRed
        case "yellow": .yellow
        case "brown": .brown
        case "indigo": .indigo
        case "teal": .nexusTeal
        case "green": .nexusGreen
        case "mint": .mint
        case "cyan": .cyan
        default: .nexusPurple
        }
    }
}

// MARK: - Details Section

private extension BudgetEditorView {
    var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                detailRow(label: "Name") {
                    TextField("Budget name", text: $name)
                        .multilineTextAlignment(.trailing)
                }

                Divider().background(Color.nexusBorder)

                detailRow(label: "Period") {
                    Picker("Period", selection: $period) {
                        ForEach(BudgetPeriod.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }

                Divider().background(Color.nexusBorder)

                detailRow(label: "Currency") {
                    Picker("Currency", selection: $currency) {
                        ForEach(Currency.allCases) { c in
                            Text("\(c.flag) \(c.rawValue)").tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
            }
            .padding(4)
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

    func detailRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.nexusSubheadline)
            Spacer()
            content()
                .font(.nexusSubheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Category Section

private extension BudgetEditorView {
    var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(TransactionCategory.allCases.filter { $0 != .salary && $0 != .investment && $0 != .gift }, id: \.self) { cat in
                    categoryButton(cat)
                }
            }
        }
    }

    func categoryButton(_ cat: TransactionCategory) -> some View {
        let isSelected = category == cat
        let color = categoryColorFor(cat)

        return Button {
            withAnimation(.spring(response: 0.3)) {
                category = cat
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: cat.icon)
                    .font(.system(size: 20))

                Text(cat.rawValue.capitalized)
                    .font(.nexusCaption2)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if isSelected {
                    ConcentricRectangleBackground(
                        cornerRadius: 14,
                        layers: 4,
                        baseColor: color,
                        spacing: 3
                    )
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.nexusSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.nexusBorder, lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }

    func categoryColorFor(_ cat: TransactionCategory) -> Color {
        switch cat.color {
        case "orange": .nexusOrange
        case "blue": .nexusBlue
        case "pink": .nexusPink
        case "purple": .nexusPurple
        case "red": .nexusRed
        case "yellow": .yellow
        case "brown": .brown
        case "indigo": .indigo
        case "teal": .nexusTeal
        case "green": .nexusGreen
        case "mint": .mint
        case "cyan": .cyan
        default: .secondary
        }
    }
}

// MARK: - Settings Section

private extension BudgetEditorView {
    var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.nexusHeadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                Toggle(isOn: $isActive) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.nexusGreen)
                        Text("Active")
                    }
                }
                .tint(Color.nexusGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().background(Color.nexusBorder)

                Toggle(isOn: $rolloverEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Color.nexusBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rollover")
                            Text("Carry unused budget to next period")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(Color.nexusBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().background(Color.nexusBorder)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(Color.nexusOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Alert Threshold")
                            Text("Notify when spending reaches this level")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("\(Int(alertThreshold * 100))%")
                            .font(.nexusHeadline)
                            .monospacedDigit()

                        Slider(value: $alertThreshold, in: 0.5...1.0, step: 0.05)
                            .tint(Color.nexusOrange)
                    }
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
}

// MARK: - Delete Button

private extension BudgetEditorView {
    var deleteButton: some View {
        Button(role: .destructive) {
            if let budget {
                modelContext.delete(budget)
            }
            dismiss()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Budget")
            }
            .font(.nexusHeadline)
            .foregroundStyle(Color.nexusRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.nexusRed.opacity(0.1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.nexusRed.opacity(0.3), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BudgetEditorView(budget: nil)
        .preferredColorScheme(.dark)
}
