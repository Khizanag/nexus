import SwiftUI

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.nexusLargeTitle)

                Text("Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                policyContent
            }
            .padding(20)
        }
        .background(Color.nexusBackground)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension PrivacyPolicyView {
    var policyContent: some View {
        Group {
            sectionHeader("Data Collection")
            Text("Nexus collects and stores data locally on your device. Your personal information, notes, tasks, financial data, and health metrics are stored using SwiftData and never leave your device unless you explicitly choose to export or sync them.")

            sectionHeader("Health Data")
            Text("When you grant HealthKit access, Nexus can read health metrics from Apple Health to display in the app. This data is used solely for display purposes and is not transmitted to any external servers.")

            sectionHeader("Data Security")
            Text("All data is stored locally using iOS's built-in security features. We do not have access to your data, and it is protected by your device's passcode and biometric authentication.")

            sectionHeader("Third-Party Services")
            Text("When sync is enabled, data may be transmitted to our secure servers for synchronization across your devices. This data is encrypted in transit and at rest.")

            sectionHeader("Your Rights")
            Text("You can export, delete, or clear all your data at any time through the Settings menu. You have full control over your information.")
        }
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.nexusHeadline)
            .padding(.top, 8)
    }
}

// MARK: - Terms of Service View

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Service")
                    .font(.nexusLargeTitle)

                Text("Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

                termsContent
            }
            .padding(20)
        }
        .background(Color.nexusBackground)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension TermsOfServiceView {
    var termsContent: some View {
        Group {
            sectionHeader("Acceptance of Terms")
            Text("By using Nexus, you agree to these Terms of Service. If you do not agree to these terms, please do not use the application.")

            sectionHeader("Use of the App")
            Text("Nexus is designed to help you organize your personal life, including notes, tasks, finances, and health tracking. You are responsible for maintaining the confidentiality of your data and device.")

            sectionHeader("User Responsibilities")
            Text("You agree to use Nexus only for lawful purposes and in accordance with these terms. You are solely responsible for the accuracy and legality of any data you enter into the application.")

            sectionHeader("Limitation of Liability")
            Text("Nexus is provided \"as is\" without warranties of any kind. We are not liable for any damages arising from your use of the application, including but not limited to data loss or inaccuracies.")

            sectionHeader("Changes to Terms")
            Text("We reserve the right to modify these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.")

            sectionHeader("Contact")
            Text("For questions about these Terms of Service, please contact us through the app's support channels.")
        }
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.nexusHeadline)
            .padding(.top, 8)
    }
}
