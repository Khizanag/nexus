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
    @Query(sort: \SubscriptionModel.name) private var subscriptions: [SubscriptionModel]
    @Query(sort: \BudgetModel.name) private var budgets: [BudgetModel]
    @Query(sort: \StockHoldingModel.symbol) private var stocks: [StockHoldingModel]
    @Query(sort: \HouseModel.name) private var houses: [HouseModel]

    private let calendarService = DefaultCalendarService.shared
    private let assistantLauncher = AssistantLauncher.shared

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var showCapabilities = false
    @State private var pendingDismissWithNavigation: AssistantNavigation?

    @State private var lastMentionedEvents: [CalendarEvent] = []
    @State private var lastMentionedTasks: [TaskModel] = []
    @State private var lastMentionedNotes: [NoteModel] = []
    @State private var selectedEventToShow: CalendarEvent?

    @State private var speechService = SpeechRecognitionService()
    @State private var showScrollToBottom = false
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                mainContent
                scrollToBottomOverlay
            }
            .navigationTitle("Nexus AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showCapabilities) { CapabilitiesView() }
            .sheet(item: $selectedEventToShow) { event in
                CalendarEventDetailView(event: event, onUpdate: {})
            }
            .onAppear { loadSavedMessages() }
            .onChange(of: speechService.transcribedText) { _, newValue in
                if !newValue.isEmpty { inputText = newValue }
            }
            .onChange(of: pendingDismissWithNavigation) { _, newValue in
                handlePendingNavigation(newValue)
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
                Button("What can you do?", systemImage: "sparkles") { showCapabilities = true }
                Button("Clear Chat", systemImage: "trash", role: .destructive) { clearAllMessages() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Main Content

private extension AssistantView {
    var mainContent: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                emptyState
            } else {
                messagesList
            }
            inputBar
        }
    }

    @ViewBuilder
    var scrollToBottomOverlay: some View {
        if showScrollToBottom, !messages.isEmpty {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    scrollToBottomButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 90)
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Empty State

private extension AssistantView {
    var emptyState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(height: 10)
                AIAvatarView()
                    .padding(.top, 10)
                welcomeText
                quickStatsCard
                suggestionsSection
                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
        }
    }

    var welcomeText: some View {
        VStack(spacing: 10) {
            Text("Hey! I'm Nexus")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Your AI-powered life assistant.\nAsk me anything about your data.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 24)
    }

    var quickStatsCard: some View {
        GlassCard {
            HStack(spacing: 0) {
                QuickStatItem(
                    value: "\(tasks.filter { !$0.isCompleted }.count)",
                    label: "Tasks",
                    icon: "checkmark.circle",
                    color: .tasksColor
                )

                statDivider

                QuickStatItem(
                    value: "\(notes.count)",
                    label: "Notes",
                    icon: "doc.text",
                    color: .notesColor
                )

                statDivider

                QuickStatItem(
                    value: formatCurrency(monthlySpending),
                    label: "Spent",
                    icon: "creditcard",
                    color: .financeColor
                )
            }
            .padding(.vertical, 20)
        }
        .padding(.horizontal, 20)
    }

    var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(width: 1, height: 50)
    }

    var suggestionsSection: some View {
        VStack(spacing: 14) {
            Text("Try asking")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(1)

            VStack(spacing: 10) {
                ForEach(dynamicSuggestions, id: \.self) { suggestion in
                    SuggestionButton(text: suggestion) {
                        inputText = suggestion
                        sendMessage()
                    }
                }
            }
        }
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
                LazyVStack(spacing: 8) {
                    Color.clear.frame(height: 8)

                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    if isLoading {
                        loadingIndicator
                    }

                    bottomAnchor
                }
                .padding(.vertical, 16)
                .animation(.spring(response: 0.4), value: messages.count)
            }
            .onAppear { setupScrollProxy(proxy) }
            .onChange(of: messages.count) { scrollToLatestMessage(proxy) }
        }
    }

    var loadingIndicator: some View {
        HStack {
            TypingIndicator()
            Spacer()
        }
        .padding(.horizontal, 20)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    var bottomAnchor: some View {
        Color.clear
            .frame(height: 1)
            .id("bottom")
            .onAppear { showScrollToBottom = false }
            .onDisappear { showScrollToBottom = true }
    }

    var scrollToBottomButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        } label: {
            scrollToBottomButtonContent
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var scrollToBottomButtonContent: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

            Image(systemName: "chevron.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.nexusPurple, .nexusBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    func setupScrollProxy(_ proxy: ScrollViewProxy) {
        scrollProxy = proxy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let lastMessage = messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    func scrollToLatestMessage(_ proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.3)) {
            proxy.scrollTo(messages.last?.id, anchor: .bottom)
        }
    }
}

