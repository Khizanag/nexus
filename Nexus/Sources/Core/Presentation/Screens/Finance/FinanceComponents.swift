import SwiftUI

// MARK: - Time Period

enum TimePeriod: String, CaseIterable, Identifiable {
    case day, week, month, year, range

    var id: String { rawValue }

    var title: String {
        switch self {
        case .range: "Range"
        default: rawValue.capitalized
        }
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: TransactionModel

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            categoryIcon
            titleAndCategory
            Spacer()
            amountAndDate
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color.nexusSurface, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
    }
}

private extension TransactionRow {
    var categoryIcon: some View {
        Image(systemName: transaction.category.icon)
            .font(.system(size: DesignSystem.Size.Icon.sm))
            .foregroundStyle(categoryColor)
            .frame(width: DesignSystem.Size.Button.compact, height: DesignSystem.Size.Button.compact)
            .background(categoryColor.opacity(0.15), in: Circle())
            .accessibilityHidden(true)
    }

    var titleAndCategory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(transaction.title)
                .font(.nexusSubheadline)
            Text(transaction.category.rawValue.capitalized)
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
    }

    var amountAndDate: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formattedAmount)
                .font(.nexusHeadline)
                .foregroundStyle(transaction.type == .income ? Color.nexusGreen : Color.primary)
            Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
    }

    var categoryColor: Color {
        TransactionCategoryColorMapper.color(for: transaction.category.color)
    }

    var formattedAmount: String {
        let prefix = transaction.type == .income ? "+" : "-"
        let formatted = transaction.amount.formatted(.currency(code: transaction.currency))
        return "\(prefix)\(formatted)"
    }
}

// MARK: - Date Range Picker Sheet

struct DateRangePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                datePickersRow
                daysSelectedLabel
                quickSelectGrid
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color.nexusBackground)
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private extension DateRangePickerSheet {
    var datePickersRow: some View {
        HStack {
            startDatePicker
            Spacer()
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            Spacer()
            endDatePicker
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.nexusSurface, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
    }

    var startDatePicker: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Start Date")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
            DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.nexusGreen)
        }
    }

    var endDatePicker: some View {
        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
            Text("End Date")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.nexusGreen)
        }
    }

    var daysSelectedLabel: some View {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return Text("Selected: \(days + 1) days")
            .font(.nexusCaption)
            .foregroundStyle(.secondary)
    }

    var quickSelectGrid: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Quick Select")
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                quickSelectButton("Last 7 Days", days: 7)
                quickSelectButton("Last 14 Days", days: 14)
                quickSelectButton("Last 30 Days", days: 30)
                quickSelectButton("Last 90 Days", days: 90)
            }
        }
    }

    func quickSelectButton(_ title: String, days: Int) -> some View {
        Button {
            endDate = Date()
            startDate = Calendar.current.date(byAdding: .day, value: -(days - 1), to: endDate) ?? endDate
        } label: {
            Text(title)
                .font(.nexusSubheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Select last \(days) days")
    }
}

// MARK: - Color Mapper

enum TransactionCategoryColorMapper {
    static func color(for colorString: String) -> Color {
        switch colorString {
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
