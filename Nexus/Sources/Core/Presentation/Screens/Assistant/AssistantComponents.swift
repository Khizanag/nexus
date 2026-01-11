import AVFoundation
import SwiftUI

// MARK: - AI Avatar View

struct AIAvatarView: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
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

struct QuickStatItem: View {
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

struct MessageBubble: View {
    let message: ChatMessage
    var onOpenAction: ((String) -> Void)?

    @State private var showCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user { Spacer(minLength: 50) }

            if message.role == .assistant {
                assistantAvatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(.init(message.content))
                    .font(.system(size: 14, weight: .regular))
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        bubbleBackground
                    }
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .contextMenu {
                        Button {
                            copyMessage()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        if message.role == .assistant {
                            Button {
                                speakMessage()
                            } label: {
                                Label("Speak", systemImage: "speaker.wave.2")
                            }
                        }
                    }
                    .overlay(alignment: .top) {
                        if showCopied {
                            Text("Copied!")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background {
                                    Capsule().fill(Color.nexusGreen)
                                }
                                .offset(y: -28)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    private func copyMessage() {
        UIPasteboard.general.string = message.content
        withAnimation(.spring(response: 0.3)) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3)) {
                showCopied = false
            }
        }
    }

    private func speakMessage() {
        let utterance = AVSpeechUtterance(string: message.content)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}

private extension MessageBubble {
    var assistantAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.nexusPurple, .nexusBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 26, height: 26)
            .overlay {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: .nexusPurple.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    var bubbleBackground: some View {
        if message.role == .user {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [.nexusPurple, .nexusPurple.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .nexusPurple.opacity(0.2), radius: 4, x: 0, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 18)
                .fill(bubbleColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.nexusBorder.opacity(0.5), lineWidth: 0.5)
                }
        }
    }

    var bubbleColor: Color {
        if message.role == .user {
            return .nexusPurple
        }

        switch message.type {
        case .taskCreated, .noteCreated, .taskCompleted, .healthLogged:
            return Color.nexusGreen.opacity(0.12)
        case .stats, .taskList, .notesSummary, .financeSummary, .healthSummary:
            return Color.nexusSurface.opacity(0.8)
        case .action:
            return Color.nexusPurple.opacity(0.1)
        default:
            return Color.nexusSurface
        }
    }
}

// MARK: - Suggestion Button

struct SuggestionButton: View {
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

struct TypingIndicator: View {
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