// MARK: - Input Bar

private extension AssistantView {
    var inputBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                microphoneButton
                textField
                sendButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background { inputBarBackground }
    }

    var inputBarBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.1), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 1)
            }
            .ignoresSafeArea()
    }

    var microphoneButton: some View {
        Button { speechService.toggleRecording() } label: {
            microphoneButtonContent
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var microphoneButtonContent: some View {
        ZStack {
            if speechService.isRecording {
                microphoneRecordingBackground
            } else {
                microphoneIdleBackground
            }

            Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(speechService.isRecording ? Color.white : Color.nexusPurple)
                .scaleEffect(speechService.isRecording ? 0.9 : 1.0)
        }
        .overlay {
            if speechService.isRecording {
                Circle()
                    .stroke(Color.nexusRed.opacity(0.5), lineWidth: 2)
                    .scaleEffect(1.2)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speechService.isRecording)
            }
        }
    }

    var microphoneRecordingBackground: some View {
        Circle()
            .fill(Color.nexusRed)
            .frame(width: 44, height: 44)
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.nexusRed, .nexusRed.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.nexusRed.opacity(0.4), radius: 8)
    }

    var microphoneIdleBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 44, height: 44)
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.1), radius: 8)
    }

    var textField: some View {
        TextField(speechService.isRecording ? "Listening..." : "Message...", text: $inputText, axis: .vertical)
            .font(.system(size: 16, weight: .regular))
            .lineLimit(1...5)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background { textFieldBackground }
            .focused($isInputFocused)
            .disabled(speechService.isRecording)
    }

    var textFieldBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: isInputFocused || speechService.isRecording
                                ? [.nexusPurple.opacity(0.5), .nexusBlue.opacity(0.3)]
                                : [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.05), radius: 8)
    }

    var sendButton: some View {
        Button(action: sendMessage) {
            sendButtonContent
        }
        .disabled(inputText.isEmpty || isLoading || speechService.isRecording)
        .scaleEffect(inputText.isEmpty ? 1 : 1.08)
        .animation(.spring(response: 0.3), value: inputText.isEmpty)
    }

    var sendButtonContent: some View {
        ZStack {
            if inputText.isEmpty {
                sendButtonIdleBackground
            } else {
                sendButtonActiveBackground
            }

            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.white)
        }
    }

    var sendButtonIdleBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: 44, height: 44)
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }

    var sendButtonActiveBackground: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.nexusPurple, .nexusBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 44, height: 44)
            .shadow(color: Color.nexusPurple.opacity(0.4), radius: 10)
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

// MARK: - Navigation

private extension AssistantView {
    func navigateAndDismiss(to destination: AssistantNavigation) {
        pendingDismissWithNavigation = destination
    }

