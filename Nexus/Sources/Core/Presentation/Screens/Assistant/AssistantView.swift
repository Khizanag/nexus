import SwiftUI
import SwiftData

struct AssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatMessageModel.timestamp, order: .forward) private var messages: [ChatMessageModel]

    @State private var assistant: NexusAssistant?
    @State private var inputText = ""
    @State private var streamingText = ""
    @State private var isStreaming = false
    @State private var showCapabilities = false
    @State private var showFallbackNote = true
    @State private var speech = SpeechRecognitionService()
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "What are my tasks?",
        "Add task: buy groceries tomorrow",
        "How much did I spend this month?",
        "Log 500 ml of water",
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                content
            }
            .navigationTitle("Nexus AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { composer }
            .sheet(isPresented: $showCapabilities) { CapabilitiesView() }
            .task { await setupAssistant() }
            .onChange(of: speech.transcribedText) { _, newValue in
                if !newValue.isEmpty { inputText = newValue }
            }
            .alert("Voice Input", isPresented: voiceErrorBinding) {
                Button("OK") { speech.errorMessage = nil }
            } message: {
                if let error = speech.errorMessage { Text(error) }
            }
        }
    }
}

// MARK: - Toolbar

private extension AssistantView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("What can you do?", systemImage: "sparkles") { showCapabilities = true }
                if !messages.isEmpty {
                    Button("Clear Chat", systemImage: "trash", role: .destructive) { clearChat() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More options")
        }
    }
}

// MARK: - Content

private extension AssistantView {
    @ViewBuilder
    var content: some View {
        if messages.isEmpty, !isStreaming {
            welcome
        } else {
            chatList
        }
    }

    var welcome: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                AIAvatarView()
                    .padding(.top, DesignSystem.Spacing.xl)

                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Hey, I'm Nexus")
                        .font(.nexusTitle)
                    Text("Ask about your tasks, health, and money — or tell me to log something.")
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        AssistantSuggestionChip(text: suggestion) { send(suggestion) }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }

    var chatList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(messages) { message in
                    MessageBubble(
                        isUser: message.role == "user",
                        text: message.content,
                        timestamp: message.timestamp
                    )
                    .listRowChrome()
                }

                if isStreaming {
                    streamingRow.listRowChrome()
                }

                Color.clear
                    .frame(height: 1)
                    .id("bottom")
                    .listRowChrome()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages.count) { scrollToBottom(proxy) }
            .onChange(of: streamingText) { scrollToBottom(proxy) }
        }
    }

    @ViewBuilder
    var streamingRow: some View {
        if streamingText.isEmpty {
            TypingIndicator()
        } else {
            MessageBubble(isUser: false, text: streamingText)
        }
    }

    func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

// MARK: - Composer

private extension AssistantView {
    var composer: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            if let notice = assistant?.fallbackNotice, showFallbackNote {
                fallbackBanner(notice)
            }
            inputBar
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.xs)
    }

    func fallbackBanner(_ text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "info.circle")
            Text(text).font(.nexusCaption)
            Spacer(minLength: 0)
            Button {
                withAnimation { showFallbackNote = false }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .glassBackground(in: .capsule)
    }

    var inputBar: some View {
        GlassEffectContainer(spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Button {
                    speech.toggleRecording()
                } label: {
                    Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                        .frame(width: DesignSystem.Size.Button.tap, height: DesignSystem.Size.Button.tap)
                }
                .buttonStyle(.glass)
                .tint(speech.isRecording ? .nexusRed : nil)
                .accessibilityLabel(speech.isRecording ? "Stop recording" : "Record voice")

                TextField(speech.isRecording ? "Listening…" : "Message Nexus", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, 10)
                    .glassBackground(in: .capsule)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .disabled(speech.isRecording)

                Button {
                    send(inputText)
                } label: {
                    Image(systemName: "arrow.up")
                        .fontWeight(.bold)
                        .frame(width: DesignSystem.Size.Button.tap, height: DesignSystem.Size.Button.tap)
                }
                .buttonStyle(.glassProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isStreaming)
                .accessibilityLabel("Send")
            }
        }
    }

    var voiceErrorBinding: Binding<Bool> {
        Binding(
            get: { speech.errorMessage != nil },
            set: { if !$0 { speech.errorMessage = nil } }
        )
    }
}

// MARK: - Actions

private extension AssistantView {
    func setupAssistant() async {
        guard assistant == nil else { return }
        let store = NexusStore(modelContainer: modelContext.container)
        assistant = NexusAssistant(store: store)
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let assistant, !isStreaming else { return }

        inputText = ""
        inputFocused = false
        if speech.isRecording { speech.toggleRecording() }

        modelContext.insert(ChatMessageModel(role: "user", content: trimmed))
        try? modelContext.save()

        streamingText = ""
        isStreaming = true

        Task { @MainActor in
            let reply = await assistant.send(trimmed) { partial in
                streamingText = partial
            }
            modelContext.insert(ChatMessageModel(role: "assistant", content: reply))
            try? modelContext.save()
            isStreaming = false
            streamingText = ""
        }
    }

    func clearChat() {
        for message in messages {
            modelContext.delete(message)
        }
        try? modelContext.save()
    }
}

// MARK: - Row Chrome

private extension View {
    /// Transparent, separator-free list rows so chat bubbles sit on the gradient background.
    func listRowChrome() -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }
}

// MARK: - Preview

#Preview {
    AssistantView()
        .modelContainer(for: ChatMessageModel.self, inMemory: true)
}
