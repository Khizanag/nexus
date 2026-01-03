import SwiftUI

struct AssistantView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false

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
                        Button("Clear Chat", systemImage: "trash") {
                            messages.removeAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 40)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.nexusPurple.opacity(0.3), .nexusBlue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.nexusGradient)
                }

                VStack(spacing: 8) {
                    Text("How can I help?")
                        .font(.nexusTitle2)

                    Text("Ask me anything about your notes, tasks, finances, or health data")
                        .font(.nexusSubheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        SuggestionButton(text: suggestion) {
                            inputText = suggestion
                            sendMessage()
                        }
                    }
                }
                .padding(.top, 16)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if isLoading {
                        HStack {
                            TypingIndicator()
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) {
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask anything...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.nexusSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.nexusBorder, lineWidth: 1)
                        }
                }
                .focused($isInputFocused)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        inputText.isEmpty ? Color.secondary : Color.nexusPurple
                    )
            }
            .disabled(inputText.isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }

    private var suggestions: [String] {
        [
            "Summarize my notes from this week",
            "What tasks are due today?",
            "How much did I spend this month?",
            "Show my health trends"
        ]
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)
        let currentInput = inputText
        inputText = ""
        isLoading = true

        Task {
            try? await Task.sleep(for: .seconds(1))

            let response = generateMockResponse(for: currentInput)
            let assistantMessage = ChatMessage(role: .assistant, content: response)

            await MainActor.run {
                messages.append(assistantMessage)
                isLoading = false
            }
        }
    }

    private func generateMockResponse(for input: String) -> String {
        let lowercased = input.lowercased()

        if lowercased.contains("task") || lowercased.contains("due") {
            return "I found 3 tasks due today. Would you like me to show them or help prioritize?"
        } else if lowercased.contains("note") || lowercased.contains("summarize") {
            return "You have 5 notes from this week. The main topics covered are project planning, meeting notes, and personal ideas."
        } else if lowercased.contains("spend") || lowercased.contains("finance") || lowercased.contains("money") {
            return "This month you've spent $1,234.56. Your biggest category is Food & Dining at $345.00. Want a detailed breakdown?"
        } else if lowercased.contains("health") || lowercased.contains("trend") {
            return "Your health trends look good! Average sleep: 7.2 hours, Daily steps average: 8,500. Your water intake could use improvement."
        } else {
            return "I understand you're asking about \"\(input)\". As your AI assistant, I can help you manage notes, tasks, finances, and health data. What would you like to know more about?"
        }
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date = .now

    enum Role {
        case user, assistant
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.nexusBody)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user ? Color.nexusPurple : Color.nexusSurface)
                    }
                    .foregroundStyle(message.role == .user ? .white : .primary)

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.nexusCaption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant { Spacer() }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Suggestion Button

private struct SuggestionButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.nexusSubheadline)
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
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1 : 0.5)
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
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    AssistantView()
        .preferredColorScheme(.dark)
}
