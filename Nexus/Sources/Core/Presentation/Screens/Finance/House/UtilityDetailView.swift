import SwiftUI
import SwiftData

struct UtilityDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var utility: UtilityAccountModel

    @State private var showAddPayment = false
    @State private var showAddReading = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    accountInfoCard
                    quickActions

                    if utility.type.hasReadings {
                        readingsSection
                    }

                    if hasFinanceData {
                        financeSection
                    }

                    dangerZone
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle(utility.provider)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("რედაქტირება") {
                        showEditSheet = true
                    }
                    .font(.nexusCaption)
                }
            }
            .sheet(isPresented: $showAddPayment) {
                AddPaymentSheet(utility: utility)
            }
            .sheet(isPresented: $showAddReading) {
                AddReadingSheet(utility: utility)
            }
            .sheet(isPresented: $showEditSheet) {
                EditUtilitySheet(utility: utility)
            }
            .confirmationDialog("წაშლა?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("წაშლა", role: .destructive) {
                    deleteUtility()
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var hasFinanceData: Bool {
        utility.monthlyAverage > 0 || utility.nextDueDate != nil || !(utility.payments?.isEmpty ?? true)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(utilityColor.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: utility.type.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(utilityColor)
            }

            VStack(spacing: 4) {
                Text(utility.type.displayName)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                Text(utility.provider)
                    .font(.nexusHeadline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
        }
    }

    // MARK: - Account Info Card

    private var accountInfoCard: some View {
        VStack(spacing: 0) {
            InfoRow(icon: "person.text.rectangle", label: "აბონენტის ID", value: utility.customerId, isCopyable: true)

            if let meter = utility.meterNumber {
                Divider().background(Color.nexusBorder).padding(.leading, 48)
                InfoRow(icon: "gauge", label: "მრიცხველის ნომერი", value: meter, isCopyable: true)
            }

            if let contract = utility.contractNumber {
                Divider().background(Color.nexusBorder).padding(.leading, 48)
                InfoRow(icon: "doc.text", label: "ხელშეკრულება", value: contract, isCopyable: true)
            }

            if let phone = utility.phoneNumber {
                Divider().background(Color.nexusBorder).padding(.leading, 48)
                InfoRow(icon: "phone", label: "ტელეფონი", value: phone, isCopyable: false)
            }

            if !utility.notes.isEmpty {
                Divider().background(Color.nexusBorder).padding(.leading, 48)
                InfoRow(icon: "note.text", label: "შენიშვნები", value: utility.notes, isCopyable: false)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            if let phone = utility.phoneNumber, let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                Link(destination: url) {
                    VStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 18))
                        Text("დარეკვა")
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.nexusGreen.opacity(0.15))
                    }
                    .foregroundStyle(Color.nexusGreen)
                }
            }

            Button {
                UIPasteboard.general.string = utility.customerId
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 18))
                    Text("ID კოპირება")
                        .font(.system(size: 11))
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.nexusPurple.opacity(0.15))
                }
                .foregroundStyle(Color.nexusPurple)
            }

            if utility.type.hasReadings {
                Button {
                    showAddReading = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "gauge")
                            .font(.system(size: 18))
                        Text("მაჩვენებელი")
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.nexusOrange.opacity(0.15))
                    }
                    .foregroundStyle(Color.nexusOrange)
                }
            }
        }
    }

    // MARK: - Finance Section

    private var financeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ფინანსები")
                    .font(.nexusHeadline)
                Spacer()
                Button("გადახდის ჩაწერა") {
                    showAddPayment = true
                }
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusGreen)
            }

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("საშუალო თვიური")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("₾\(String(format: "%.0f", utility.monthlyAverage))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 40)

                    VStack(spacing: 4) {
                        Text("შემდეგი გადახდა")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        if let dueDate = utility.nextDueDate {
                            Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.nexusSubheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(dueColor)
                        } else {
                            Text("-")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 40)

                    VStack(spacing: 4) {
                        Text("ბოლო გადახდა")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        if let lastDate = utility.lastPaymentDate {
                            Text(lastDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.nexusCaption)
                        } else {
                            Text("-")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 14)

                if let payments = utility.payments?.sorted(by: { $0.date > $1.date }), !payments.isEmpty {
                    Divider().background(Color.nexusBorder)

                    ForEach(payments.prefix(5)) { payment in
                        PaymentRow(payment: payment)

                        if payment.id != payments.prefix(5).last?.id {
                            Divider().background(Color.nexusBorder).padding(.leading, 44)
                        }
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
            }
        }
    }

    // MARK: - Readings Section

    private var readingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("მაჩვენებლები")
                    .font(.nexusHeadline)
                Spacer()
                Button("დამატება") {
                    showAddReading = true
                }
                .font(.nexusCaption)
                .foregroundStyle(Color.nexusPurple)
            }

            if let readings = utility.readings?.sorted(by: { $0.date > $1.date }), !readings.isEmpty {
                VStack(spacing: 0) {
                    ForEach(readings.prefix(5)) { reading in
                        ReadingRow(reading: reading)

                        if reading.id != readings.prefix(5).last?.id {
                            Divider().background(Color.nexusBorder).padding(.leading, 44)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.nexusSurface)
                }
            } else {
                emptyReadings
            }
        }
    }

    private var emptyReadings: some View {
        VStack(spacing: 8) {
            Image(systemName: "gauge")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("მაჩვენებლები არ არის")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("წაშლა")
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

    // MARK: - Helpers

    private var utilityColor: Color {
        Color.named(utility.type.color)
    }

    private var dueColor: Color {
        guard let days = utility.daysUntilDue else { return .primary }
        if days < 0 { return .red }
        if days <= 3 { return .orange }
        return .primary
    }

    private func deleteUtility() {
        modelContext.delete(utility)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    let isCopyable: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 14, weight: .medium, design: isCopyable ? .monospaced : .default))
            }

            Spacer()

            if isCopyable {
                Button {
                    UIPasteboard.general.string = value
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Reading Row

private struct ReadingRow: View {
    let reading: UtilityReadingModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gauge")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(String(format: "%.0f", reading.value))")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))

                Text(reading.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let consumption = reading.consumption {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(String(format: "%.0f", consumption))")
                        .font(.nexusCaption)
                        .foregroundStyle(.orange)
                    Text("მოხმარება")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Payment Row

private struct PaymentRow: View {
    let payment: UtilityPaymentModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("₾\(String(format: "%.2f", payment.amount))")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                Text(payment.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let method = payment.paymentMethod {
                Text(method)
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Add Payment Sheet

struct AddPaymentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let utility: UtilityAccountModel

    @State private var amount = ""
    @State private var date = Date()
    @State private var paymentMethod = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("გადახდის დეტალები") {
                    TextField("თანხა (₾)", text: $amount)
                        .keyboardType(.decimalPad)

                    DatePicker("თარიღი", selection: $date, displayedComponents: .date)

                    TextField("გადახდის მეთოდი (არასავალდებულო)", text: $paymentMethod)
                }

                Section {
                    TextField("შენიშვნა", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Button {
                        recordPayment()
                    } label: {
                        HStack {
                            Spacer()
                            Text("გადახდის ჩაწერა")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(Double(amount) == nil || Double(amount) == 0)
                }
            }
            .navigationTitle("გადახდა")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("გაუქმება") { dismiss() }
                }
            }
        }
    }

    private func recordPayment() {
        guard let amountValue = Double(amount) else { return }
        utility.recordPayment(amount: amountValue, date: date, notes: notes)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Add Reading Sheet

struct AddReadingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let utility: UtilityAccountModel

    @State private var value = ""
    @State private var date = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("მაჩვენებელი") {
                    TextField("მიმდინარე მაჩვენებელი", text: $value)
                        .keyboardType(.decimalPad)

                    DatePicker("თარიღი", selection: $date, displayedComponents: .date)
                }

                if let lastReading = utility.lastReading, let currentValue = Double(value) {
                    Section("მოხმარება") {
                        let consumption = currentValue - lastReading.value
                        HStack {
                            Text("წინა მაჩვენებელი:")
                            Spacer()
                            Text("\(String(format: "%.0f", lastReading.value))")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("მოხმარება:")
                            Spacer()
                            Text("\(String(format: "%.0f", max(0, consumption)))")
                                .fontWeight(.semibold)
                                .foregroundStyle(consumption >= 0 ? .orange : .red)
                        }
                    }
                }

                Section {
                    TextField("შენიშვნა", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    Button {
                        recordReading()
                    } label: {
                        HStack {
                            Spacer()
                            Text("ჩაწერა")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(Double(value) == nil)
                }
            }
            .navigationTitle("მაჩვენებელი")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("გაუქმება") { dismiss() }
                }
            }
        }
    }

    private func recordReading() {
        guard let readingValue = Double(value) else { return }
        utility.recordReading(value: readingValue, date: date)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Utility Sheet

struct EditUtilitySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var utility: UtilityAccountModel

    var body: some View {
        NavigationStack {
            Form {
                Section("ინფორმაცია") {
                    TextField("პროვაიდერი", text: $utility.provider)
                    TextField("მომხმარებლის ID", text: $utility.customerId)

                    TextField("მრიცხველის ნომერი", text: Binding(
                        get: { utility.meterNumber ?? "" },
                        set: { utility.meterNumber = $0.isEmpty ? nil : $0 }
                    ))

                    TextField("ტელეფონი", text: Binding(
                        get: { utility.phoneNumber ?? "" },
                        set: { utility.phoneNumber = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("გადახდა") {
                    TextField("საშუალო თვიური (₾)", value: $utility.monthlyAverage, format: .number)
                        .keyboardType(.decimalPad)

                    if let nextDue = Binding($utility.nextDueDate) {
                        DatePicker("შემდეგი გადახდა", selection: nextDue, displayedComponents: .date)
                    }
                }

                Section {
                    Toggle("აქტიური", isOn: $utility.isActive)
                }

                Section {
                    TextField("შენიშვნები", text: $utility.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("რედაქტირება")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("გაუქმება") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("შენახვა") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

