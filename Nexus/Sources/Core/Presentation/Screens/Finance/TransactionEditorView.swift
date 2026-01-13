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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    HStack(spacing: 12) {
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
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.nexusGreen)
                        }

                        TextField("0.00", text: $amount)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .focused($isAmountFocused)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Title", text: $title)

                    Picker("Category", selection: $category) {
                        ForEach(TransactionCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue.capitalized, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if transaction != nil {
                    Section {
                        Button(role: .destructive) {
                            deleteTransaction()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Transaction")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle(transaction == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .fontWeight(.semibold)
                    .disabled(amount.isEmpty || title.isEmpty)
                }
            }
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

// MARK: - Actions

private extension TransactionEditorView {
    func saveTransaction() {
        guard let amountValue = Double(amount) else { return }

        if let existingTransaction = transaction {
            existingTransaction.title = title
            existingTransaction.amount = amountValue
            existingTransaction.currency = currency.rawValue
            existingTransaction.type = type
            existingTransaction.category = category
            existingTransaction.date = date
            existingTransaction.notes = notes
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

#Preview {
    TransactionEditorView(transaction: nil)
        .preferredColorScheme(.dark)
}
