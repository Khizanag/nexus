import SwiftUI

// MARK: - Today Metric Card

struct TodayMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var isFromHealthKit: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                if isFromHealthKit {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.nexusRed)
                        .offset(x: 8, y: -4)
                }
            }

            Text(value)
                .font(.nexusHeadline)

            Text(title)
                .font(.nexusCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let metric: HealthMetricType
    let latestValue: Double?
    var isFromHealthKit: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(metricColor)

                    if isFromHealthKit {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.nexusRed)
                            .offset(x: 6, y: -4)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
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
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }
}

private extension MetricCard {
    var metricColor: Color {
        HealthMetricColorMapper.color(for: metric.color)
    }

    func formattedValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

// MARK: - Health Entry Row

struct HealthEntryRow: View {
    let entry: HealthEntryModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.type.icon)
                .font(.system(size: 16))
                .foregroundStyle(metricColor)
                .frame(width: 36, height: 36)
                .background {
                    Circle().fill(metricColor.opacity(0.15))
                }

            VStack(alignment: .leading, spacing: 2) {
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
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.nexusSurface)
        }
    }
}

private extension HealthEntryRow {
    var metricColor: Color {
        HealthMetricColorMapper.color(for: entry.type.color)
    }

    func formattedValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)
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
