import SwiftUI

struct ProgressBar: View {
    let progress: Double
    var color: Color?
    var height: CGFloat

    init(
        progress: Double,
        color: Color? = nil,
        height: CGFloat = 6
    ) {
        self.progress = progress
        self.color = color
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.nexusBorder)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(progressColor)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1.0))
            }
        }
        .frame(height: height)
    }

    private var progressColor: Color {
        if let color {
            return color
        }
        if progress >= 1.0 { return .nexusRed }
        if progress >= 0.8 { return .nexusOrange }
        return .nexusGreen
    }
}

#Preview {
    VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Low Progress (30%)")
                .font(.nexusCaption)
            ProgressBar(progress: 0.3)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Medium Progress (75%)")
                .font(.nexusCaption)
            ProgressBar(progress: 0.75)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("High Progress (90%)")
                .font(.nexusCaption)
            ProgressBar(progress: 0.9)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Exceeded (120%)")
                .font(.nexusCaption)
            ProgressBar(progress: 1.2)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Custom Color")
                .font(.nexusCaption)
            ProgressBar(progress: 0.6, color: .nexusPurple, height: 10)
        }
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
