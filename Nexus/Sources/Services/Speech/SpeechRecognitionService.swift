import Foundation
import Speech
import AVFoundation
import Observation

@Observable
final class SpeechRecognitionService: @unchecked Sendable {
    @MainActor var transcribedText: String = ""
    @MainActor var isRecording: Bool = false
    @MainActor var isAuthorized: Bool = false
    @MainActor var errorMessage: String?

    @MainActor private var audioEngine: AVAudioEngine?
    @MainActor private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @MainActor private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?

    nonisolated init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    @MainActor
    func requestAuthorization() async {
        // Request speech recognition authorization
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        // Request microphone authorization
        let micStatus: Bool
        if #available(iOS 17.0, *) {
            micStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            micStatus = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        isAuthorized = speechStatus == .authorized && micStatus
    }

    @MainActor
    func startRecording() {
        #if targetEnvironment(simulator)
        errorMessage = "Voice input requires a physical device. Simulator does not support microphone."
        return
        #else

        // Check if already recording
        guard !isRecording else { return }

        // Check authorization first
        Task {
            await requestAuthorization()

            guard isAuthorized else {
                errorMessage = "Please allow microphone and speech recognition access in Settings"
                return
            }

            guard let speechRecognizer, speechRecognizer.isAvailable else {
                errorMessage = "Speech recognition not available"
                return
            }

            do {
                try await startAudioSession()
                try setupRecognition()
                isRecording = true
                errorMessage = nil
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
                isRecording = false
            }
        }
        #endif
    }

    @MainActor
    func stopRecording() {
        guard isRecording else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        // Deactivate audio session
        Task.detached {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func startAudioSession() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    @MainActor
    private func setupRecognition() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        audioEngine = AVAudioEngine()
        guard let audioEngine else { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw SpeechError.requestUnavailable
        }

        recognitionRequest.shouldReportPartialResults = true
        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            throw SpeechError.audioEngineUnavailable
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if error != nil || (result?.isFinal == true) {
                    self.stopRecording()
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        transcribedText = ""
    }

    @MainActor
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}

enum SpeechError: LocalizedError {
    case requestUnavailable
    case audioEngineUnavailable

    var errorDescription: String? {
        switch self {
        case .requestUnavailable:
            return "Speech recognition request unavailable"
        case .audioEngineUnavailable:
            return "Audio engine unavailable"
        }
    }
}
