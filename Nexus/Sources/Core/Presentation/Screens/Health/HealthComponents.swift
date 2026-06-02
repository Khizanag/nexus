import SwiftUI

// MARK: - Today Metric Card

struct TodayMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var isFromHealthKit: Bool = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.nexusTitle2)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)

                if isFromHealthKit {
                    Image(systemName: "heart.fill")
                        .font(.nexusCaption2)
                        .foregroundStyle(Color.nexusRed)
                        .offset(x: 8, y: -4)
                        .accessibilityHidden(true)
                }
            }

            Text(value)
                .font(.nexusHeadline)

            Text(title)
                .font(.nexusCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
        .glassBackground(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let metric: HealthMetricType
    let latestValue: Double?
    var isFromHealthKit: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: metric.icon)
                        .font(.nexusTitle3)
                        .foregroundStyle(metricColor)
                        .accessibilityHidden(true)

                    if isFromHealthKit {
                        Image(systemName: "heart.fill")
                            .font(.nexusCaption2)
                            .foregroundStyle(Color.nexusRed)
                            .offset(x: 6, y: -4)
                            .accessibilityHidden(true)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(metric.displayName)
                    .font(.nexusSubheadline)

                if let value = latestValue {
                    Text("\(formattedValue(value)) \(metric.defaultUnit)")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No data")
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .glassBackground(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private extension MetricCard {
    var metricColor: Color {
        HealthMetricColorMapper.color(for: metric.color)
    }

    func formattedValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - Health Entry Row

struct HealthEntryRow: View {
    let entry: HealthEntryModel

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: entry.type.icon)
                .font(.nexusSubheadline)
                .foregroundStyle(metricColor)
                .frame(width: 36, height: 36)
                .background(metricColor.opacity(0.15), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(entry.type.displayName)
                    .font(.nexusSubheadline)

                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(formattedValue(entry.value)) \(entry.unit)")
                .font(.nexusHeadline)
                .foregroundStyle(metricColor)
        }
        .padding(DesignSystem.Spacing.sm)
        .glassBackground(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.type.displayName)
        .accessibilityValue("\(formattedValue(entry.value)) \(entry.unit), \(entry.date.formatted(date: .abbreviated, time: .shortened))")
    }
}

private extension HealthEntryRow {
    var metricColor: Color {
        HealthMetricColorMapper.color(for: entry.type.color)
    }

    func formattedValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - Color Mapper

enum HealthMetricColorMapper {
    static func color(for colorString: String) -> Color {
        switch colorString {
        case "purple": .nexusPurple
        case "blue": .nexusBlue
        case "indigo": .indigo
        case "green": .nexusGreen
        case "orange": .nexusOrange
        case "red": .nexusRed
        case "pink": .nexusPink
        case "yellow": .yellow
        case "teal": .nexusTeal
        default: .secondary
        }
    }
}
