import SwiftUI
import Charts

// MARK: - Budget List Row

struct BudgetListRow: View {
    let budget: BudgetModel
    let spent: Double
    let status: BudgetStatus
    let currency: String

    private var progress: Double {
        guard budget.effectiveBudget > 0 else { return 0 }
        return min(spent / budget.effectiveBudget, 1)
    }

    private var remaining: Double {
        max(budget.effectiveBudget - spent, 0)
    }

    private var categoryColor: Color {
        TransactionCategoryColorMapper.color(for: budget.category.color)
    }

    private var statusColor: Color {
        switch status {
        case .onTrack: .nexusGreen
        case .warning: .nexusOrange
        case .exceeded: .nexusRed
        case .completed: .nexusBlue
        }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            headerRow
            progressBar
            footerRow
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Private Views

private extension BudgetListRow {
    var headerRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: budget.category.icon)
                .font(.nexusSubheadline)
                .foregroundStyle(.white)
                .frame(width: DesignSystem.Size.Button.compact, height: DesignSystem.Size.Button.compact)
                .background(categoryColor, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(budget.name)
                    .font(.nexusHeadline)
                Text(budget.period.displayName)
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge
        }
    }

    var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.nexusCaption2)
            Text(status.message)
                .font(.nexusCaption2)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .background(statusColor.opacity(0.12), in: Capsule())
    }

    var progressBar: some View {
        ProgressView(value: progress)
            .tint(statusColor)
            .accessibilityHidden(true)
    }

    var footerRow: some View {
        HStack {
            Text(spent.formatted(.currency(code: currency).precision(.fractionLength(0))))
                .font(.nexusCaption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(budget.effectiveBudget.formatted(.currency(code: currency).precision(.fractionLength(0))))
                .font(.nexusCaption)
                .foregroundStyle(.secondary)
        }
    }

    var accessibilityDescription: String {
        "\(budget.name), \(status.message), spent \(spent.formatted(.currency(code: currency))) of \(budget.effectiveBudget.formatted(.currency(code: currency)))"
    }
}

// MARK: - Budget Progress Gauge

struct BudgetProgressGauge: View {
    let progress: Double
    let currency: String
    let spent: Double
    let total: Double
    var size: CGFloat = 80

    private var gaugeColor: Color {
        if progress >= 1.0 { return .nexusRed }
        if progress >= 0.8 { return .nexusOrange }
        return .nexusGreen
    }

    var body: some View {
        Gauge(value: min(progress, 1)) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: 1) {
                Text("\(Int(min(progress, 1) * 100))")
                    .font(.nexusDisplayNumber(.footnote))
                Text("%")
                    .font(.nexusCaption2)
                    .foregroundStyle(.secondary)
            }
        }
        .gaugeStyle(.accessoryCircular)
        .tint(gaugeColor)
        .frame(width: size, height: size)
        .accessibilityLabel("Budget used \(Int(progress * 100)) percent. Spent \(spent.formatted(.currency(code: currency))) of \(total.formatted(.currency(code: currency)))")
    }
}
