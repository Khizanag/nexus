import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @AppStorage("accentColor") private var accentColor: String = AccentPalette.purple.rawValue

    // MARK: - Body

    var body: some View {
        List {
            themeSection
            accentSection
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Theme

private extension AppearanceSettingsView {
    var themeSection: some View {
        Section {
            Picker("Theme", selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Label(option.label, systemImage: option.symbol)
                        .tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Theme")
        } footer: {
            Text("System follows your device's Light or Dark setting.")
        }
    }
}

// MARK: - Accent

private extension AppearanceSettingsView {
    var accentSection: some View {
        Section("Accent Color") {
            ForEach(AccentPalette.allCases) { option in
                accentRow(option)
            }
        }
    }

    func accentRow(_ option: AccentPalette) -> some View {
        Button {
            accentColor = option.rawValue
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(option.color)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    }

                Text(option.label)
                    .foregroundStyle(.primary)

                Spacer()

                if accentColor == option.rawValue {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
        }
        .accessibilityLabel(option.label)
        .accessibilityValue(accentColor == option.rawValue ? "Selected" : "")
        .accessibilityAddTraits(accentColor == option.rawValue ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
