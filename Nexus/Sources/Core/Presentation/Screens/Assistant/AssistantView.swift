import SwiftUI
import SwiftData

struct AssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \NoteModel.updatedAt, order: .reverse) private var notes: [NoteModel]
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var tasks: [TaskModel]
    @Query(sort: \TransactionModel.date, order: .reverse) private var transactions: [TransactionModel]
    @Query(sort: \HealthEntryModel.date, order: .reverse) private var healthEntries: [HealthEntryModel]

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var showCapabilities = false

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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
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
                            withAnimation {
                                messages.removeAll()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showCapabilities) {
                CapabilitiesView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
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

    private var quickStatsCard: some View {
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

    private var dynamicSuggestions: [String] {
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
        }

        if !notes.isEmpty {
            suggestions.append("Summarize my recent notes")
        }

        if !transactions.isEmpty {
            suggestions.append("How much did I spend this month?")
        }

        if !healthEntries.isEmpty {
            suggestions.append("How's my health tracking going?")
        }

        if suggestions.isEmpty {
            suggestions = [
                "What can you help me with?",
                "Create a new task",
                "Start tracking my health"
            ]
        }

        return Array(suggestions.prefix(4))
    }

    // MARK: - Messages List

    private var messagesList: some View {
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

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask me anything...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.nexusSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    isInputFocused ? Color.nexusPurple.opacity(0.5) : Color.nexusBorder,
                                    lineWidth: isInputFocused ? 2 : 1
                                )
                        }
                }
                .focused($isInputFocused)

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
            .disabled(inputText.isEmpty || isLoading)
            .scaleEffect(inputText.isEmpty ? 1 : 1.05)
            .animation(.spring(response: 0.3), value: inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }

    // MARK: - Send Message

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: inputText)
        withAnimation {
            messages.append(userMessage)
        }
        let currentInput = inputText
        inputText = ""
        isLoading = true

        Task {
            try? await Task.sleep(for: .milliseconds(800))

            let response = generateResponse(for: currentInput)

            await MainActor.run {
                withAnimation {
                    messages.append(response)
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Response Generation

    private func generateResponse(for input: String) -> ChatMessage {
        let lowercased = input.lowercased()

        // Tasks
        if lowercased.contains("task") || lowercased.contains("due") || lowercased.contains("todo") {
            return generateTasksResponse(for: lowercased)
        }

        // Notes
        if lowercased.contains("note") || lowercased.contains("summarize") || lowercased.contains("written") {
            return generateNotesResponse(for: lowercased)
        }

        // Finance
        if lowercased.contains("spend") || lowercased.contains("money") || lowercased.contains("finance") ||
           lowercased.contains("expense") || lowercased.contains("income") || lowercased.contains("budget") {
            return generateFinanceResponse(for: lowercased)
        }

        // Health
        if lowercased.contains("health") || lowercased.contains("sleep") || lowercased.contains("step") ||
           lowercased.contains("weight") || lowercased.contains("water") || lowercased.contains("calorie") {
            return generateHealthResponse(for: lowercased)
        }

        // Capabilities
        if lowercased.contains("can you") || lowercased.contains("help") || lowercased.contains("what can") {
            return ChatMessage(
                role: .assistant,
                content: """
                I can help you with:

                📝 **Notes** - Summarize, search, and organize your notes
                ✅ **Tasks** - Track deadlines, priorities, and completion
                💰 **Finance** - Analyze spending, income, and budgets
                ❤️ **Health** - Monitor sleep, steps, weight, and more

                Just ask me anything about your data!
                """,
                type: .capabilities
            )
        }

        // Create actions
        if lowercased.contains("create") || lowercased.contains("add") || lowercased.contains("new") {
            if lowercased.contains("task") {
                return ChatMessage(
                    role: .assistant,
                    content: "I'd love to help you create a task! Tap the + button on the Tasks tab to add a new task with title, due date, and priority.",
                    type: .action(icon: "plus.circle", label: "Go to Tasks")
                )
            } else if lowercased.contains("note") {
                return ChatMessage(
                    role: .assistant,
                    content: "Ready to capture your thoughts! Head to the Notes tab and tap + to create a new note.",
                    type: .action(icon: "square.and.pencil", label: "Go to Notes")
                )
            }
        }

        // Default response
        return ChatMessage(
            role: .assistant,
            content: "I'm here to help you manage your personal life! You can ask me about your tasks, notes, spending, or health data. For example, try asking \"What tasks are due today?\" or \"How much did I spend this month?\"",
            type: .text
        )
    }

    private func generateTasksResponse(for input: String) -> ChatMessage {
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
                content: """
                📅 **Tasks Due Today** (\(todayTasks.count))

                \(taskList)\(todayTasks.count > 5 ? "\n...and \(todayTasks.count - 5) more" : "")

                \(todayTasks.count == 1 ? "Just one task" : "You've got this!") 💪
                """,
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
                content: """
                ⚠️ **Overdue Tasks** (\(overdueTasks.count))

                \(taskList)

                Consider tackling these soon!
                """,
                type: .taskList(count: overdueTasks.count)
            )
        }

        // General tasks overview
        let completionRate = tasks.isEmpty ? 0 : Int((Double(completedTasks.count) / Double(tasks.count)) * 100)

        return ChatMessage(
            role: .assistant,
            content: """
            📊 **Task Overview**

            • **Pending:** \(pendingTasks.count) tasks
            • **Completed:** \(completedTasks.count) tasks
            • **Due Today:** \(todayTasks.count) tasks
            • **Overdue:** \(overdueTasks.count) tasks

            Completion rate: **\(completionRate)%** \(completionRate >= 70 ? "🌟" : completionRate >= 50 ? "👍" : "💪")
            """,
            type: .stats
        )
    }

    private func generateNotesResponse(for input: String) -> ChatMessage {
        if notes.isEmpty {
            return ChatMessage(
                role: .assistant,
                content: "You haven't created any notes yet. Start capturing your thoughts by tapping the + button in the Notes tab!",
                type: .text
            )
        }

        let thisWeek = notes.filter { note in
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return note.createdAt >= weekAgo
        }

        let pinnedCount = notes.filter { $0.isPinned }.count
        let recentTitles = notes.prefix(5).map { "• \($0.title.isEmpty ? "Untitled" : $0.title)" }.joined(separator: "\n")

        return ChatMessage(
            role: .assistant,
            content: """
            📝 **Notes Summary**

            • **Total Notes:** \(notes.count)
            • **This Week:** \(thisWeek.count) new notes
            • **Pinned:** \(pinnedCount) notes

            **Recent Notes:**
            \(recentTitles)
            """,
            type: .notesSummary(count: notes.count)
        )
    }

    private func generateFinanceResponse(for input: String) -> ChatMessage {
        if transactions.isEmpty {
            return ChatMessage(
                role: .assistant,
                content: "You haven't logged any transactions yet. Start tracking your finances by adding income and expenses in the Finance tab!",
                type: .text
            )
        }

        let calendar = Calendar.current
        let thisMonth = transactions.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        let income = thisMonth.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expenses = thisMonth.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let balance = income - expenses

        // Top categories
        let expensesByCategory = Dictionary(grouping: thisMonth.filter { $0.type == .expense }) { $0.category }
        let topCategories = expensesByCategory
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
            .prefix(3)

        let categoryBreakdown = topCategories.map { "• \($0.category.rawValue.capitalized): \(formatCurrency($0.amount))" }.joined(separator: "\n")

        return ChatMessage(
            role: .assistant,
            content: """
            💰 **Finance Summary** (This Month)

            📈 **Income:** \(formatCurrency(income))
            📉 **Expenses:** \(formatCurrency(expenses))
            💵 **Balance:** \(formatCurrency(balance)) \(balance >= 0 ? "✅" : "⚠️")

            **Top Spending Categories:**
            \(categoryBreakdown.isEmpty ? "No expenses yet" : categoryBreakdown)
            """,
            type: .financeSummary(balance: balance)
        )
    }

    private func generateHealthResponse(for input: String) -> ChatMessage {
        if healthEntries.isEmpty {
            return ChatMessage(
                role: .assistant,
                content: "You haven't logged any health data yet. Start tracking your wellness journey in the Health tab! You can log steps, sleep, water intake, and more.",
                type: .text
            )
        }

        let calendar = Calendar.current
        let thisWeek = healthEntries.filter { entry in
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
            return entry.date >= weekAgo
        }

        // Get latest values for each metric type
        var latestMetrics: [HealthMetricType: Double] = [:]
        for entry in healthEntries {
            if latestMetrics[entry.type] == nil {
                latestMetrics[entry.type] = entry.value
            }
        }

        var healthSummary = "❤️ **Health Summary**\n\n"

        if let steps = latestMetrics[.steps] {
            healthSummary += "🚶 **Steps:** \(Int(steps)) \(steps >= 10000 ? "🎯" : "")\n"
        }
        if let sleep = latestMetrics[.sleep] {
            healthSummary += "😴 **Sleep:** \(String(format: "%.1f", sleep)) hours \(sleep >= 7 ? "✅" : "💤")\n"
        }
        if let water = latestMetrics[.waterIntake] {
            healthSummary += "💧 **Water:** \(Int(water)) ml\n"
        }
        if let weight = latestMetrics[.weight] {
            healthSummary += "⚖️ **Weight:** \(String(format: "%.1f", weight)) kg\n"
        }
        if let calories = latestMetrics[.calories] {
            healthSummary += "🔥 **Calories:** \(Int(calories)) kcal\n"
        }

        healthSummary += "\n📊 **This Week:** \(thisWeek.count) entries logged"

        return ChatMessage(
            role: .assistant,
            content: healthSummary,
            type: .healthSummary
        )
    }

    // MARK: - Helpers

    private var monthlySpending: Double {
        let calendar = Calendar.current
        return transactions
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) && $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date = .now
    var type: MessageType = .text

    enum Role {
        case user, assistant
    }

    enum MessageType {
        case text
        case stats
        case taskList(count: Int)
        case notesSummary(count: Int)
        case financeSummary(balance: Double)
        case healthSummary
        case capabilities
        case action(icon: String, label: String)
    }
}

