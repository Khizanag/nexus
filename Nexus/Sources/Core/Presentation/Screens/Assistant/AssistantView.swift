import SwiftUI
import SwiftData

struct AssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \NoteModel.updatedAt, order: .reverse) private var notes: [NoteModel]
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var tasks: [TaskModel]
    @Query(sort: \TransactionModel.date, order: .reverse) private var transactions: [TransactionModel]
    @Query(sort: \HealthEntryModel.date, order: .reverse) private var healthEntries: [HealthEntryModel]
    @Query(sort: \ChatMessageModel.timestamp, order: .forward) private var savedMessages: [ChatMessageModel]

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var showCapabilities = false

    @State private var speechService = SpeechRecognitionService()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }
                inputBar
            }
            .background(Color.nexusBackground)
            .navigationTitle("Nexus AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showCapabilities) {
                CapabilitiesView()
            }
            .onAppear { loadSavedMessages() }
            .onChange(of: speechService.transcribedText) { _, newValue in
                if !newValue.isEmpty { inputText = newValue }
            }
            .alert("Voice Input", isPresented: .init(
                get: { speechService.errorMessage != nil },
                set: { if !$0 { speechService.errorMessage = nil } }
            )) {
                Button("OK") { speechService.errorMessage = nil }
            } message: {
                if let error = speechService.errorMessage { Text(error) }
            }
        }
    }
}

// MARK: - Toolbar

