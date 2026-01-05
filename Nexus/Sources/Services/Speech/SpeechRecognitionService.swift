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

    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    @MainActor private var audioEngine: AVAudioEngine?
    @MainActor private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @MainActor private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?
    private var hasCheckedAuthorization = false

    nonisolated init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    @MainActor
    func checkAuthorizationIfNeeded() {
        guard !hasCheckedAuthorization else { return }
        hasCheckedAuthorization = true

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }

    @MainActor
    func startRecording() {
        #if targetEnvironment(simulator)
        errorMessage = "Voice input requires a physical device. Simulator does not support microphone."
        return
        #endif

        checkAuthorizationIfNeeded()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition not available"
            return
        }

        do {
            try startAudioSession()
            try setupRecognition()
            isRecording = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            isRecording = false
        }
    }

    @MainActor
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    private func startAudioSession() throws {
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
        recognitionRequest.addsPunctuation = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.channelCount > 0 else {
            throw SpeechError.audioEngineUnavailable
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.recognitionRequest?.append(buffer)
            }
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }

                if error != nil || (result?.isFinal == true) {
                    self?.stopRecording()
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
