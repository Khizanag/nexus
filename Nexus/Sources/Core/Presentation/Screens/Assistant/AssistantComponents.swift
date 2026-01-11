import AVFoundation
import SwiftUI

// MARK: - Speech Manager (Singleton to retain synthesizer)

@MainActor
final class SpeechManager {
    static let shared = SpeechManager()
    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - AI Avatar View

struct AIAvatarView: View {
    @State private var isAnimating = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .nexusPurple.opacity(0.4 - Double(index) * 0.1),
                                .nexusBlue.opacity(0.3 - Double(index) * 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 90 + CGFloat(index * 25), height: 90 + CGFloat(index * 25))
                    .rotationEffect(.degrees(rotation + Double(index * 30)))
                    .opacity(isAnimating ? 0.8 : 0.4)
            }

            // Glass orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .nexusPurple.opacity(0.9),
                            .nexusBlue.opacity(0.8),
                            .nexusPurple.opacity(0.7)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 80, height: 80)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .frame(width: 80, height: 80)
                }
                .shadow(color: .nexusPurple.opacity(0.5), radius: 20, x: 0, y: 10)

            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.5), radius: 10)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
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
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    @State private var showCopied = false
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 60) }

            if message.role == .assistant {
                assistantAvatar
                    .offset(y: -4)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                messageContent
                    .contextMenu {
                        Button {
                            copyMessage()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        if message.role == .assistant {
                            Button {
                                SpeechManager.shared.speak(message.content)
                            } label: {
                                Label("Speak", systemImage: "speaker.wave.2")
                            }
                        }
                    }

                HStack(spacing: 4) {
                    if showCopied {
                        Label("Copied", systemImage: "checkmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.nexusGreen)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if message.role == .user {
            userBubble
        } else {
            assistantBubble
        }
    }

    private var userBubble: some View {
        Text(.init(message.content))
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                BubbleShape(isUser: true)
                    .fill(
                        LinearGradient(
                            colors: [.nexusPurple, .nexusPurple.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .nexusPurple.opacity(0.3), radius: 8, x: 0, y: 4)
            }
    }

    private var assistantBubble: some View {
        Text(.init(message.content))
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                BubbleShape(isUser: false)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        BubbleShape(isUser: false)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
    }

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.nexusPurple, .nexusBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .shadow(color: .nexusPurple.opacity(0.4), radius: 6, x: 0, y: 3)

            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func copyMessage() {
        UIPasteboard.general.string = message.content
        withAnimation(.spring(response: 0.3)) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                showCopied = false
            }
        }
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6

        var path = Path()

        if isUser {
            // User bubble - tail on right
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - tailSize))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius + tailSize, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            // Assistant bubble - tail on left
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + radius - tailSize, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius - tailSize),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Suggestion Button

struct SuggestionButton: View {
    let text: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.nexusPurple, .nexusBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.nexusPurple, .nexusBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: .nexusPurple.opacity(0.4), radius: 6, x: 0, y: 3)

                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Dots
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.nexusPurple, .nexusBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.2 : 0.8)
                        .opacity(animating ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                BubbleShape(isUser: false)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        BubbleShape(isUser: false)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
            }
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                Color.nexusBackground,
                Color.nexusPurple.opacity(0.05),
                Color.nexusBlue.opacity(0.03),
                Color.nexusBackground
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}
