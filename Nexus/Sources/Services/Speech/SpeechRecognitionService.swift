import Foundation
import Speech
import AVFoundation
import Observation

@Observable
@MainActor
final class SpeechRecognitionService {
    var transcribedText: String = ""
    var isRecording: Bool = false
    var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func startRecording() {
        #if targetEnvironment(simulator)
        errorMessage = "Voice input requires a physical device."
        return
        #else

        guard !isRecording else { return }

        Task {
            // Request permissions
            let speechAuthorized = await requestSpeechAuthorization()
            let micAuthorized = await requestMicrophoneAuthorization()

            guard speechAuthorized && micAuthorized else {
                errorMessage = "Please allow microphone and speech recognition in Settings"
                return
            }

            guard let speechRecognizer, speechRecognizer.isAvailable else {
                errorMessage = "Speech recognition not available"
                return
            }

            do {
                try configureAudioSession()
                try startRecognition(with: speechRecognizer)
                isRecording = true
                errorMessage = nil
            } catch {
                errorMessage = "Failed to start: \(error.localizedDescription)"
                cleanup()
            }
        }
        #endif
    }

    func stopRecording() {
        guard isRecording else { return }
        cleanup()
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func cleanup() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition(with recognizer: SFSpeechRecognizer) throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let engine = AVAudioEngine()
        audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw SpeechError.audioEngineUnavailable
        }

        // Capture request locally to avoid accessing self from audio thread
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let result {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self.cleanup()
                }
            }
        }

        engine.prepare()
        try engine.start()
        transcribedText = ""
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
