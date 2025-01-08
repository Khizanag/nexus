import SwiftUI
import SwiftData
import AuthenticationServices

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthenticationService.self) private var authService

    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("notifications") private var notifications = true
    @AppStorage("currency") private var currency = "USD"

    @State private var showClearDataAlert = false
    @State private var showSignOutAlert = false
    @State private var isSigningIn = false
    @State private var signInError: String?

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
                    Button("Done") { dismiss() }
                }
            }
            .alert("Clear All Data", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) { clearAllData() }
            } message: {
                Text("This will permanently delete all your notes, tasks, transactions, and health entries. This action cannot be undone.")
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) { signOut() }
            } message: {
                Text("Your data will remain on this device but will no longer sync to iCloud.")
            }
        }
    }
}

// MARK: - Account Section

private extension SettingsView {
    var accountSection: some View {
        Section {
            if authService.isSignedIn, let user = authService.currentUser {
                signedInView(user: user)
            } else {
                signedOutView
            }
        } header: {
            Text("Account")
        } footer: {
            if !authService.isSignedIn {
                Text("Sign in to sync your data across all your devices with iCloud.")
                    .font(.nexusCaption)
            }
        }
    }

    func signedInView(user: UserAccount) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.nexusGradient)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Text(user.initials)
                            .font(.nexusTitle)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName).font(.nexusHeadline)
                    if let email = user.email {
                        Text(email).font(.nexusSubheadline).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.icloud.fill").foregroundStyle(Color.nexusGreen)
                        Text("Synced with iCloud").foregroundStyle(Color.nexusGreen)
                    }
                    .font(.nexusCaption)
                }
                Spacer()
            }
            .padding(.vertical, 8)

            Button(role: .destructive) { showSignOutAlert = true } label: {
                HStack {
                    Spacer()
                    Text("Sign Out").font(.nexusSubheadline).fontWeight(.medium)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 10).fill(Color.nexusRed.opacity(0.15))
                }
            }
            .buttonStyle(.plain)
        }
    }

    var signedOutView: some View {
        VStack(spacing: 16) {
            if isSigningIn {
                HStack {
                    Spacer()
                    ProgressView().padding(.vertical, 20)
                    Spacer()
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { _ in }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(10)
                .allowsHitTesting(false)
                .overlay {
                    Button { signInWithApple() } label: { Color.clear }
                }
            }

            if let error = signInError {
                Text(error)
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusRed)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }

    func signInWithApple() {
        guard !isSigningIn else { return }
        isSigningIn = true
        signInError = nil

        Task {
            do {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = scene.windows.first else {
                    throw AuthenticationError.failed
                }
                _ = try await authService.signInWithApple(presentationAnchor: window)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } catch AuthenticationError.canceled {
                // User cancelled
            } catch {
                signInError = error.localizedDescription
            }
            isSigningIn = false
        }
    }

    func signOut() {
        do {
            try authService.signOut()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            signInError = error.localizedDescription
        }
    }
}

// MARK: - Preferences Section

private extension SettingsView {
    var preferencesSection: some View {
        Section("Preferences") {
            Toggle("Haptic Feedback", isOn: $hapticFeedback)
            Toggle("Notifications", isOn: $notifications)

            Picker("Currency", selection: $currency) {
                Text("USD ($)").tag("USD")
                Text("EUR (€)").tag("EUR")
                Text("GBP (£)").tag("GBP")
                Text("JPY (¥)").tag("JPY")
                Text("GEL (₾)").tag("GEL")
            }

            NavigationLink {
                AppearanceSettingsView()
            } label: {
                Label("Appearance", systemImage: "paintbrush")
            }
        }
    }
}

// MARK: - Data Section

private extension SettingsView {
    var dataSection: some View {
        Section("Data") {
            NavigationLink { ExportDataView() } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            NavigationLink { ImportDataView() } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }
            Button(role: .destructive) { showClearDataAlert = true } label: {
                Label("Clear All Data", systemImage: "trash")
            }
        }
    }

    func clearAllData() {
        do {
            try modelContext.delete(model: NoteModel.self)
            try modelContext.delete(model: TaskModel.self)
            try modelContext.delete(model: TransactionModel.self)
            try modelContext.delete(model: HealthEntryModel.self)
            try modelContext.delete(model: TagModel.self)
        } catch {
            print("Failed to clear data: \(error)")
        }
    }
}

// MARK: - About Section

private extension SettingsView {
    var aboutSection: some View {
        Section {
            NavigationLink { PrivacyPolicyView() } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            NavigationLink { TermsOfServiceView() } label: {
                Label("Terms of Service", systemImage: "doc.text")
            }
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0").foregroundStyle(.secondary)
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

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
