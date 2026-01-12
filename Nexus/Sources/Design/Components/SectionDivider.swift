import SwiftUI

struct SectionDivider: View {
    var extendToEdges: Bool
    var opacity: Double

    init(extendToEdges: Bool = true, opacity: Double = 0.5) {
        self.extendToEdges = extendToEdges
        self.opacity = opacity
    }

    var body: some View {
        Rectangle()
            .fill(Color.nexusBorder.opacity(opacity))
            .frame(height: 1)
            .padding(.horizontal, extendToEdges ? -20 : 0)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Section 1")
            .font(.nexusHeadline)

        SectionDivider()

        Text("Section 2")
            .font(.nexusHeadline)

        SectionDivider(extendToEdges: false)

        Text("Section 3")
            .font(.nexusHeadline)
    }
    .padding()
    .background(Color.nexusBackground)
    .preferredColorScheme(.dark)
}
