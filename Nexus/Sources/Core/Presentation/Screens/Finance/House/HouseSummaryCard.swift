import SwiftUI
import SwiftData

struct HouseSummaryCard: View {
    @Query(sort: \HouseModel.createdAt, order: .reverse) private var houses: [HouseModel]

    @State private var showHouseView = false

    private var primaryHouse: HouseModel? {
        houses.first { $0.isPrimary } ?? houses.first
    }

    private var allUtilities: [UtilityAccountModel] {
        houses.flatMap { $0.activeUtilities }
    }

    private var totalMonthly: Double {
        houses.reduce(0) { $0 + $1.totalMonthlyEstimate }
    }

    private var totalPending: Int {
        houses.reduce(0) { $0 + $1.pendingPaymentsCount }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if !houses.isEmpty {
                Divider().background(Color.nexusBorder)
                contentView
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
        .onTapGesture {
            showHouseView = true
        }
        .sheet(isPresented: $showHouseView) {
            HouseView()
        }
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.nexusOrange.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "house.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.nexusOrange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("House & Services")
                        .font(.nexusHeadline)

                    if !houses.isEmpty {
                        HStack(spacing: 8) {
                            Text("^[\(houses.count) house](inflect: true)")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)

                            Text("•")
                                .foregroundStyle(.tertiary)

                            Text("^[\(allUtilities.count) service](inflect: true)")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
    }

    @ViewBuilder
    private var contentView: some View {
        if houses.isEmpty {
            emptyState
        } else {
            servicesOverview
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Store house and services information")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)

            Text("Tap to add")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
    }

    private var servicesOverview: some View {
        VStack(spacing: 10) {
            if !allUtilities.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(Set(allUtilities.map { $0.type })).prefix(6), id: \.self) { type in
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.named(type.color))

                            Text(type.displayName)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                HStack {
                    Text("No services added")
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }

            if totalMonthly > 0 || totalPending > 0 {
                Divider().background(Color.nexusBorder)

                HStack {
                    if totalMonthly > 0 {
                        HStack(spacing: 4) {
                            Text("Monthly:")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                            Text(formatAmount(totalMonthly))
                                .font(.nexusCaption)
                                .fontWeight(.semibold)
                        }
                    }

                    Spacer()

                    if totalPending > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text("^[\(totalPending) pending](inflect: true)")
                                .font(.nexusCaption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
    }

    private func formatAmount(_ amount: Double) -> String {
        if amount == 0 { return "₾0" }
        return String(format: "₾%.0f", amount)
    }
}

