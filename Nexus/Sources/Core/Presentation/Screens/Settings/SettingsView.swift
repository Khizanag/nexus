import SwiftUI
import SwiftData
import AuthenticationServices
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(DefaultAuthenticationService.self) private var authService

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
                        .accessibilityLabel("Dismiss Settings")
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
                    .accessibilityHidden(true)

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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Signed in as \(user.displayName)")

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
            .accessibilityLabel("Sign out of \(user.displayName)")
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
                .accessibilityLabel("Signing in")
            } else {
                // The button shows Apple's native styling, but taps route to the auth
                // service's own ASAuthorizationController so there is a single sign-in flow.
                Button { signInWithApple() } label: {
                    SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(10)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sign in with Apple")
                .accessibilityAddTraits(.isButton)
            }

            if let error = signInError {
                Text(error)
                    .font(.nexusCaption)
                    .foregroundStyle(Color.nexusRed)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Sign in error: \(error)")
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
                if hapticFeedback {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } catch AuthenticationError.canceled {
                // User cancelled — silent
            } catch {
                signInError = error.localizedDescription
            }
            isSigningIn = false
        }
    }

    func signOut() {
        do {
            try authService.signOut()
            if hapticFeedback {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
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
                .accessibilityLabel("Haptic Feedback")
                .accessibilityValue(hapticFeedback ? "On" : "Off")

            Toggle("Notifications", isOn: $notifications)
                .accessibilityLabel("Notifications")
                .accessibilityValue(notifications ? "On" : "Off")
                .onChange(of: notifications) { _, newValue in
                    handleNotificationsToggle(newValue)
                }

            Picker("Currency", selection: $currency) {
                Text("USD ($)").tag("USD")
                Text("EUR (€)").tag("EUR")
                Text("GBP (£)").tag("GBP")
                Text("JPY (¥)").tag("JPY")
                Text("GEL (₾)").tag("GEL")
            }
            .accessibilityLabel("Currency")

            NavigationLink {
                AppearanceSettingsView()
            } label: {
                Label("Appearance", systemImage: "paintbrush")
            }
            .accessibilityLabel("Appearance settings")
        }
    }

    func handleNotificationsToggle(_ enabled: Bool) {
        guard enabled else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                if !granted {
                    await MainActor.run { notifications = false }
                }
            case .denied:
                // System denied — reflect reality
                await MainActor.run { notifications = false }
            default:
                break
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
            .accessibilityLabel("Export Data")

            NavigationLink { ImportDataView() } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }
            .accessibilityLabel("Import Data")

            Button(role: .destructive) { showClearDataAlert = true } label: {
                Label("Clear All Data", systemImage: "trash")
            }
            .accessibilityLabel("Clear all data")
        }
    }

    func clearAllData() {
        do {
            try modelContext.delete(model: NoteModel.self)
            try modelContext.delete(model: TaskModel.self)
            try modelContext.delete(model: TransactionModel.self)
            try modelContext.delete(model: HealthEntryModel.self)
            try modelContext.delete(model: TagModel.self)
            if hapticFeedback {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
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
            .accessibilityLabel("Privacy Policy")

            NavigationLink { TermsOfServiceView() } label: {
                Label("Terms of Service", systemImage: "doc.text")
            }
            .accessibilityLabel("Terms of Service")

            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0").foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Version 1.0.0")
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
}
