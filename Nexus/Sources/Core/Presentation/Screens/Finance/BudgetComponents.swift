import SwiftUI

// MARK: - Budget Card

struct BudgetCard: View {
    let budget: BudgetModel
    let spent: Double
    let status: BudgetStatus
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                headerRow
                progressSection
                statsRow
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [categoryColor.opacity(0.5), categoryColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit Budget", systemImage: "pencil")
            }

            Button(role: .destructive) { onDelete() } label: {
                Label("Delete Budget", systemImage: "trash")
            }
        }
    }
}

// MARK: - Private Views

private extension BudgetCard {
    var headerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: budget.category.icon)
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background {
                    Circle().fill(categoryColor)
                }

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
                .font(.system(size: 10))

            Text(status.message)
                .font(.nexusCaption2)
        }
        .foregroundStyle(progressColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(progressColor.opacity(0.15))
        }
    }

    var progressSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.nexusBorder)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [categoryColor, categoryColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 12)

            HStack {
                Text(formatCurrency(spent))
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatCurrency(budget.effectiveBudget))
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var statsRow: some View {
        HStack {
            statItem(title: "Remaining", value: formatCurrency(remaining), valueColor: remaining > 0 ? .primary : .nexusRed)
            Spacer()
            statItem(title: "Daily Budget", value: formatCurrency(remaining / Double(max(budget.daysRemaining, 1))), valueColor: .secondary)
            Spacer()
            statItem(title: "Days Left", value: "\(budget.daysRemaining)", valueColor: .secondary)
        }
    }

    func statItem(title: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.nexusCaption2)
                .foregroundStyle(.tertiary)

            Text(value)
                .font(.nexusSubheadline)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Computed Properties

private extension BudgetCard {
    var progress: Double {
        min(spent / budget.effectiveBudget, 1.0)
    }

    var remaining: Double {
        max(budget.effectiveBudget - spent, 0)
    }

    var progressColor: Color {
        switch status {
        case .onTrack: .nexusGreen
        case .warning: .nexusOrange
        case .exceeded: .nexusRed
        case .completed: .nexusBlue
        }
    }

    var categoryColor: Color {
        TransactionCategoryColorMapper.color(for: budget.category.color)
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = budget.currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Budget Progress Ring

struct BudgetProgressRing: View {
    let progress: Double
    var size: CGFloat = 60
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: progress)

            VStack(spacing: 0) {
                Text("\(Int(clampedProgress * 100))")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("%")
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Private Helpers

private extension BudgetProgressRing {
    var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var progressColor: Color {
        if progress >= 1.0 { return .nexusRed }
        if progress >= 0.8 { return .nexusOrange }
        return .nexusGreen
    }
}
