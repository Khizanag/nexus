import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("accentColor") private var accentColor = "purple"

    private let colorOptions: [(name: String, color: Color)] = [
        ("purple", .nexusPurple),
        ("blue", .nexusBlue),
        ("green", .nexusGreen),
        ("orange", .nexusOrange),
        ("pink", .nexusPink),
        ("teal", .nexusTeal)
    ]

    var body: some View {
        List {
            Section("Accent Color") {
                ForEach(colorOptions, id: \.name) { option in
                    colorRow(option)
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension AppearanceSettingsView {
    func colorRow(_ option: (name: String, color: Color)) -> some View {
        HStack {
            Circle()
                .fill(option.color)
                .frame(width: 24, height: 24)

            Text(option.name.capitalized)

            Spacer()

            if accentColor == option.name {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.nexusPurple)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            accentColor = option.name
        }
    }
}
