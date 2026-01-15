import SwiftUI

struct NutritionProgressRing: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat
    var icon: String?
    var showLabel: Bool
    var label: String?
    var value: String?

    init(
        progress: Double,
        color: Color,
        lineWidth: CGFloat = 8,
        icon: String? = nil,
        showLabel: Bool = false,
        label: String? = nil,
        value: String? = nil
    ) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.icon = icon
        self.showLabel = showLabel
        self.label = label
        self.value = value
    }

    var body: some View {
        ZStack {
            backgroundCircle
            progressArc
            centerContent
        }
    }
}

// MARK: - Subviews

private extension NutritionProgressRing {
    var backgroundCircle: some View {
        Circle()
            .stroke(Color.nexusBorder, lineWidth: lineWidth)
    }

    var progressArc: some View {
        Circle()
            .trim(from: 0, to: min(progress, 1.0))
            .stroke(
                progressColor,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 0.5), value: progress)
    }

    var centerContent: some View {
        VStack(spacing: 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: lineWidth * 1.5))
                    .foregroundStyle(progressColor)
            }
            if showLabel {
                if let value {
                    Text(value)
                        .font(.nexusHeadline)
                        .foregroundStyle(Color.nexusTextPrimary)
                }
                if let label {
                    Text(label)
                        .font(.nexusCaption)
                        .foregroundStyle(Color.nexusTextSecondary)
                }
            }
        }
    }

    var progressColor: Color {
        if progress >= 1.0 {
            return .nexusRed
        } else if progress >= 0.9 {
            return .nexusOrange
        }
        return color
    }
}

// MARK: - Mini Ring Variant

struct MiniMacroRing: View {
    let current: Double
    let goal: Double
    let color: Color
    let icon: String
    let label: String

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return current / goal
    }

    var body: some View {
        VStack(spacing: 8) {
            NutritionProgressRing(
                progress: progress,
                color: color,
                lineWidth: 5,
                icon: icon
            )
            .frame(width: 50, height: 50)

            VStack(spacing: 2) {
                Text("\(Int(current))")
                    .font(.nexusCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.nexusTextPrimary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.nexusTextSecondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        HStack(spacing: 20) {
            NutritionProgressRing(
                progress: 0.65,
                color: .nexusOrange,
                lineWidth: 12,
                icon: "flame.fill",
                showLabel: true,
                label: "kcal",
                value: "1,450"
            )
            .frame(width: 120, height: 120)

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    MiniMacroRing(
                        current: 180,
                        goal: 250,
                        color: .nexusBlue,
                        icon: "leaf.fill",
                        label: "Carbs"
                    )
                    MiniMacroRing(
                        current: 95,
                        goal: 150,
                        color: .nexusRed,
                        icon: "fish.fill",
                        label: "Protein"
                    )
                    MiniMacroRing(
                        current: 55,
                        goal: 65,
                        color: .nexusPurple,
                        icon: "drop.fill",
                        label: "Fats"
                    )
                }
            }
        }

        HStack(spacing: 20) {
            NutritionProgressRing(progress: 0.3, color: .nexusGreen, lineWidth: 6)
                .frame(width: 40, height: 40)
            NutritionProgressRing(progress: 0.6, color: .nexusBlue, lineWidth: 6)
                .frame(width: 40, height: 40)
            NutritionProgressRing(progress: 0.9, color: .nexusOrange, lineWidth: 6)
                .frame(width: 40, height: 40)
            NutritionProgressRing(progress: 1.2, color: .nexusRed, lineWidth: 6)
                .frame(width: 40, height: 40)
        }
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
