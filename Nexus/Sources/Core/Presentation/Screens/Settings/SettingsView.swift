import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("notifications") private var notifications = true
    @AppStorage("syncEnabled") private var syncEnabled = false
    @AppStorage("currency") private var currency = "USD"

    var body: some View {
        NavigationStack {
            List {
                accountSection
                preferencesSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.nexusBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var accountSection: some View {
        Section {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.nexusGradient)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Text("N")
                            .font(.nexusTitle)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Nexus User")
                        .font(.nexusHeadline)

                    Text("Free Plan")
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Account")
        }
    }

    private var preferencesSection: some View {
        Section {
            Toggle("Haptic Feedback", isOn: $hapticFeedback)

            Toggle("Notifications", isOn: $notifications)

            Picker("Currency", selection: $currency) {
                Text("USD ($)").tag("USD")
                Text("EUR (€)").tag("EUR")
                Text("GBP (£)").tag("GBP")
                Text("JPY (¥)").tag("JPY")
            }

            NavigationLink {
                AppearanceSettingsView()
            } label: {
                Label("Appearance", systemImage: "paintbrush")
            }
        } header: {
            Text("Preferences")
        }
    }

    private var dataSection: some View {
        Section {
            Toggle("Sync Enabled", isOn: $syncEnabled)

            NavigationLink {
                Text("Export Data")
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }

            NavigationLink {
                Text("Import Data")
            } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }
        } header: {
            Text("Data")
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink {
                Text("Privacy Policy")
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            NavigationLink {
                Text("Terms of Service")
            } label: {
                Label("Terms of Service", systemImage: "doc.text")
            }

            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        } footer: {
            Text("Made with love")
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
    }
}

// MARK: - Appearance Settings

private struct AppearanceSettingsView: View {
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
            Section {
                ForEach(colorOptions, id: \.name) { option in
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
            } header: {
                Text("Accent Color")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