private extension AssistantView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("What can you do?", systemImage: "sparkles") {
                    showCapabilities = true
                }
                Button("Clear Chat", systemImage: "trash", role: .destructive) {
                    clearAllMessages()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Message Persistence

private extension AssistantView {
    func loadSavedMessages() {
        messages = savedMessages.map { saved in
            ChatMessage(
                id: saved.id,
                role: saved.role == "user" ? .user : .assistant,
                content: saved.content,
                timestamp: saved.timestamp
            )
        }
    }

    func saveMessage(_ message: ChatMessage) {
        let savedMessage = ChatMessageModel(
            id: message.id,
            role: message.role == .user ? "user" : "assistant",
            content: message.content,
            timestamp: message.timestamp
        )
        modelContext.insert(savedMessage)
    }

    func clearAllMessages() {
        withAnimation { messages.removeAll() }
        for saved in savedMessages {
            modelContext.delete(saved)
        }
    }
}

// MARK: - Empty State

private extension AssistantView {
    var emptyState: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 20)
                AIAvatarView()

                VStack(spacing: 8) {
                    Text("Hey! I'm Nexus AI")
                        .font(.nexusTitle2)
                    Text("Your personal life assistant. I can help you with notes, tasks, finances, and health tracking.")
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                quickStatsCard

                VStack(spacing: 12) {
                    Text("Try asking")
                        .font(.nexusCaption)
                        .foregroundStyle(.tertiary)

                    ForEach(dynamicSuggestions, id: \.self) { suggestion in
                        SuggestionButton(text: suggestion) {
                            inputText = suggestion
                            sendMessage()
                        }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    var quickStatsCard: some View {
        HStack(spacing: 0) {
            QuickStatItem(
                value: "\(tasks.filter { !$0.isCompleted }.count)",
                label: "Open Tasks",
                icon: "checkmark.circle",
                color: .tasksColor
            )
            Divider().frame(height: 40)
            QuickStatItem(
                value: "\(notes.count)",
                label: "Notes",
                icon: "doc.text",
                color: .notesColor
            )
            Divider().frame(height: 40)
            QuickStatItem(
                value: formatCurrency(monthlySpending),
                label: "This Month",
                icon: "creditcard",
                color: .financeColor
            )
        }
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
        .padding(.horizontal, 20)
    }

    var dynamicSuggestions: [String] {
        var suggestions: [String] = []
        let pendingTasks = tasks.filter { !$0.isCompleted }
        let todayTasks = pendingTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due)
        }

        if todayTasks.count > 0 {
            suggestions.append("What tasks are due today?")
        } else if pendingTasks.count > 0 {
            suggestions.append("Show my pending tasks")
        } else {
            suggestions.append("Create task Buy groceries tomorrow")
        }

        if !notes.isEmpty {
            suggestions.append("Summarize my recent notes")
        } else {
            suggestions.append("Create note Meeting ideas")
        }

        if !transactions.isEmpty {
            suggestions.append("How much did I spend this month?")
        }

        if let firstTask = pendingTasks.first {
            let shortTitle = firstTask.title.prefix(20)
            suggestions.append("Complete task \(shortTitle)")
        }

        let healthSuggestions = ["Log 8 hours of sleep", "Drank 500ml water", "Walked 5000 steps"]
        if suggestions.count < 4 {
            suggestions.append(healthSuggestions.randomElement() ?? "Log 8 hours of sleep")
        }

        return Array(suggestions.prefix(4))
    }
}

// MARK: - Messages List

private extension AssistantView {
    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    if isLoading {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 16)
                .animation(.spring(response: 0.4), value: messages.count)
            }
            .onChange(of: messages.count) {
                withAnimation(.spring(response: 0.3)) {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Input Bar

private extension AssistantView {
    var inputBar: some View {
        HStack(spacing: 8) {
            microphoneButton
            textField
            sendButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }

    var microphoneButton: some View {
        Button {
            speechService.toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(speechService.isRecording ? Color.nexusRed : Color.nexusSurface)
                    .frame(width: 44, height: 44)

                Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(speechService.isRecording ? Color.white : Color.nexusPurple)
                    .scaleEffect(speechService.isRecording ? 0.8 : 1.0)
            }
            .overlay {
                if speechService.isRecording {
                    Circle()
                        .stroke(Color.nexusRed.opacity(0.5), lineWidth: 2)
                        .scaleEffect(1.2)
                        .opacity(speechService.isRecording ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speechService.isRecording)
                }
            }
        }
        .animation(.spring(response: 0.3), value: speechService.isRecording)
    }

    var textField: some View {
        TextField(speechService.isRecording ? "Listening..." : "Ask me anything...", text: $inputText, axis: .vertical)
            .lineLimit(1...5)
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                speechService.isRecording ? Color.nexusRed.opacity(0.5) :
                                isInputFocused ? Color.nexusPurple.opacity(0.5) : Color.nexusBorder,
                                lineWidth: (isInputFocused || speechService.isRecording) ? 2 : 1
                            )
                    }
            }
            .focused($isInputFocused)
            .disabled(speechService.isRecording)
    }

    var sendButton: some View {
        Button(action: sendMessage) {
            ZStack {
                Circle()
                    .fill(inputText.isEmpty ? Color.nexusSurface : Color.nexusPurple)
                    .frame(width: 44, height: 44)

                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.white)
            }
        }
        .disabled(inputText.isEmpty || isLoading || speechService.isRecording)
        .scaleEffect(inputText.isEmpty ? 1 : 1.05)
        .animation(.spring(response: 0.3), value: inputText.isEmpty)
    }
}

// MARK: - Send Message

