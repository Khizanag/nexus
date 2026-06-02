import AVFoundation
import SwiftUI

// MARK: - Speech Manager (singleton to retain the synthesizer)

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
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - AI Avatar

struct AIAvatarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.nexusPurple.opacity(0.35 - Double(index) * 0.1), lineWidth: 1.5)
                    .frame(width: 92 + CGFloat(index * 26), height: 92 + CGFloat(index * 26))
                    .rotationEffect(.degrees(rotation + Double(index * 30)))
                    .opacity(animating ? 0.9 : 0.5)
            }

            Circle()
                .fill(Color.nexusGradient)
                .frame(width: 82, height: 82)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.nexusOnAccent)
                        .scaleEffect(animating ? 1.08 : 1)
                }
                .shadow(color: .nexusPurple.opacity(0.4), radius: 18, y: 8)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { animating = true }
            withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) { rotation = 360 }
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
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: DesignSystem.Size.Icon.badge, height: DesignSystem.Size.Icon.badge)
                .background(color.opacity(0.15), in: .circle)

            Text(value).font(.nexusTitle3)
            Text(label).font(.nexusCaption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let isUser: Bool
    let text: String
    var timestamp: Date?

    var body: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.xs) {
            if isUser { Spacer(minLength: 48) }
            if !isUser { avatar }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubble
                if let timestamp {
                    Text(timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.nexusCaption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
            }

            if !isUser { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? "You said" : "Nexus said")
        .accessibilityValue(text)
    }

    private var bubble: some View {
        Text(.init(text))
            .font(.nexusCallout)
            .foregroundStyle(isUser ? Color.nexusOnAccent : .primary)
            .textSelection(.enabled)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .modifier(BubbleBackground(isUser: isUser))
    }

    private var avatar: some View {
        Image(systemName: "sparkles")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.nexusOnAccent)
            .frame(width: DesignSystem.Size.Avatar.sm, height: DesignSystem.Size.Avatar.sm)
            .background(Color.nexusGradient, in: .circle)
            .accessibilityHidden(true)
    }
}

private struct BubbleBackground: ViewModifier {
    let isUser: Bool

    func body(content: Content) -> some View {
        if isUser {
            content.background(
                Color.nexusGradient,
                in: .rect(cornerRadius: 20, style: .continuous)
            )
        } else {
            content.glassBackground(in: .rect(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.nexusOnAccent)
                .frame(width: DesignSystem.Size.Avatar.sm, height: DesignSystem.Size.Avatar.sm)
                .background(Color.nexusGradient, in: .circle)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.2 : 0.7)
                        .opacity(animating ? 1 : 0.4)
                        .animation(
                            reduceMotion ? nil :
                                .easeInOut(duration: 0.5).repeatForever().delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .glassBackground(in: .rect(cornerRadius: 20, style: .continuous))

            Spacer(minLength: 48)
        }
        .onAppear { animating = true }
        .accessibilityLabel("Nexus is typing")
    }
}

// MARK: - Suggestion Chip

struct AssistantSuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(text, systemImage: "sparkle")
                .font(.nexusSubheadline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.glass)
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        LinearGradient(
            colors: [
                Color.nexusBackground,
                Color.nexusPurple.opacity(0.06),
                Color.nexusBlue.opacity(0.04),
                Color.nexusBackground,
            ],
            startPoint: animate ? .topLeading : .bottomTrailing,
            endPoint: animate ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { animate.toggle() }
        }
    }
}