    func handlePendingNavigation(_ destination: AssistantNavigation?) {
        guard let destination else { return }
        assistantLauncher.navigate(to: destination)
        pendingDismissWithNavigation = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dismiss()
        }
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
            let response = await generateResponse(for: currentInput)

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
    func generateResponse(for input: String) async -> ChatMessage {
        let lowercased = input.lowercased()

        if let openAction = parseOpenAction(lowercased: lowercased) { return openAction }
        if let taskAction = parseTaskAction(input: input, lowercased: lowercased) { return taskAction }
        if let noteAction = parseNoteAction(input: input, lowercased: lowercased) { return noteAction }
        if let completeAction = parseCompleteAction(lowercased: lowercased) { return completeAction }
        if let healthAction = parseHealthAction(input: input, lowercased: lowercased) { return healthAction }
        if let subscriptionAction = parseSubscriptionAction(input: input, lowercased: lowercased) { return subscriptionAction }

        if lowercased.contains("task") || lowercased.contains("due") || lowercased.contains("todo") {
            return generateTasksResponse(for: lowercased)
        }

        if lowercased.contains("note") || lowercased.contains("summarize") || lowercased.contains("written") {
            return generateNotesResponse(for: lowercased)
        }

        if lowercased.contains("subscription") || lowercased.contains("recurring") || lowercased.contains("netflix") ||
           lowercased.contains("spotify") || lowercased.contains("monthly service") {
            return generateSubscriptionsResponse(for: lowercased)
        }

        if lowercased.contains("calendar") || lowercased.contains("event") || lowercased.contains("schedule") ||
           lowercased.contains("appointment") || lowercased.contains("meeting") || lowercased.contains("today") {
            return await generateCalendarResponse(for: lowercased)
        }

        if lowercased.contains("budget") {
            return generateBudgetResponse(for: lowercased)
        }

        if lowercased.contains("spend") || lowercased.contains("money") || lowercased.contains("finance") ||
           lowercased.contains("expense") || lowercased.contains("income") {
            return generateFinanceResponse(for: lowercased)
        }

        if lowercased.contains("stock") || lowercased.contains("portfolio") || lowercased.contains("invest") ||
           lowercased.contains("shares") || lowercased.contains("ticker") {
            return generateStocksResponse(for: lowercased)
        }

        if lowercased.contains("house") || lowercased.contains("utility") || lowercased.contains("electric") ||
           lowercased.contains("gas bill") || lowercased.contains("water bill") || lowercased.contains("property") {
            return generateHouseResponse(for: lowercased)
        }

        if lowercased.contains("health") || lowercased.contains("sleep") || lowercased.contains("step") ||
           lowercased.contains("weight") || lowercased.contains("water") || lowercased.contains("calorie") {
            return generateHealthResponse(for: lowercased)
        }

        if lowercased.contains("can you") || lowercased.contains("help") || lowercased.contains("what can") {
            return generateCapabilitiesResponse()
        }

        return generateDefaultResponse()
    }

    func generateCapabilitiesResponse() -> ChatMessage {
        ChatMessage(
            role: .assistant,
            content: """
            I can help you with everything in Nexus:

            📝 **Notes** - Create and summarize notes
            ✅ **Tasks** - Create tasks, track deadlines, mark complete
            📅 **Calendar** - View today's events and schedule
            💰 **Finance** - Analyze spending and budgets
            🔄 **Subscriptions** - Track recurring payments
            📈 **Stocks** - View your investment portfolio
            🏠 **House** - Check utility bills and payments
            ❤️ **Health** - Log and track health metrics

            **Navigation:**
            • "Open calendar" / "Open tasks" / "Open finance"
            • "Go to health" / "Show settings"

            **Quick Actions:**
            • "What's on my calendar today?"
            • "Show my subscriptions"
            • "How's my budget doing?"
            • "Create task Buy groceries tomorrow"
            • "Log 8 hours of sleep"
            """,
            type: .capabilities
        )
    }

    func generateDefaultResponse() -> ChatMessage {
        ChatMessage(
            role: .assistant,
            content: "I'm Nexus AI - your personal life assistant! I can help with tasks, notes, calendar, finances, subscriptions, stocks, house utilities, and health tracking. Just ask me anything or say \"What can you do?\" for more details.",
            type: .text
        )
    }
}

// MARK: - Tasks Response

