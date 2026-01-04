import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("notifications") private var notifications = true
    @AppStorage("syncEnabled") private var syncEnabled = false
    @AppStorage("currency") private var currency = "USD"

    @State private var showClearDataAlert = false
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false

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
            .alert("Clear All Data", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all your notes, tasks, transactions, and health entries. This action cannot be undone.")
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
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
                ExportDataView()
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }

            NavigationLink {
                ImportDataView()
            } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
            }

            Button(role: .destructive) {
                showClearDataAlert = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }
        } header: {
            Text("Data")
        }
    }

    private func clearAllData() {
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

    private var aboutSection: some View {
        Section {
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            NavigationLink {
                TermsOfServiceView()
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

// MARK: - Export Data View

private struct ExportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [NoteModel]
    @Query private var tasks: [TaskModel]
    @Query private var transactions: [TransactionModel]
    @Query private var healthEntries: [HealthEntryModel]

    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var showShareSheet = false
    @State private var exportError: String?

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Notes")
                    Spacer()
                    Text("\(notes.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Tasks")
                    Spacer()
                    Text("\(tasks.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Transactions")
                    Spacer()
                    Text("\(transactions.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Health Entries")
                    Spacer()
                    Text("\(healthEntries.count)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Data Summary")
            }

            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Spacer()
                        if isExporting {
                            ProgressView()
                        } else {
                            Label("Export as JSON", systemImage: "square.and.arrow.up")
                        }
                        Spacer()
                    }
                }
                .disabled(isExporting)
            }

            if let error = exportError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportData() {
        isExporting = true
        exportError = nil

        Task {
            do {
                let exportData = ExportableData(
                    notes: notes.map { ExportableNote(from: $0) },
                    tasks: tasks.map { ExportableTask(from: $0) },
                    transactions: transactions.map { ExportableTransaction(from: $0) },
                    healthEntries: healthEntries.map { ExportableHealthEntry(from: $0) },
                    exportDate: Date()
                )

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(exportData)

                let fileName = "nexus_export_\(Date().formatted(.dateTime.year().month().day())).json"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try jsonData.write(to: tempURL)

                await MainActor.run {
                    exportedURL = tempURL
                    showShareSheet = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = "Export failed: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - Import Data View

private struct ImportDataView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showFilePicker = false
    @State private var importResult: ImportResult?
    @State private var isImporting = false

    var body: some View {
        List {
            Section {
                Text("Import data from a previously exported Nexus JSON file. Existing data will be preserved.")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    showFilePicker = true
                } label: {
                    HStack {
                        Spacer()
                        if isImporting {
                            ProgressView()
                        } else {
                            Label("Choose File", systemImage: "doc.badge.plus")
                        }
                        Spacer()
                    }
                }
                .disabled(isImporting)
            }

            if let result = importResult {
                Section {
                    if result.success {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Import Successful", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)

                            Text("Imported: \(result.notesCount) notes, \(result.tasksCount) tasks, \(result.transactionsCount) transactions, \(result.healthEntriesCount) health entries")
                                .font(.nexusCaption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label(result.error ?? "Import failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importData(from: url)
                }
            case .failure(let error):
                importResult = ImportResult(success: false, error: error.localizedDescription)
            }
        }
    }

    private func importData(from url: URL) {
        isImporting = true
        importResult = nil

        Task {
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "Nexus", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access file"])
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let importedData = try decoder.decode(ExportableData.self, from: data)

                var notesCount = 0
                var tasksCount = 0
                var transactionsCount = 0
                var healthEntriesCount = 0

                for note in importedData.notes {
                    let newNote = NoteModel(title: note.title, content: note.content)
                    newNote.createdAt = note.createdAt
                    newNote.updatedAt = note.updatedAt
                    newNote.isPinned = note.isPinned
                    modelContext.insert(newNote)
                    notesCount += 1
                }

                for task in importedData.tasks {
                    let newTask = TaskModel(title: task.title)
                    newTask.notes = task.notes
                    newTask.dueDate = task.dueDate
                    newTask.priority = TaskPriority(rawValue: task.priority) ?? .medium
                    newTask.isCompleted = task.isCompleted
                    newTask.completedAt = task.completedAt
                    modelContext.insert(newTask)
                    tasksCount += 1
                }

                for transaction in importedData.transactions {
                    let newTransaction = TransactionModel(
                        amount: transaction.amount,
                        title: transaction.title,
                        notes: transaction.notes,
                        category: TransactionCategory(rawValue: transaction.category) ?? .other,
                        type: TransactionType(rawValue: transaction.type) ?? .expense,
                        date: transaction.date
                    )
                    modelContext.insert(newTransaction)
                    transactionsCount += 1
                }

                for entry in importedData.healthEntries {
                    let newEntry = HealthEntryModel(
                        type: HealthMetricType(rawValue: entry.type) ?? .steps,
                        value: entry.value,
                        unit: entry.unit
                    )
                    newEntry.date = entry.date
                    newEntry.notes = entry.notes
                    modelContext.insert(newEntry)
                    healthEntriesCount += 1
                }

                try modelContext.save()

                await MainActor.run {
                    importResult = ImportResult(
                        success: true,
                        notesCount: notesCount,
                        tasksCount: tasksCount,
                        transactionsCount: transactionsCount,
                        healthEntriesCount: healthEntriesCount
                    )
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    importResult = ImportResult(success: false, error: error.localizedDescription)
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Privacy Policy View

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.nexusLargeTitle)

                Text("Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

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
            .padding(20)
        }
        .background(Color.nexusBackground)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.nexusHeadline)
            .padding(.top, 8)
    }
}

// MARK: - Terms of Service View

private struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Service")
                    .font(.nexusLargeTitle)

                Text("Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                    .font(.nexusCaption)
                    .foregroundStyle(.secondary)

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
            .padding(20)
        }
        .background(Color.nexusBackground)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.nexusHeadline)
            .padding(.top, 8)
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Export/Import Models

private struct ExportableData: Codable {
    let notes: [ExportableNote]
    let tasks: [ExportableTask]
    let transactions: [ExportableTransaction]
    let healthEntries: [ExportableHealthEntry]
    let exportDate: Date
}

private struct ExportableNote: Codable {
    let title: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let isPinned: Bool

    init(from model: NoteModel) {
        self.title = model.title
        self.content = model.content
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
        self.isPinned = model.isPinned
    }
}

private struct ExportableTask: Codable {
    let title: String
    let notes: String
    let dueDate: Date?
    let priority: String
    let isCompleted: Bool
    let completedAt: Date?
    let createdAt: Date

    init(from model: TaskModel) {
        self.title = model.title
        self.notes = model.notes
        self.dueDate = model.dueDate
        self.priority = model.priority.rawValue
        self.isCompleted = model.isCompleted
        self.completedAt = model.completedAt
        self.createdAt = model.createdAt
    }
}

private struct ExportableTransaction: Codable {
    let amount: Double
    let type: String
    let category: String
    let title: String
    let notes: String
    let date: Date

    init(from model: TransactionModel) {
        self.amount = model.amount
        self.type = model.type.rawValue
        self.category = model.category.rawValue
        self.title = model.title
        self.notes = model.notes
        self.date = model.date
    }
}

private struct ExportableHealthEntry: Codable {
    let type: String
    let value: Double
    let unit: String
    let date: Date
    let notes: String

    init(from model: HealthEntryModel) {
        self.type = model.type.rawValue
        self.value = model.value
        self.unit = model.unit
        self.date = model.date
        self.notes = model.notes
    }
}

private struct ImportResult {
    let success: Bool
    var error: String?
    var notesCount: Int = 0
    var tasksCount: Int = 0
    var transactionsCount: Int = 0
    var healthEntriesCount: Int = 0
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
