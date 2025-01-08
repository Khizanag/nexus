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
    @State private var showShareSheet = false
    @State private var exportError: String?

    var body: some View {
        List {
            dataSummarySection
            exportButtonSection
            if let error = exportError {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL { ShareSheet(items: [url]) }
        }
    }
}

private extension ExportDataView {
    var dataSummarySection: some View {
        Section("Data Summary") {
            dataRow("Notes", count: notes.count)
            dataRow("Tasks", count: tasks.count)
            dataRow("Transactions", count: transactions.count)
            dataRow("Health Entries", count: healthEntries.count)
        }
    }

    func dataRow(_ label: String, count: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(count)").foregroundStyle(.secondary)
        }
    }

    var exportButtonSection: some View {
        Section {
            Button { exportData() } label: {
                HStack {
                    Spacer()
                    if isExporting { ProgressView() }
                    else { Label("Export as JSON", systemImage: "square.and.arrow.up") }
                    Spacer()
                }
            }
            .disabled(isExporting)
        }
    }

    func exportData() {
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

struct ImportDataView: View {
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
                Button { showFilePicker = true } label: {
                    HStack {
                        Spacer()
                        if isImporting { ProgressView() }
                        else { Label("Choose File", systemImage: "doc.badge.plus") }
                        Spacer()
                    }
                }
                .disabled(isImporting)
            }

            if let result = importResult { resultSection(result) }
        }
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { importData(from: url) }
            case .failure(let error):
                importResult = ImportResult(success: false, error: error.localizedDescription)
            }
        }
    }
}

private extension ImportDataView {
    func resultSection(_ result: ImportResult) -> some View {
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

    func importData(from url: URL) {
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

                var counts = (notes: 0, tasks: 0, transactions: 0, health: 0)

                for note in importedData.notes {
                    let newNote = NoteModel(title: note.title, content: note.content)
                    newNote.createdAt = note.createdAt
                    newNote.updatedAt = note.updatedAt
                    newNote.isPinned = note.isPinned
                    modelContext.insert(newNote)
                    counts.notes += 1
                }

                for task in importedData.tasks {
                    let newTask = TaskModel(title: task.title)
                    newTask.notes = task.notes
                    newTask.dueDate = task.dueDate
                    newTask.priority = TaskPriority(rawValue: task.priority) ?? .medium
                    newTask.isCompleted = task.isCompleted
                    newTask.completedAt = task.completedAt
                    modelContext.insert(newTask)
                    counts.tasks += 1
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
                    counts.transactions += 1
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
                    counts.health += 1
                }

                try modelContext.save()

                await MainActor.run {
                    importResult = ImportResult(
                        success: true,
                        notesCount: counts.notes,
                        tasksCount: counts.tasks,
                        transactionsCount: counts.transactions,
                        healthEntriesCount: counts.health
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

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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

struct ImportResult {
    let success: Bool
    var error: String?
    var notesCount: Int = 0
    var tasksCount: Int = 0
    var transactionsCount: Int = 0
    var healthEntriesCount: Int = 0
}