// MARK: - AI Avatar View

private struct AIAvatarView: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.nexusPurple.opacity(0.3), .nexusBlue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 100 + CGFloat(index * 20), height: 100 + CGFloat(index * 20))
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .opacity(isAnimating ? 0.3 : 0.6)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.3),
                        value: isAnimating
                    )
            }

            // Main circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.nexusPurple, .nexusBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 90)
                .shadow(color: .nexusPurple.opacity(0.5), radius: 20)
                .scaleEffect(pulseScale)

            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }
}

// MARK: - Quick Stat Item

private struct QuickStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.nexusHeadline)

            Text(label)
                .font(.nexusCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 60) }

            if message.role == .assistant {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.nexusPurple, .nexusBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(.init(message.content))
                    .font(.nexusBody)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(bubbleColor)
                    }
                    .foregroundStyle(message.role == .user ? .white : .primary)

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.nexusCaption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 300, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
    }

    private var bubbleColor: Color {
        if message.role == .user {
            return .nexusPurple
        }

        switch message.type {
        case .stats, .taskList, .notesSummary, .financeSummary, .healthSummary:
            return Color.nexusSurface
        default:
            return Color.nexusSurface
        }
    }
}

// MARK: - Suggestion Button

private struct SuggestionButton: View {
    let text: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(Color.nexusPurple)