private extension AssistantView {
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
            return generateTodayTasksResponse(todayTasks)
        }

        if input.contains("overdue") || input.contains("late") {
            return generateOverdueTasksResponse(overdueTasks)
        }

        return generateTaskOverviewResponse(
            pending: pendingTasks.count,
            completed: completedTasks.count,
            today: todayTasks.count,
            overdue: overdueTasks.count,
            total: tasks.count
        )
    }

    func generateTodayTasksResponse(_ todayTasks: [TaskModel]) -> ChatMessage {
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

    func generateOverdueTasksResponse(_ overdueTasks: [TaskModel]) -> ChatMessage {
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

    func generateTaskOverviewResponse(pending: Int, completed: Int, today: Int, overdue: Int, total: Int) -> ChatMessage {
        let completionRate = total == 0 ? 0 : Int((Double(completed) / Double(total)) * 100)
        return ChatMessage(
            role: .assistant,
            content: "📊 **Task Overview**\n\n• **Pending:** \(pending) tasks\n• **Completed:** \(completed) tasks\n• **Due Today:** \(today) tasks\n• **Overdue:** \(overdue) tasks\n\nCompletion rate: **\(completionRate)%** \(completionRate >= 70 ? "🌟" : completionRate >= 50 ? "👍" : "💪")",
            type: .stats
        )
    }
}

// MARK: - Notes Response

private extension AssistantView {
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
}

// MARK: - Finance Response

private extension AssistantView {
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
}

// MARK: - Health Response

private extension AssistantView {
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

// MARK: - Subscriptions Response

private extension AssistantView {
    func generateSubscriptionsResponse(for input: String) -> ChatMessage {
        if subscriptions.isEmpty {
            return ChatMessage(role: .assistant, content: "You haven't added any subscriptions yet. Add your recurring services like Netflix, Spotify, or gym memberships in the Finance tab!", type: .text)
        }

        let activeSubscriptions = subscriptions.filter { $0.isActive }
        let monthlyTotal = activeSubscriptions.reduce(0.0) { $0 + $1.monthlyEquivalent }

        let subscriptionList = activeSubscriptions.prefix(5).map { "• \($0.name): \($0.formattedAmount)\($0.billingCycle.shortName)" }.joined(separator: "\n")

        return ChatMessage(
            role: .assistant,
            content: "🔄 **Subscriptions Summary**\n\n• **Active:** \(activeSubscriptions.count) subscriptions\n• **Monthly Cost:** ~\(formatCurrency(monthlyTotal))\n\n**Your Subscriptions:**\n\(subscriptionList)\(activeSubscriptions.count > 5 ? "\n...and \(activeSubscriptions.count - 5) more" : "")",
            type: .stats
        )
    }
}

// MARK: - Calendar Response

private extension AssistantView {
    func generateCalendarResponse(for input: String) async -> ChatMessage {
        guard calendarService.isAuthorized else {
            return ChatMessage(role: .assistant, content: "Calendar access is not authorized. Please enable calendar access in the Calendar tab to view your events.", type: .text)
        }

        do {
            let formatter = DateFormatter()
            formatter.timeStyle = .short

            if input.contains("today") || input.contains("schedule") {
                return try await generateTodayCalendarResponse(formatter: formatter)
            }

            if input.contains("tomorrow") {
                return try await generateTomorrowCalendarResponse(formatter: formatter)
            }

            if input.contains("week") || input.contains("upcoming") {
                return try await generateWeekCalendarResponse(formatter: formatter)
            }

            return try await generateDefaultCalendarResponse(formatter: formatter)

        } catch {
            return ChatMessage(
                role: .assistant,
                content: "📅 Couldn't fetch calendar events. Please make sure calendar access is enabled in Settings.",
                type: .text
            )
        }
    }

    func generateTodayCalendarResponse(formatter: DateFormatter) async throws -> ChatMessage {
        let events = try await calendarService.fetchTodayEvents()
        lastMentionedEvents = events

        if events.isEmpty {
            return ChatMessage(
                role: .assistant,
                content: "📅 **Today's Schedule**\n\nNo events scheduled for today. Enjoy your free day!",
                type: .text
            )
        }

        let allDayEvents = events.filter { $0.isAllDay }
        let timedEvents = events.filter { !$0.isAllDay }

        var response = "📅 **Today's Schedule** (\(events.count) events)\n\n"

        if !allDayEvents.isEmpty {
            response += "**All Day:**\n"
            for (index, event) in allDayEvents.enumerated() {
                response += "\(index + 1). \(event.title)\n"
            }
            response += "\n"
        }

        if !timedEvents.isEmpty {
            response += "**Scheduled:**\n"
            let startIndex = allDayEvents.count
            for (index, event) in timedEvents.prefix(8).enumerated() {
                let time = formatter.string(from: event.startDate)
                let location = event.location.map { " 📍 \($0)" } ?? ""
                response += "\(startIndex + index + 1). **\(time)** - \(event.title)\(location)\n"
            }
            if timedEvents.count > 8 {
                response += "\n...and \(timedEvents.count - 8) more events"
            }
        }

        response += "\n💡 *Say \"open 1\" or \"open [event name]\" to view details*"

        return ChatMessage(role: .assistant, content: response, type: .stats)
    }

    func generateTomorrowCalendarResponse(formatter: DateFormatter) async throws -> ChatMessage {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let dayAfter = calendar.date(byAdding: .day, value: 1, to: tomorrow)!
        let events = try await calendarService.fetchEvents(from: tomorrow, to: dayAfter)
        lastMentionedEvents = events

        if events.isEmpty {
            return ChatMessage(role: .assistant, content: "📅 **Tomorrow's Schedule**\n\nNo events scheduled for tomorrow.", type: .text)
        }

        var response = "📅 **Tomorrow's Schedule** (\(events.count) events)\n\n"
        for (index, event) in events.prefix(8).enumerated() {
            if event.isAllDay {
                response += "\(index + 1). **All Day** - \(event.title)\n"
            } else {
                let time = formatter.string(from: event.startDate)
                response += "\(index + 1). **\(time)** - \(event.title)\n"
            }
        }
        if events.count > 8 {
            response += "\n...and \(events.count - 8) more events"
        }

        response += "\n💡 *Say \"open 1\" or \"open [event name]\" to view details*"

        return ChatMessage(role: .assistant, content: response, type: .stats)
    }

    func generateWeekCalendarResponse(formatter: DateFormatter) async throws -> ChatMessage {
        let events = try await calendarService.fetchUpcomingEvents(days: 7)
        lastMentionedEvents = events

        if events.isEmpty {
            return ChatMessage(role: .assistant, content: "📅 **This Week**\n\nNo events scheduled for the next 7 days.", type: .text)
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMM d"

        let grouped = Dictionary(grouping: events) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }

        var response = "📅 **Upcoming Events** (\(events.count) this week)\n\n"
        var eventIndex = 1
        for date in grouped.keys.sorted().prefix(5) {
            let dayEvents = grouped[date] ?? []
            response += "**\(dayFormatter.string(from: date)):**\n"
            for event in dayEvents.prefix(3) {
                if event.isAllDay {
                    response += "\(eventIndex). \(event.title)\n"
                } else {
                    let time = formatter.string(from: event.startDate)
                    response += "\(eventIndex). \(time) - \(event.title)\n"
                }
                eventIndex += 1
            }
            if dayEvents.count > 3 {
                response += "  ...+\(dayEvents.count - 3) more\n"
            }
            response += "\n"
        }

        response += "💡 *Say \"open 1\" or \"open [event name]\" to view details*"

        return ChatMessage(role: .assistant, content: response, type: .stats)
    }

    func generateDefaultCalendarResponse(formatter: DateFormatter) async throws -> ChatMessage {
        let events = try await calendarService.fetchTodayEvents()
        lastMentionedEvents = events

        if events.isEmpty {
            return ChatMessage(
                role: .assistant,
                content: "📅 **Calendar**\n\nNo events today. Ask me about \"tomorrow's events\" or \"this week's schedule\" for upcoming events!",
                type: .text
            )
        }

        var response = "📅 **Today** (\(events.count) events)\n\n"
        for (index, event) in events.prefix(5).enumerated() {
            if event.isAllDay {
                response += "\(index + 1). **All Day** - \(event.title)\n"
            } else {
                let time = formatter.string(from: event.startDate)
                response += "\(index + 1). **\(time)** - \(event.title)\n"
            }
        }
        if events.count > 5 {
            response += "\n...and \(events.count - 5) more events"
        }

        response += "\n💡 *Say \"open 1\" or \"open [event name]\" to view details*"

        return ChatMessage(role: .assistant, content: response, type: .stats)
    }
}

// MARK: - Budget Response

private extension AssistantView {
    func generateBudgetResponse(for input: String) -> ChatMessage {
        if budgets.isEmpty {
            return ChatMessage(role: .assistant, content: "You haven't created any budgets yet. Set up budgets in the Finance tab to track your spending by category!", type: .text)
        }

        let activeBudgets = budgets.filter { $0.isActive }
        var budgetSummary = "📊 **Budget Overview**\n\n"

        for budget in activeBudgets.prefix(5) {
            let spent = calculateSpentForBudget(budget)
            let limit = budget.effectiveBudget
            let percentage = limit > 0 ? min(100, Int((spent / limit) * 100)) : 0
            let remaining = max(0, limit - spent)
            let status = percentage >= 100 ? "🔴" : percentage >= 80 ? "🟡" : "🟢"
            budgetSummary += "\(status) **\(budget.name):** \(formatCurrency(spent)) / \(formatCurrency(limit)) (\(percentage)%)\n"
            budgetSummary += "   Remaining: \(formatCurrency(remaining)) • \(budget.daysRemaining) days left\n\n"
        }

        if activeBudgets.count > 5 {
            budgetSummary += "...and \(activeBudgets.count - 5) more budgets"
        }

        return ChatMessage(role: .assistant, content: budgetSummary, type: .stats)
    }

    func calculateSpentForBudget(_ budget: BudgetModel) -> Double {
        transactions
            .filter { $0.type == .expense }
            .filter { $0.category == budget.category }
            .filter { $0.date >= budget.currentPeriodStart && $0.date <= budget.currentPeriodEnd }
            .reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Stocks Response

private extension AssistantView {
    func generateStocksResponse(for input: String) -> ChatMessage {
        if stocks.isEmpty {
            return ChatMessage(role: .assistant, content: "You haven't added any stocks to your portfolio yet. Track your investments by adding stocks in the Finance > Stocks section!", type: .text)
        }

        let totalCost = stocks.reduce(0.0) { $0 + $1.totalCost }

        let stockList = stocks.prefix(5).map { stock in
            "📊 **\(stock.symbol):** \(Int(stock.quantity)) shares @ \(formatCurrency(stock.averageCostPerShare))"
        }.joined(separator: "\n")

        return ChatMessage(
            role: .assistant,
            content: "📊 **Portfolio Summary**\n\n💰 **Total Invested:** \(formatCurrency(totalCost))\n📈 **Holdings:** \(stocks.count) stocks\n\n**Your Stocks:**\n\(stockList)\(stocks.count > 5 ? "\n...and \(stocks.count - 5) more" : "")\n\n*Note: Live prices are available in the Stocks section.*",
            type: .stats
        )
    }
}

// MARK: - House Response

private extension AssistantView {
    func generateHouseResponse(for input: String) -> ChatMessage {
        if houses.isEmpty {
            return ChatMessage(role: .assistant, content: "You haven't added any properties yet. Add your house or apartment in the Finance > House section to track utility bills!", type: .text)
        }

        var houseSummary = "🏠 **Properties Overview**\n\n"

        for house in houses.prefix(3) {
            houseSummary += "**\(house.name)**\n"
            if !house.address.isEmpty {
                houseSummary += "📍 \(house.address)\n"
            }

            if let utilities = house.utilities, !utilities.isEmpty {
                let utilityList = utilities.prefix(3).map { "• \($0.provider)" }.joined(separator: "\n")
                houseSummary += "\(utilityList)\n"
            }
            houseSummary += "\n"
        }

        if houses.count > 3 {
            houseSummary += "...and \(houses.count - 3) more properties"
        }

        return ChatMessage(role: .assistant, content: houseSummary, type: .stats)
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

    func parseSubscriptionAction(input: String, lowercased: String) -> ChatMessage? {
        let createPatterns = ["add subscription", "new subscription", "subscribe to", "create subscription"]
        for pattern in createPatterns {
            if lowercased.contains(pattern) {
                let extracted = extractContent(from: input, after: pattern)
                if !extracted.isEmpty { return createSubscription(from: extracted, input: lowercased) }
            }
        }
        return nil
    }
}

// MARK: - Open Action Parsing

private extension AssistantView {
    func parseOpenAction(lowercased: String) -> ChatMessage? {
        let openPatterns = ["open ", "go to ", "show me ", "take me to ", "navigate to ", "switch to ", "view "]

        for pattern in openPatterns {
            guard lowercased.contains(pattern) else { continue }

            if let eventResult = tryOpenEventByNumber(lowercased) { return eventResult }
            if let eventResult = tryOpenEventByName(lowercased) { return eventResult }

            if lowercased.contains("that") || lowercased.contains(" it") || lowercased.contains("first") || lowercased.contains("last") {
                if let eventResult = tryOpenContextualEvent(lowercased) { return eventResult }
            }

            return parseNavigationDestination(lowercased)
        }

        return nil
    }

    func parseNavigationDestination(_ lowercased: String) -> ChatMessage? {
        if lowercased.contains("calendar") || lowercased.contains("schedule") || lowercased.contains("events") {
            navigateAndDismiss(to: .calendar)
            return ChatMessage(role: .assistant, content: "📅 Opening Calendar...", type: .action(icon: "calendar", label: "Open Calendar"))
        }

        if lowercased.contains("task") || lowercased.contains("todo") || lowercased.contains("to-do") {
            navigateAndDismiss(to: .tab(.tasks))
            return ChatMessage(role: .assistant, content: "✅ Opening Tasks...", type: .action(icon: "checkmark.circle", label: "Open Tasks"))
        }

        if lowercased.contains("finance") || lowercased.contains("money") || lowercased.contains("budget") ||
           lowercased.contains("expense") || lowercased.contains("transaction") {
            navigateAndDismiss(to: .tab(.finance))
            return ChatMessage(role: .assistant, content: "💰 Opening Finance...", type: .action(icon: "creditcard", label: "Open Finance"))
        }

        if lowercased.contains("subscription") {
            navigateAndDismiss(to: .tab(.finance))
            return ChatMessage(role: .assistant, content: "🔄 Opening Subscriptions...", type: .action(icon: "arrow.triangle.2.circlepath", label: "Open Subscriptions"))
        }

        if lowercased.contains("stock") || lowercased.contains("portfolio") || lowercased.contains("investment") {
            navigateAndDismiss(to: .tab(.finance))
            return ChatMessage(role: .assistant, content: "📈 Opening Stocks...", type: .action(icon: "chart.line.uptrend.xyaxis", label: "Open Stocks"))
        }

        if lowercased.contains("health") || lowercased.contains("wellness") || lowercased.contains("fitness") {
            navigateAndDismiss(to: .tab(.health))
            return ChatMessage(role: .assistant, content: "❤️ Opening Health...", type: .action(icon: "heart", label: "Open Health"))
        }

        if lowercased.contains("home") || lowercased.contains("dashboard") {
            navigateAndDismiss(to: .tab(.home))
            return ChatMessage(role: .assistant, content: "🏠 Opening Home...", type: .action(icon: "house", label: "Open Home"))
        }

        if lowercased.contains("note") {
            navigateAndDismiss(to: .tab(.home))
            return ChatMessage(role: .assistant, content: "📝 Opening Notes...", type: .action(icon: "doc.text", label: "Open Notes"))
        }

        if lowercased.contains("setting") {
            navigateAndDismiss(to: .settings)
            return ChatMessage(role: .assistant, content: "⚙️ Opening Settings...", type: .action(icon: "gear", label: "Open Settings"))
        }

        if lowercased.contains("house") || lowercased.contains("property") || lowercased.contains("utilit") {
            navigateAndDismiss(to: .tab(.finance))
            return ChatMessage(role: .assistant, content: "🏠 Opening House...", type: .action(icon: "house", label: "Open House"))
        }

        return nil
    }

    func tryOpenEventByNumber(_ input: String) -> ChatMessage? {
        guard !lastMentionedEvents.isEmpty else { return nil }

        let pattern = #"(?:open|show|view)\s*(?:event|number|#)?\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
              let range = Range(match.range(at: 1), in: input),
              let number = Int(input[range]) else {
            return nil
        }

        let index = number - 1
        guard index >= 0, index < lastMentionedEvents.count else {
            return ChatMessage(
                role: .assistant,
                content: "I couldn't find event #\(number). There are \(lastMentionedEvents.count) events in the list.",
                type: .text
            )
        }

        let event = lastMentionedEvents[index]
        selectedEventToShow = event
        return ChatMessage(
            role: .assistant,
            content: "📅 Opening **\(event.title)**...",
            type: .action(icon: "calendar", label: "Open Event")
        )
    }

    func tryOpenEventByName(_ input: String) -> ChatMessage? {
        guard !lastMentionedEvents.isEmpty else { return nil }

        for event in lastMentionedEvents {
            let titleLowercased = event.title.lowercased()
            let words = titleLowercased.split(separator: " ").map(String.init)

            for word in words where word.count > 3 {
                if input.contains(word) {
                    selectedEventToShow = event
                    return ChatMessage(
                        role: .assistant,
                        content: "📅 Opening **\(event.title)**...",
                        type: .action(icon: "calendar", label: "Open Event")
                    )
                }
            }
        }

        return nil
    }

    func tryOpenContextualEvent(_ input: String) -> ChatMessage? {
        guard !lastMentionedEvents.isEmpty else { return nil }

        let event: CalendarEvent?
        if input.contains("last") {
            event = lastMentionedEvents.last
        } else {
            event = lastMentionedEvents.first
        }

        if let event {
            selectedEventToShow = event
            return ChatMessage(
                role: .assistant,
                content: "📅 Opening **\(event.title)**...",
                type: .action(icon: "calendar", label: "Open Event")
            )
        }

        return nil
    }
}

// MARK: - Create Actions

private extension AssistantView {
    func createSubscription(from content: String, input: String) -> ChatMessage {
        var name = content
        var amount: Double = 0

        if let dollarIndex = input.firstIndex(of: "$") {
            let afterDollar = input[input.index(after: dollarIndex)...]
            if let value = Double(afterDollar.prefix(while: { $0.isNumber || $0 == "." })) {
                amount = value
            }
        } else if let value = extractNumber(from: input) {
            amount = value
        }

        let wordsToRemove = ["for $", " $"]
        for word in wordsToRemove {
            if let range = name.lowercased().range(of: word) {
                name = String(name[..<range.lowerBound])
            }
        }
        name = name.trimmingCharacters(in: .whitespaces)

        let subscription = SubscriptionModel(
            name: name,
            amount: amount,
            billingCycle: .monthly,
            category: .other
        )
        modelContext.insert(subscription)

        return ChatMessage(
            role: .assistant,
            content: "🔄 **Subscription Added!**\n\n**\(name)**\n💰 \(amount > 0 ? formatCurrency(amount) + "/month" : "Amount not set")\n\nYou can edit the details in the Subscriptions section.",
            type: .text
        )
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

// MARK: - Preview

#Preview {
    AssistantView()
        .preferredColorScheme(.dark)
}
