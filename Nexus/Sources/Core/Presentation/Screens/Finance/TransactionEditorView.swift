import SwiftUI
import SwiftData

struct TransactionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currency") private var preferredCurrency = "USD"

    let transaction: TransactionModel?

    @State private var title: String
    @State private var amount: String
    @State private var type: TransactionType
    @State private var category: TransactionCategory
    @State private var date: Date
    @State private var notes: String
    @State private var currency: Currency

    @FocusState private var isAmountFocused: Bool

    init(transaction: TransactionModel?) {
        self.transaction = transaction
        _title = State(initialValue: transaction?.title ?? "")
        _amount = State(initialValue: transaction.map { String(format: "%.2f", $0.amount) } ?? "")
        _type = State(initialValue: transaction?.type ?? .expense)
        _category = State(initialValue: transaction?.category ?? .other)
        _date = State(initialValue: transaction?.date ?? .now)
        _notes = State(initialValue: transaction?.notes ?? "")
        _currency = State(initialValue: transaction.flatMap { Currency(rawValue: $0.currency) } ?? .usd)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                amountSection
                detailsSection
                notesSection
                if transaction != nil { deleteSection }
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle(transaction == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear {
                if transaction == nil {
                    isAmountFocused = true
                    if let defaultCurrency = Currency(rawValue: preferredCurrency) {
                        currency = defaultCurrency
                    }
                }
            }
        }
    }
}

// MARK: - Toolbar

private extension TransactionEditorView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Save") { saveTransaction() }
                .fontWeight(.semibold)
                .disabled(amount.isEmpty || title.isEmpty)
        }
    }
}

// MARK: - Form Sections

private extension TransactionEditorView {
    var typeSection: some View {
        Section {
            Picker("Type", selection: $type) {
                ForEach(TransactionType.allCases, id: \.self) { t in
                    Text(t.rawValue.capitalized).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .accessibilityLabel("Transaction type")
        }
    }

    var amountSection: some View {
        Section {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Menu {
                    ForEach(Currency.allCases) { curr in
                        Button {
                            currency = curr
                        } label: {
                            HStack {
                                Text(curr.flag)
                                Text(curr.rawValue)
                                Text(curr.symbol)
                                    .foregroundStyle(.secondary)
                                if curr == currency {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(currency.symbol)
                        .font(.nexusDisplayNumber(.title2))
                        .foregroundStyle(Color.nexusGreen)
                }
                .accessibilityLabel("Select currency: \(currency.name)")

                TextField("0.00", text: $amount)
                    .font(.nexusDisplayNumber())
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .accessibilityLabel("Amount")
            }
            .listRowBackground(Color.clear)
        }
    }

    var detailsSection: some View {
        Section {
            TextField("Title", text: $title)
                .accessibilityLabel("Transaction title")

            Picker("Category", selection: $category) {
                ForEach(TransactionCategory.allCases, id: \.self) { cat in
                    Label(cat.rawValue.capitalized, systemImage: cat.icon)
                        .tag(cat)
                }
            }
            .accessibilityLabel("Category")

            DatePicker("Date", selection: $date, displayedComponents: .date)
                .accessibilityLabel("Transaction date")
        }
    }

    var notesSection: some View {
        Section {
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .accessibilityLabel("Notes")
        }
    }

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                deleteTransaction()
            } label: {
                Label("Delete Transaction", systemImage: "trash")
            }
        }
    }
}

// MARK: - Actions

private extension TransactionEditorView {
    func saveTransaction() {
        guard let amountValue = Double(amount) else { return }

        if let existing = transaction {
            existing.title = title
            existing.amount = amountValue
            existing.currency = currency.rawValue
            existing.type = type
            existing.category = category
            existing.date = date
            existing.notes = notes
        } else {
            let newTransaction = TransactionModel(
                amount: amountValue,
                currency: currency.rawValue,
                title: title,
                notes: notes,
                category: category,
                type: type,
                date: date
            )
            modelContext.insert(newTransaction)
        }

        dismiss()
    }

    func deleteTransaction() {
        if let transaction {
            modelContext.delete(transaction)
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    TransactionEditorView(transaction: nil)
}
