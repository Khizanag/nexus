import SwiftUI

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            legalLayout { policyContent }
        }
        .background(Color.nexusBackground)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension PrivacyPolicyView {
    var policyContent: some View {
        Group {
            legalHeader("Data Collection")
            Text("Nexus collects and stores data locally on your device. Your personal information, notes, tasks, financial data, and health metrics are stored using SwiftData and never leave your device unless you explicitly choose to export or sync them.")

            legalHeader("Health Data")
            Text("When you grant HealthKit access, Nexus can read health metrics from Apple Health to display in the app. This data is used solely for display purposes and is not transmitted to any external servers.")

            legalHeader("Data Security")
            Text("All data is stored locally using iOS's built-in security features. We do not have access to your data, and it is protected by your device's passcode and biometric authentication.")

            legalHeader("Third-Party Services")
            Text("When sync is enabled, data may be transmitted to our secure servers for synchronization across your devices. This data is encrypted in transit and at rest.")

            legalHeader("Your Rights")
            Text("You can export, delete, or clear all your data at any time through the Settings menu. You have full control over your information.")
        }
    }
}

// MARK: - Terms of Service View

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            legalLayout { termsContent }
        }
        .background(Color.nexusBackground)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension TermsOfServiceView {
    var termsContent: some View {
        Group {
            legalHeader("Acceptance of Terms")
            Text("By using Nexus, you agree to these Terms of Service. If you do not agree to these terms, please do not use the application.")

            legalHeader("Use of the App")
            Text("Nexus is designed to help you organize your personal life, including notes, tasks, finances, and health tracking. You are responsible for maintaining the confidentiality of your data and device.")

            legalHeader("User Responsibilities")
            Text("You agree to use Nexus only for lawful purposes and in accordance with these terms. You are solely responsible for the accuracy and legality of any data you enter into the application.")

            legalHeader("Limitation of Liability")
            Text("Nexus is provided \"as is\" without warranties of any kind. We are not liable for any damages arising from your use of the application, including but not limited to data loss or inaccuracies.")

            legalHeader("Changes to Terms")
            Text("We reserve the right to modify these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.")

            legalHeader("Contact")
            Text("For questions about these Terms of Service, please contact us through the app's support channels.")
        }
    }
}

// MARK: - Shared Helpers

private func legalLayout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
        content()
    }
    .font(.nexusBody)
    .foregroundStyle(Color.nexusTextPrimary)
    .frame(maxWidth: 680, alignment: .leading)
    .padding(DesignSystem.Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
}

private func legalHeader(_ title: String) -> some View {
    Text(title)
        .font(.nexusHeadline)
        .padding(.top, DesignSystem.Spacing.xs)
        .accessibilityAddTraits(.isHeader)
}
