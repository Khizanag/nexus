import SwiftUI
import SwiftData

struct HouseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \HouseModel.createdAt, order: .reverse) private var houses: [HouseModel]

    @State private var selectedHouse: HouseModel?
    @State private var showAddHouse = false
    @State private var showAddUtility = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if houses.isEmpty {
                        emptyState
                    } else {
                        ForEach(houses) { house in
                            HouseCard(house: house) {
                                selectedHouse = house
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle("სახლები")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddHouse = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddHouse) {
                AddHouseSheet()
            }
            .sheet(item: $selectedHouse) { house in
                HouseDetailView(house: house)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                Text("სახლი არ არის დამატებული")
                    .font(.nexusHeadline)

                Text("დაამატეთ თქვენი სახლი კომუნალურების სამართავად")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddHouse = true
            } label: {
                Label("სახლის დამატება", systemImage: "plus")
                    .font(.nexusSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background {
                        Capsule().fill(Color.nexusGreen)
                    }
            }
        }
        .padding(40)
    }
}

// MARK: - House Card

struct HouseCard: View {
    let house: HouseModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                headerView
                if !house.activeUtilities.isEmpty {
                    Divider().background(Color.nexusBorder)
                    utilitiesPreview
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(house.isPrimary ? Color.nexusGreen.opacity(0.5) : Color.nexusBorder, lineWidth: house.isPrimary ? 2 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(houseColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: house.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(houseColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(house.name)
                        .font(.nexusHeadline)
                        .fontWeight(.semibold)

                    if house.isPrimary {
                        Text("მთავარი")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background {
                                Capsule().fill(Color.nexusGreen)
                            }
                    }
                }

                Text(house.address)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let district = house.district {
                    Text("\(district), \(house.city)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(house.totalMonthlyEstimate))
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Text("თვიურად")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    private var utilitiesPreview: some View {
        HStack(spacing: 16) {
            ForEach(house.activeUtilities.prefix(5)) { utility in
                VStack(spacing: 4) {
                    Image(systemName: utility.type.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(utilityColor(utility.type))

                    if let days = utility.daysUntilDue {
                        if days <= 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        } else if days <= 7 {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }

            if house.activeUtilities.count > 5 {
                Text("+\(house.activeUtilities.count - 5)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if house.pendingPaymentsCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text("\(house.pendingPaymentsCount) გადასახდელი")
                        .font(.nexusCaption)
                }
                .foregroundStyle(Color.nexusOrange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var houseColor: Color {
        Color.named(house.color)
    }

    private func utilityColor(_ type: UtilityType) -> Color {
        Color.named(type.color)
    }

    private func formatAmount(_ amount: Double) -> String {
        if amount == 0 { return "₾0" }
        return String(format: "₾%.0f", amount)
    }
}

// MARK: - House Detail View

struct HouseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var house: HouseModel

    @State private var showAddUtility = false
    @State private var selectedUtility: UtilityAccountModel?
    @State private var showEditHouse = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    houseInfoCard
                    summaryCard

                    if !house.activeUtilities.isEmpty {
                        utilitiesSection
                    }

                    addUtilityButton
                    dangerZone
                }
                .padding(20)
            }
            .background(Color.nexusBackground)
            .navigationTitle(house.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showEditHouse = true
                    } label: {
                        Text("რედაქტირება")
                            .font(.nexusCaption)
                    }
                }
            }
            .sheet(isPresented: $showAddUtility) {
                AddUtilitySheet(house: house)
            }
            .sheet(item: $selectedUtility) { utility in
                UtilityDetailView(utility: utility)
            }
            .sheet(isPresented: $showEditHouse) {
                EditHouseSheet(house: house)
            }
            .confirmationDialog("სახლის წაშლა?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("წაშლა", role: .destructive) {
                    deleteHouse()
                }
            } message: {
                Text("ეს წაშლის სახლს და ყველა კომუნალურ მონაცემს")
            }
        }
    }

    private var houseInfoCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(houseColor.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: house.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(houseColor)
            }

            VStack(spacing: 4) {
                Text(house.address)
                    .font(.nexusSubheadline)
                    .multilineTextAlignment(.center)

                if let district = house.district {
                    Text("\(district), \(house.city)")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }

                if let apt = house.apartmentNumber {
                    Text("ბინა \(apt)" + (house.floor.map { ", სართული \($0)" } ?? ""))
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            SummaryItem(
                icon: "creditcard.fill",
                value: formatAmount(house.totalMonthlyEstimate),
                label: "თვიური",
                color: .nexusPurple
            )

            Divider()
                .frame(height: 40)
                .background(Color.nexusBorder)

            SummaryItem(
                icon: "bolt.fill",
                value: "\(house.activeUtilities.count)",
                label: "კომუნალური",
                color: .nexusGreen
            )

            Divider()
                .frame(height: 40)
                .background(Color.nexusBorder)

            SummaryItem(
                icon: "exclamationmark.circle.fill",
                value: "\(house.pendingPaymentsCount)",
                label: "გადასახდელი",
                color: house.pendingPaymentsCount > 0 ? .nexusOrange : .gray
            )
        }
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
        }
    }

    private var utilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("კომუნალურები")
                .font(.nexusHeadline)

            VStack(spacing: 0) {
                ForEach(house.activeUtilities) { utility in
                    UtilityRow(utility: utility) {
                        selectedUtility = utility
                    }

                    if utility.id != house.activeUtilities.last?.id {
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
        }
    }

    private var addUtilityButton: some View {
        Button {
            showAddUtility = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("კომუნალურის დამატება")
            }
            .font(.nexusSubheadline)
            .fontWeight(.medium)
            .foregroundStyle(Color.nexusPurple)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.nexusPurple.opacity(0.15))
            }
        }
    }

    private var dangerZone: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("სახლის წაშლა")
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

    private var houseColor: Color {
        Color.named(house.color)
    }

    private func formatAmount(_ amount: Double) -> String {
        if amount == 0 { return "₾0" }
        return String(format: "₾%.0f", amount)
    }

    private func deleteHouse() {
        modelContext.delete(house)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Summary Item

private struct SummaryItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Utility Row

struct UtilityRow: View {
    let utility: UtilityAccountModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(utilityColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: utility.type.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(utilityColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(utility.provider)
                        .font(.nexusSubheadline)
                        .fontWeight(.medium)

                    Text(utility.customerId)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let days = utility.daysUntilDue {
                        Text(dueText(days: days))
                            .font(.nexusCaption)
                            .foregroundStyle(dueColor(days: days))
                    }

                    if utility.monthlyAverage > 0 {
                        Text("~₾\(String(format: "%.0f", utility.monthlyAverage))")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var utilityColor: Color {
        Color.named(utility.type.color)
    }

    private func dueText(days: Int) -> String {
        if days < 0 { return "ვადაგადაცილებული" }
        if days == 0 { return "დღეს" }
        if days == 1 { return "ხვალ" }
        return "\(days) დღეში"
    }

    private func dueColor(days: Int) -> Color {
        if days < 0 { return .red }
        if days <= 3 { return .orange }
        return .secondary
    }
}

