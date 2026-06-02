import SwiftUI
import SwiftData

// MARK: - Export Data View

struct ExportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [NoteModel]
    @Query private var tasks: [TaskModel]
    @Query private var transactions: [TransactionModel]
    @Query private var healthEntries: [HealthEntryModel]

    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var exportError: String?
    @State private var showErrorAlert = false

    private var hasData: Bool {
        notes.count + tasks.count + transactions.count + healthEntries.count > 0
    }

    var body: some View {
        List {
            dataSummarySection
            if hasData {
                exportButtonSection
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if !hasData {
                ContentUnavailableView(
                    "Nothing to Export",
                    systemImage: "tray",
                    description: Text("Add some notes, tasks, transactions, or health entries first.")
                )
            }
        }
        .alert("Export Failed", isPresented: $showErrorAlert, presenting: exportError) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error)
        }
    }
}

// MARK: - Export Data View — Sections

private extension ExportDataView {
    var dataSummarySection: some View {
        Section("Data Summary") {
            dataRow("Notes", count: notes.count, systemImage: "note.text")
            dataRow("Tasks", count: tasks.count, systemImage: "checkmark.circle")
            dataRow("Transactions", count: transactions.count, systemImage: "creditcard")
            dataRow("Health Entries", count: healthEntries.count, systemImage: "heart")
        }
    }

    func dataRow(_ label: String, count: Int, systemImage: String) -> some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(count)")
    }

    var exportButtonSection: some View {
        Section {
            Group {
                if isExporting {
                    HStack {
                        Spacer()
                        ProgressView("Exporting…")
                        Spacer()
                    }
                    .accessibilityLabel("Exporting data")
                } else if let url = exportedURL {
                    ShareLink(item: url) {
                        Label("Share Export File", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel("Share exported file")
                } else {
                    Button { buildExport() } label: {
                        Label("Export as JSON", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel("Export data as JSON")
                }
            }
        } footer: {
            Text("Exports all your data to a JSON file you can save or share.")
        }
    }

    func buildExport() {
        isExporting = true
        exportError = nil
        exportedURL = nil

        let snapshot = ExportableData(
            notes: notes.map { ExportableNote(from: $0) },
            tasks: tasks.map { ExportableTask(from: $0) },
            transactions: transactions.map { ExportableTransaction(from: $0) },
            healthEntries: healthEntries.map { ExportableHealthEntry(from: $0) },
            exportDate: Date()
        )

        Task.detached(priority: .userInitiated) {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(snapshot)

                let fileName = "nexus_export_\(Date().formatted(.dateTime.year().month().day())).json"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try jsonData.write(to: tempURL)

                await MainActor.run {
                    exportedURL = tempURL
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = "Export failed: \(error.localizedDescription)"
                    showErrorAlert = true
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - Import Data View

struct ImportDataView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var successMessage = ""
    @State private var importError = ""

    var body: some View {
        List {
            Section {
                Text("Import data from a previously exported Nexus JSON file. Existing data will be preserved.")
                    .font(.nexusSubheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button { showFilePicker = true } label: {
                    HStack {
                        Spacer()
                        if isImporting {
                            ProgressView("Importing…")
                        } else {
                            Label("Choose File", systemImage: "doc.badge.plus")
                        }
                        Spacer()
                    }
                }
                .disabled(isImporting)
                .accessibilityLabel(isImporting ? "Importing data" : "Choose a file to import")
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
                if let url = urls.first { importData(from: url) }
            case .failure(let error):
                importError = error.localizedDescription
                showErrorAlert = true
            }
        }
        .alert("Import Successful", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .alert("Import Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError)
        }
    }
}

// MARK: - Import Data View — Logic

private extension ImportDataView {
    func importData(from url: URL) {
        isImporting = true

        Task.detached(priority: .userInitiated) {
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    throw ImportError.accessDenied
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)

                guard !data.isEmpty else { throw ImportError.emptyFile }

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let imported = try decoder.decode(ExportableData.self, from: data)

                // Validate at the boundary
                guard
                    imported.notes.allSatisfy({ !$0.title.isEmpty }),
                    imported.tasks.allSatisfy({ !$0.title.isEmpty })
                else {
                    throw ImportError.invalidData
                }

                var counts = (notes: 0, tasks: 0, transactions: 0, health: 0)

                await MainActor.run {
                    for note in imported.notes {
                        let newNote = NoteModel(title: note.title, content: note.content)
                        newNote.createdAt = note.createdAt
                        newNote.updatedAt = note.updatedAt
                        newNote.isPinned = note.isPinned
                        modelContext.insert(newNote)
                        counts.notes += 1
                    }

                    for task in imported.tasks {
                        let newTask = TaskModel(title: task.title)
                        newTask.notes = task.notes
                        newTask.dueDate = task.dueDate
                        newTask.priority = TaskPriority(rawValue: task.priority) ?? .medium
                        newTask.isCompleted = task.isCompleted
                        newTask.completedAt = task.completedAt
                        modelContext.insert(newTask)
                        counts.tasks += 1
                    }

                    for transaction in imported.transactions {
                        let newTransaction = TransactionModel(
                            amount: transaction.amount,
                            title: transaction.title,
                            notes: transaction.notes,
                            category: TransactionCategory(rawValue: transaction.category) ?? .other,
                            type: TransactionType(rawValue: transaction.type) ?? .expense,
                            date: transaction.date
                        )
                        modelContext.insert(newTransaction)
                        counts.transactions += 1
                    }

                    for entry in imported.healthEntries {
                        let newEntry = HealthEntryModel(
                            type: HealthMetricType(rawValue: entry.type) ?? .steps,
                            value: entry.value,
                            unit: entry.unit
                        )
                        newEntry.date = entry.date
                        newEntry.notes = entry.notes
                        modelContext.insert(newEntry)
                        counts.health += 1
                    }

                    try? modelContext.save()
                }

                let message = "Imported \(counts.notes) notes, \(counts.tasks) tasks, \(counts.transactions) transactions, and \(counts.health) health entries."

                await MainActor.run {
                    successMessage = message
                    showSuccessAlert = true
                    isImporting = false
                }
            } catch {
                let message: String
                if let importErr = error as? ImportError {
                    message = importErr.localizedDescription
                } else {
                    message = "Import failed: \(error.localizedDescription)"
                }
                await MainActor.run {
                    importError = message
                    showErrorAlert = true
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Import Error

private enum ImportError: LocalizedError {
    case accessDenied
    case emptyFile
    case invalidData

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Cannot access the selected file."
        case .emptyFile: "The selected file is empty."
        case .invalidData: "The file contains invalid or incomplete data."
        }
    }
}

// MARK: - Export/Import Models

struct ExportableData: Codable {
    let notes: [ExportableNote]
    let tasks: [ExportableTask]
    let transactions: [ExportableTransaction]
    let healthEntries: [ExportableHealthEntry]
    let exportDate: Date
}

struct ExportableNote: Codable {
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

struct ExportableTask: Codable {
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

struct ExportableTransaction: Codable {
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

struct ExportableHealthEntry: Codable {
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
