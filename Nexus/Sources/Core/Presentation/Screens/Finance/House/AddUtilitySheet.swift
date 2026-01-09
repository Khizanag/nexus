import SwiftUI
import SwiftData

struct AddUtilitySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let house: HouseModel

    @State private var selectedType: UtilityType?
    @State private var selectedProvider: GeorgianUtilityProvider?
    @State private var customerId = ""
    @State private var accountNumber = ""
    @State private var meterNumber = ""
    @State private var phoneNumber = ""
    @State private var monthlyAverage = ""
    @State private var nextDueDate = Date()
    @State private var notes = ""

    @State private var step = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator

                if step == 1 {
                    typeSelectionView
                } else if step == 2 {
                    providerSelectionView
                } else {
                    detailsForm
                }
            }
            .background(Color.nexusBackground)
            .navigationTitle("კომუნალურის დამატება")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("გაუქმება") { dismiss() }
                }
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.nexusPurple : Color.nexusBorder)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Step 1: Type Selection

    private var typeSelectionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("აირჩიეთ კომუნალურის ტიპი")
                    .font(.nexusHeadline)
                    .padding(.horizontal, 20)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(UtilityType.allCases) { type in
                        TypeCard(type: type, isSelected: selectedType == type) {
                            selectedType = type
                            withAnimation(.spring(response: 0.3)) {
                                step = 2
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Step 2: Provider Selection

    private var providerSelectionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            step = 1
                            selectedType = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Text("აირჩიეთ პროვაიდერი")
                        .font(.nexusHeadline)
                }
                .padding(.horizontal, 20)

                if let type = selectedType {
                    let providers = GeorgianUtilityProvider.providers(for: type)

                    VStack(spacing: 0) {
                        ForEach(providers) { provider in
                            ProviderRow(provider: provider) {
                                selectedProvider = provider
                                withAnimation(.spring(response: 0.3)) {
                                    step = 3
                                }
                            }

                            if provider.id != providers.last?.id {
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
                    .padding(.horizontal, 20)

                    // Custom provider option
                    Button {
                        selectedProvider = nil
                        withAnimation(.spring(response: 0.3)) {
                            step = 3
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("სხვა პროვაიდერი")
                                .font(.nexusSubheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.nexusSurface)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Step 3: Details Form

    private var detailsForm: some View {
        Form {
            Section {
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            step = 2
                            selectedProvider = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    if let provider = selectedProvider {
                        Text(provider.nameGeorgian)
                            .font(.nexusHeadline)
                    } else {
                        Text("დეტალები")
                            .font(.nexusHeadline)
                    }
                }
            }

            Section("აბონენტის ინფორმაცია") {
                TextField("მომხმარებლის ID / აბონენტის ნომერი", text: $customerId)
                    .keyboardType(.numberPad)

                if selectedType?.hasReadings == true {
                    TextField("მრიცხველის ნომერი (არასავალდებულო)", text: $meterNumber)
                }

                TextField("ტელეფონის ნომერი (არასავალდებულო)", text: $phoneNumber)
                    .keyboardType(.phonePad)
            }

            Section {
                TextField("შენიშვნები", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section {
                DisclosureGroup("ფინანსური დეტალები (არასავალდებულო)") {
                    TextField("საშუალო თვიური (₾)", text: $monthlyAverage)
                        .keyboardType(.decimalPad)

                    DatePicker("შემდეგი გადახდის თარიღი", selection: $nextDueDate, displayedComponents: .date)
                }
            }

            Section {
                Button {
                    addUtility()
                } label: {
                    HStack {
                        Spacer()
                        Text("დამატება")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(customerId.isEmpty)
            }

            if let provider = selectedProvider {
                Section("დამატებითი ინფორმაცია") {
                    if let website = provider.website {
                        Link(destination: URL(string: website)!) {
                            HStack {
                                Image(systemName: "safari")
                                Text("ვებგვერდი")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                        }
                    }

                    if let phone = provider.phone {
                        Link(destination: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))")!) {
                            HStack {
                                Image(systemName: "phone")
                                Text(phone)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                        }
                    }

                    Text("ფორმატი: \(provider.customerIdFormat)")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Add Utility

    private func addUtility() {
        guard let type = selectedType else { return }

        let utility = UtilityAccountModel(
            type: type,
            provider: selectedProvider?.nameGeorgian ?? type.displayName,
            providerIcon: selectedProvider?.icon ?? type.icon,
            customerId: customerId,
            meterNumber: meterNumber.isEmpty ? nil : meterNumber,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            monthlyAverage: Double(monthlyAverage) ?? 0,
            notes: notes,
            house: house
        )
        utility.nextDueDate = nextDueDate

        modelContext.insert(utility)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Type Card

private struct TypeCard: View {
    let type: UtilityType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(typeColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: type.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(typeColor)
                }

                VStack(spacing: 2) {
                    Text(type.displayName)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)

                    Text(type.displayNameEnglish)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? typeColor : Color.nexusBorder, lineWidth: isSelected ? 2 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var typeColor: Color {
        Color.named(type.color)
    }
}

// MARK: - Provider Row

private struct ProviderRow: View {
    let provider: GeorgianUtilityProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(providerColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: provider.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(providerColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.nameGeorgian)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)

                    Text(provider.name)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var providerColor: Color {
        Color.named(provider.type.color)
    }
}