private extension AssistantView {
    func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: inputText)
        withAnimation { messages.append(userMessage) }
        saveMessage(userMessage)

        let currentInput = inputText
        inputText = ""
        isLoading = true

        Task {
            try? await Task.sleep(for: .milliseconds(800))
            let response = generateResponse(for: currentInput)

            await MainActor.run {
                withAnimation {
                    messages.append(response)
                    saveMessage(response)
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Response Generation

private extension AssistantView {
    func generateResponse(for input: String) -> ChatMessage {
        let lowercased = input.lowercased()

        if let taskAction = parseTaskAction(input: input, lowercased: lowercased) { return taskAction }
        if let noteAction = parseNoteAction(input: input, lowercased: lowercased) { return noteAction }
        if let completeAction = parseCompleteAction(lowercased: lowercased) { return completeAction }
        if let healthAction = parseHealthAction(input: input, lowercased: lowercased) { return healthAction }

        if lowercased.contains("task") || lowercased.contains("due") || lowercased.contains("todo") {
            return generateTasksResponse(for: lowercased)
        }

        if lowercased.contains("note") || lowercased.contains("summarize") || lowercased.contains("written") {
            return generateNotesResponse(for: lowercased)
        }

        if lowercased.contains("spend") || lowercased.contains("money") || lowercased.contains("finance") ||
           lowercased.contains("expense") || lowercased.contains("income") || lowercased.contains("budget") {
            return generateFinanceResponse(for: lowercased)
        }

        if lowercased.contains("health") || lowercased.contains("sleep") || lowercased.contains("step") ||
           lowercased.contains("weight") || lowercased.contains("water") || lowercased.contains("calorie") {
            return generateHealthResponse(for: lowercased)
        }

        if lowercased.contains("can you") || lowercased.contains("help") || lowercased.contains("what can") {
            return ChatMessage(
                role: .assistant,
                content: """
                I can help you with:

                📝 **Notes** - Create, summarize, and organize your notes
                ✅ **Tasks** - Create tasks, track deadlines, mark complete
                💰 **Finance** - Analyze spending, income, and budgets
                ❤️ **Health** - Log and track your health metrics

                **Quick Actions:**
                • "Create task Buy groceries tomorrow"
                • "Add note Meeting notes: ..."
                • "Complete task Buy groceries"
                • "Log 8 hours of sleep"
                """,
                type: .capabilities
            )
        }

        return ChatMessage(
            role: .assistant,
            content: "I'm here to help you manage your personal life! You can ask me about your tasks, notes, spending, or health data. I can also **create tasks and notes** for you - just say \"Create task...\" or \"Add note...\"",
            type: .text
        )
    }

    func generateTasksResponse(for input: String) -> ChatMessage {
        let pendingTasks = tasks.filter { !$0.isCompleted }
        let completedTasks = tasks.filter { $0.isCompleted }
        let todayTasks = pendingTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return Calendar.current.isDateInToday(due)
        }
        let overdueTasks = pendingTasks.filter { task in
            guard let due = task.dueDate else { return false }
            return due < Date() && !Calendar.current.isDateInToday(due)
        }

        if input.contains("today") {
            if todayTasks.isEmpty {
                return ChatMessage(role: .assistant, content: "You have no tasks due today. Enjoy your free day! 🎉", type: .text)
            }
            let taskList = todayTasks.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
            return ChatMessage(
                role: .assistant,
                content: "📅 **Tasks Due Today** (\(todayTasks.count))\n\n\(taskList)\(todayTasks.count > 5 ? "\n...and \(todayTasks.count - 5) more" : "")\n\n\(todayTasks.count == 1 ? "Just one task" : "You've got this!") 💪",
                type: .taskList(count: todayTasks.count)
            )
        }

        if input.contains("overdue") || input.contains("late") {
            if overdueTasks.isEmpty {
                return ChatMessage(role: .assistant, content: "Great news! You have no overdue tasks. You're on top of things! ⭐", type: .text)
            }
            let taskList = overdueTasks.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
            return ChatMessage(
                role: .assistant,
                content: "⚠️ **Overdue Tasks** (\(overdueTasks.count))\n\n\(taskList)\n\nConsider tackling these soon!",
                type: .taskList(count: overdueTasks.count)
            )
        }

        let completionRate = tasks.isEmpty ? 0 : Int((Double(completedTasks.count) / Double(tasks.count)) * 100)
        return ChatMessage(
            role: .assistant,
            content: "📊 **Task Overview**\n\n• **Pending:** \(pendingTasks.count) tasks\n• **Completed:** \(completedTasks.count) tasks\n• **Due Today:** \(todayTasks.count) tasks\n• **Overdue:** \(overdueTasks.count) tasks\n\nCompletion rate: **\(completionRate)%** \(completionRate >= 70 ? "🌟" : completionRate >= 50 ? "👍" : "💪")",
            type: .stats
        )
    }

    func generateNotesResponse(for input: String) -> ChatMessage {
        if notes.isEmpty {
            return ChatMessage(role: .assistant, content: "You haven't created any notes yet. Start capturing your thoughts by tapping the + button in the Notes tab!", type: .text)
        }

        let thisWeek = notes.filter { note in
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return note.createdAt >= weekAgo
        }
        let pinnedCount = notes.filter { $0.isPinned }.count
        let recentTitles = notes.prefix(5).map { "• \($0.title.isEmpty ? "Untitled" : $0.title)" }.joined(separator: "\n")

        return ChatMessage(
            role: .assistant,
            content: "📝 **Notes Summary**\n\n• **Total Notes:** \(notes.count)\n• **This Week:** \(thisWeek.count) new notes\n• **Pinned:** \(pinnedCount) notes\n\n**Recent Notes:**\n\(recentTitles)",
            type: .notesSummary(count: notes.count)
        )
    }

    func generateFinanceResponse(for input: String) -> ChatMessage {
        if transactions.isEmpty {
            return ChatMessage(role: .assistant, content: "You haven't logged any transactions yet. Start tracking your finances by adding income and expenses in the Finance tab!", type: .text)
        }

        let calendar = Calendar.current
        let thisMonth = transactions.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        let income = thisMonth.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expenses = thisMonth.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let balance = income - expenses

        let expensesByCategory = Dictionary(grouping: thisMonth.filter { $0.type == .expense }) { $0.category }
        let topCategories = expensesByCategory
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
            .prefix(3)
        let categoryBreakdown = topCategories.map { "• \($0.category.rawValue.capitalized): \(formatCurrency($0.amount))" }.joined(separator: "\n")

        return ChatMessage(
            role: .assistant,
            content: "💰 **Finance Summary** (This Month)\n\n📈 **Income:** \(formatCurrency(income))\n📉 **Expenses:** \(formatCurrency(expenses))\n💵 **Balance:** \(formatCurrency(balance)) \(balance >= 0 ? "✅" : "⚠️")\n\n**Top Spending Categories:**\n\(categoryBreakdown.isEmpty ? "No expenses yet" : categoryBreakdown)",
            type: .financeSummary(balance: balance)
        )
    }

    func generateHealthResponse(for input: String) -> ChatMessage {
        if healthEntries.isEmpty {
            return ChatMessage(role: .assistant, content: "You haven't logged any health data yet. Start tracking your wellness journey in the Health tab!", type: .text)
        }

        var latestMetrics: [HealthMetricType: Double] = [:]
        for entry in healthEntries {
            if latestMetrics[entry.type] == nil {
                latestMetrics[entry.type] = entry.value
            }
        }

        var healthSummary = "❤️ **Health Summary**\n\n"
        if let steps = latestMetrics[.steps] { healthSummary += "🚶 **Steps:** \(Int(steps)) \(steps >= 10000 ? "🎯" : "")\n" }
        if let sleep = latestMetrics[.sleep] { healthSummary += "😴 **Sleep:** \(String(format: "%.1f", sleep)) hours \(sleep >= 7 ? "✅" : "💤")\n" }
        if let water = latestMetrics[.waterIntake] { healthSummary += "💧 **Water:** \(Int(water)) ml\n" }
        if let weight = latestMetrics[.weight] { healthSummary += "⚖️ **Weight:** \(String(format: "%.1f", weight)) kg\n" }
        if let calories = latestMetrics[.calories] { healthSummary += "🔥 **Calories:** \(Int(calories)) kcal\n" }

        let calendar = Calendar.current
        let thisWeek = healthEntries.filter { entry in
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
            return entry.date >= weekAgo
        }
        healthSummary += "\n📊 **This Week:** \(thisWeek.count) entries logged"

        return ChatMessage(role: .assistant, content: healthSummary, type: .healthSummary)
    }
}

// MARK: - AI Actions

private extension AssistantView {
    func parseTaskAction(input: String, lowercased: String) -> ChatMessage? {
        let createPatterns = ["create task", "add task", "new task", "make task", "remind me to", "reminder to", "todo:"]
        for pattern in createPatterns {
            if lowercased.contains(pattern) {
                let extracted = extractContent(from: input, after: pattern)
                if !extracted.isEmpty { return createTask(title: extracted, fromInput: lowercased) }
            }
        }
        return nil
    }

    func parseNoteAction(input: String, lowercased: String) -> ChatMessage? {
        let createPatterns = ["create note", "add note", "new note", "make note", "write note", "note:"]
        for pattern in createPatterns {
            if lowercased.contains(pattern) {
                let extracted = extractContent(from: input, after: pattern)
                if !extracted.isEmpty { return createNote(content: extracted) }
            }
        }
        return nil
    }

    func parseCompleteAction(lowercased: String) -> ChatMessage? {
        let completePatterns = ["complete task", "finish task", "done with", "mark done", "mark complete", "completed"]
        for pattern in completePatterns {
            if lowercased.contains(pattern) {
                let searchTerm = extractContent(from: lowercased, after: pattern)
                if !searchTerm.isEmpty { return completeTask(matching: searchTerm) }
            }
        }
        return nil
    }

    func extractContent(from input: String, after pattern: String) -> String {
        let lowercased = input.lowercased()
        guard let range = lowercased.range(of: pattern) else { return "" }

        let startIndex = input.index(input.startIndex, offsetBy: lowercased.distance(from: lowercased.startIndex, to: range.upperBound))
        var content = String(input[startIndex...]).trimmingCharacters(in: .whitespaces)

        let wordsToRemove = ["to ", "a ", "an ", "the ", "called ", "named ", "titled "]
        for word in wordsToRemove {
            if content.lowercased().hasPrefix(word) {
                content = String(content.dropFirst(word.count))
            }
        }
        return content.trimmingCharacters(in: .whitespaces)
    }

    func createTask(title: String, fromInput input: String) -> ChatMessage {
        let parsedTitle = parseTaskTitle(title)
        let dueDate = parseDueDate(from: input)
        let priority = parsePriority(from: input)

        let task = TaskModel(title: parsedTitle, priority: priority, dueDate: dueDate)
        modelContext.insert(task)

        var confirmationParts = ["✅ **Task Created!**\n\n**\(parsedTitle)**"]
        if let due = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            confirmationParts.append("📅 Due: \(formatter.string(from: due))")
        }
        if priority != .medium {
            confirmationParts.append("🏷️ Priority: \(priority.rawValue.capitalized)")
        }

        return ChatMessage(role: .assistant, content: confirmationParts.joined(separator: "\n"), type: .taskCreated(title: parsedTitle))
    }

    func parseTaskTitle(_ input: String) -> String {
        var title = input
        let timePatterns = [
            " tomorrow", " today", " tonight", " next week", " next month",
            " this week", " this weekend",
            " on monday", " on tuesday", " on wednesday", " on thursday", " on friday", " on saturday", " on sunday",
            " high priority", " low priority", " urgent", " important"
        ]
        for pattern in timePatterns {
            if let range = title.lowercased().range(of: pattern) {
                let startIndex = title.index(title.startIndex, offsetBy: title.lowercased().distance(from: title.lowercased().startIndex, to: range.lowerBound))
                title = String(title[..<startIndex])
            }
        }
        return title.trimmingCharacters(in: .whitespaces)
    }

    func parseDueDate(from input: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        if input.contains("today") || input.contains("tonight") {
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now)
        }
        if input.contains("tomorrow") {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: tomorrow)
            }
        }
        if input.contains("next week") { return calendar.date(byAdding: .weekOfYear, value: 1, to: now) }
        if input.contains("this weekend") {
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            components.weekday = 7
            return calendar.date(from: components)
        }

        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
        for (dayName, dayNumber) in weekdays {
            if input.contains(dayName) {
                var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
                components.weekday = dayNumber
                if let date = calendar.date(from: components), date <= now {
                    return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
                }
                return calendar.date(from: components)
            }
        }
        return nil
    }

    func parsePriority(from input: String) -> TaskPriority {
        if input.contains("urgent") || input.contains("asap") || input.contains("immediately") { return .urgent }
        if input.contains("high priority") || input.contains("important") { return .high }
        if input.contains("low priority") || input.contains("whenever") || input.contains("not urgent") { return .low }
        return .medium
    }

    func createNote(content: String) -> ChatMessage {
        let (title, body) = parseNoteContent(content)
        let note = NoteModel(title: title, content: body)
        modelContext.insert(note)

        let preview = body.isEmpty ? "" : "\n\n\(body.prefix(100))\(body.count > 100 ? "..." : "")"
        return ChatMessage(role: .assistant, content: "📝 **Note Created!**\n\n**\(title)**\(preview)", type: .noteCreated(title: title))
    }

    func parseNoteContent(_ content: String) -> (title: String, body: String) {
        if let colonIndex = content.firstIndex(of: ":") {
            let title = String(content[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let bodyStart = content.index(after: colonIndex)
            let body = String(content[bodyStart...]).trimmingCharacters(in: .whitespaces)
            return (title.isEmpty ? "New Note" : title, body)
        }
        if let newlineIndex = content.firstIndex(of: "\n") {
            let title = String(content[..<newlineIndex]).trimmingCharacters(in: .whitespaces)
            let bodyStart = content.index(after: newlineIndex)
            let body = String(content[bodyStart...]).trimmingCharacters(in: .whitespaces)
            return (title.isEmpty ? "New Note" : title, body)
        }
        let words = content.split(separator: " ")
        if words.count > 5 {
            let title = words.prefix(4).joined(separator: " ")
            return (title, content)
        }
        return (content, "")
    }

    func completeTask(matching searchTerm: String) -> ChatMessage {
        let pendingTasks = tasks.filter { !$0.isCompleted }
        let matchingTask = pendingTasks.first { $0.title.lowercased().contains(searchTerm.lowercased()) }

        if let task = matchingTask {
            task.isCompleted = true
            task.completedAt = Date()
            task.updatedAt = Date()
            return ChatMessage(role: .assistant, content: "🎉 **Task Completed!**\n\n~~\(task.title)~~\n\nGreat job! One less thing to worry about.", type: .taskCompleted(title: task.title))
        }

        let similarTasks = pendingTasks.filter { task in
            let taskWords = Set(task.title.lowercased().split(separator: " ").map(String.init))
            let searchWords = Set(searchTerm.lowercased().split(separator: " ").map(String.init))
            return !taskWords.isDisjoint(with: searchWords)
        }.prefix(3)

        if !similarTasks.isEmpty {
            let suggestions = similarTasks.map { "• \($0.title)" }.joined(separator: "\n")
            return ChatMessage(role: .assistant, content: "I couldn't find a task matching \"\(searchTerm)\". Did you mean one of these?\n\n\(suggestions)\n\nTry saying \"Complete task [exact name]\"", type: .text)
        }

        return ChatMessage(role: .assistant, content: "I couldn't find a pending task matching \"\(searchTerm)\". You have \(pendingTasks.count) pending tasks. Try asking \"Show my tasks\" to see them.", type: .text)
    }
}

// MARK: - Health Actions

private extension AssistantView {
    func parseHealthAction(input: String, lowercased: String) -> ChatMessage? {
        let logPatterns = ["log ", "logged ", "track ", "tracked ", "record ", "recorded ", "add health ", "drank ", "slept ", "walked ", "weigh ", "weight "]
        for pattern in logPatterns {
            if lowercased.contains(pattern) {
                if let result = parseHealthEntry(from: input, lowercased: lowercased) { return result }
            }
        }

        let metricKeywords: [(keywords: [String], metric: HealthMetricType)] = [
            (["water", "ml", "liter", "litre", "hydrat"], .waterIntake),
            (["sleep", "slept", "hour of sleep", "hours of sleep"], .sleep),
            (["step", "walked"], .steps),
            (["calorie", "kcal", "cal burned"], .calories),
            (["weight", "weigh", "kg", "pound", "lb"], .weight),
            (["heart rate", "bpm", "pulse", "heartbeat"], .heartRate),
            (["mood", "feeling", "feel "], .mood),
            (["energy", "energetic", "tired"], .energy),
            (["blood pressure", "bp "], .bloodPressure)
        ]

        for (keywords, metric) in metricKeywords {
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    if let value = extractNumber(from: lowercased) {
                        return logHealthEntry(metric: metric, value: value)
                    }
                }
            }
        }
        return nil
    }

    func extractNumber(from text: String) -> Double? {
        let pattern = #"(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[range])
    }

    func parseHealthEntry(from input: String, lowercased: String) -> ChatMessage? {
        if lowercased.contains("water") || lowercased.contains("drank") || lowercased.contains("ml") || lowercased.contains("liter") {
            if let value = extractNumber(from: lowercased) {
                var amount = value
                if lowercased.contains("liter") || lowercased.contains("litre") || lowercased.contains("l ") { amount = value * 1000 }
                else if lowercased.contains("glass") || lowercased.contains("cup") { amount = value * 250 }
                return logHealthEntry(metric: .waterIntake, value: amount)
            }
        }
        if lowercased.contains("sleep") || lowercased.contains("slept") {
            if let value = extractNumber(from: lowercased) { return logHealthEntry(metric: .sleep, value: value) }
        }
        if lowercased.contains("step") || lowercased.contains("walked") {
            if let value = extractNumber(from: lowercased) { return logHealthEntry(metric: .steps, value: value) }
        }
        if lowercased.contains("calorie") || lowercased.contains("kcal") {
            if let value = extractNumber(from: lowercased) { return logHealthEntry(metric: .calories, value: value) }
        }
        if lowercased.contains("weight") || lowercased.contains("weigh") {
            if let value = extractNumber(from: lowercased) {
                var weight = value
                if lowercased.contains("lb") || lowercased.contains("pound") { weight = value * 0.453592 }
                return logHealthEntry(metric: .weight, value: weight)
            }
        }
        if lowercased.contains("heart rate") || lowercased.contains("bpm") || lowercased.contains("pulse") {
            if let value = extractNumber(from: lowercased) { return logHealthEntry(metric: .heartRate, value: value) }
        }
        if lowercased.contains("mood") || (lowercased.contains("feeling") && extractNumber(from: lowercased) != nil) {
            if let value = extractNumber(from: lowercased) {
                return logHealthEntry(metric: .mood, value: min(max(value, 1), 10))
            }
        }
        if lowercased.contains("energy") {
            if let value = extractNumber(from: lowercased) {
                return logHealthEntry(metric: .energy, value: min(max(value, 1), 10))
            }
        }
        return nil
    }

    func logHealthEntry(metric: HealthMetricType, value: Double) -> ChatMessage {
        let entry = HealthEntryModel(type: metric, value: value, unit: metric.defaultUnit, date: Date())
        modelContext.insert(entry)

        let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)

        let emoji: String
        switch metric {
        case .weight: emoji = "⚖️"
        case .waterIntake: emoji = "💧"
        case .sleep: emoji = "😴"
        case .steps: emoji = "🚶"
        case .calories: emoji = "🔥"
        case .heartRate: emoji = "❤️"
        case .bloodPressure: emoji = "🩺"
        case .mood: emoji = "😊"
        case .energy: emoji = "⚡"
        }

        return ChatMessage(
            role: .assistant,
            content: "\(emoji) **\(metric.displayName) Logged!**\n\n**\(formattedValue) \(metric.defaultUnit)**\n\nKeep tracking for better insights!",
            type: .healthLogged(metric: metric.displayName, value: "\(formattedValue) \(metric.defaultUnit)")
        )
    }
}

// MARK: - Helpers

private extension AssistantView {
    var monthlySpending: Double {
        let calendar = Calendar.current
        return transactions
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) && $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

#Preview {
    AssistantView()
        .preferredColorScheme(.dark)
}
