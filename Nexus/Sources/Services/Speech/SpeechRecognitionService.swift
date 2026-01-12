import Foundation
import Speech
import AVFoundation
import Observation

@Observable
final class SpeechRecognitionService: @unchecked Sendable {
    @MainActor var transcribedText: String = ""
    @MainActor var isRecording: Bool = false
    @MainActor var errorMessage: String?

    // Audio resources - accessed from audio thread
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    @MainActor private var silenceTimer: Timer?

    nonisolated init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    @MainActor
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task {
                await startRecording()
            }
        }
    }

    @MainActor
    func startRecording() async {
        #if targetEnvironment(simulator)
        errorMessage = "Voice input requires a physical device"
        return
        #else

        guard !isRecording else { return }

        // Request speech authorization
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition not authorized. Please enable in Settings."
            return
        }

        // Request microphone authorization
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micGranted else {
            errorMessage = "Microphone access denied. Please enable in Settings."
            return
        }

        // Start the actual recording
        beginRecordingSession()
        #endif
    }

    @MainActor
    private func beginRecordingSession() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition not available on this device"
            return
        }

        // Clean up any previous session
        cleanupResources()

        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Create audio engine
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode

            // Get and validate audio format
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            // Validate format - this is crucial for real devices
            guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                errorMessage = "Invalid audio format. Please try again."
                try? audioSession.setActive(false)
                return
            }

            // Create recognition request
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true

            // Store request before installing tap
            self.recognitionRequest = request
            self.audioEngine = engine

            // Install audio tap - this callback runs on audio thread
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                // Directly append - recognitionRequest is thread-safe for append
                self?.recognitionRequest?.append(buffer)
            }

            // Prepare and start engine
            engine.prepare()
            try engine.start()

            // Start recognition task
            self.recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    self?.handleRecognitionResult(result: result, error: error)
                }
            }

            // Update state
            isRecording = true
            errorMessage = nil
            transcribedText = ""

            // Start silence timer - auto-stop after 30 seconds
            startSilenceTimer()

        } catch {
            errorMessage = "Failed to start: \(error.localizedDescription)"
            cleanupResources()
        }
    }

    @MainActor
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        // Reset silence timer on new results
        if result != nil {
            startSilenceTimer()
        }

        if let result {
            transcribedText = result.bestTranscription.formattedString

            if result.isFinal {
                stopRecording()
            }
        }

        if let error {
            let nsError = error as NSError
            // Ignore cancellation errors (code 216 or 1110)
            let isCancellation = (nsError.code == 216 || nsError.code == 1110)
            if !isCancellation && isRecording {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            stopRecording()
        }
    }

    @MainActor
    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopRecording()
            }
        }
    }

    @MainActor
    func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        silenceTimer?.invalidate()
        silenceTimer = nil

        cleanupResources()
    }

    private func cleanupResources() {
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil

        // End audio request
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Stop audio engine
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