                Text(text)
                    .font(.nexusSubheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.nexusSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.nexusBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1)
        .animation(.spring(response: 0.3), value: isPressed)
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.nexusPurple, .nexusBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.nexusPurple)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1 : 0.5)
                        .opacity(animating ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nexusSurface)
            }
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Capabilities View

private struct CapabilitiesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    AIAvatarView()
                        .scaleEffect(0.8)
                        .padding(.top, 20)

                    Text("What I Can Do")
                        .font(.nexusTitle2)

                    VStack(spacing: 16) {
                        CapabilityCard(
                            icon: "checkmark.circle.fill",
                            title: "Task Management",
                            description: "View pending tasks, check due dates, track completion rates",
                            color: .tasksColor,
                            examples: ["What tasks are due today?", "Show overdue tasks", "How many tasks did I complete?"]
                        )

                        CapabilityCard(
                            icon: "doc.text.fill",
                            title: "Notes & Writing",
                            description: "Summarize notes, find content, track writing activity",
                            color: .notesColor,
                            examples: ["Summarize my notes", "How many notes this week?"]
                        )

                        CapabilityCard(
                            icon: "creditcard.fill",
                            title: "Finance Tracking",
                            description: "Analyze spending, view income, track by category",
                            color: .financeColor,
                            examples: ["How much did I spend?", "Show my top expenses"]
                        )

                        CapabilityCard(
                            icon: "heart.fill",
                            title: "Health Insights",
                            description: "Monitor sleep, steps, weight, and wellness trends",
                            color: .healthColor,
                            examples: ["How's my health?", "Show my sleep data"]
                        )
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .background(Color.nexusBackground)
            .navigationTitle("Nexus AI")
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
}

private struct CapabilityCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let examples: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.nexusHeadline)
                    Text(description)
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Try saying:")
                    .font(.nexusCaption)
                    .foregroundStyle(.tertiary)

                ForEach(examples, id: \.self) { example in
                    Text("• \"\(example)\"")
                        .font(.nexusCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.nexusSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.nexusBorder, lineWidth: 1)
                }
        }
    }
}

#Preview {
    AssistantView()
        .preferredColorScheme(.dark)
}
