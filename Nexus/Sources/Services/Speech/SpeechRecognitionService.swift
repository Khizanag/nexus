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
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task {
                await startRecording()
            }
        }
    }

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
        await beginRecordingSession()
        #endif
    }

    private func beginRecordingSession() async {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition not available on this device"
            return
        }

        // Clean up any previous session
        cleanupAudioSession()

        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP])
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
            request.requiresOnDeviceRecognition = false

            // Install audio tap
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            // Prepare and start engine
            engine.prepare()
            try engine.start()

            // Store references
            self.audioEngine = engine
            self.recognitionRequest = request

            // Start recognition task
            self.recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    self?.handleRecognitionResult(result: result, error: error)
                }
            }

            // Update state
            isRecording = true
            errorMessage = nil
            transcribedText = ""

            // Start silence timer - auto-stop after 30 seconds of no new input
            startSilenceTimer()

        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            cleanupAudioSession()
        }
    }

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        // Reset silence timer on new results
        if result != nil {
            startSilenceTimer()
        }

        if let result {
            transcribedText = result.bestTranscription.formattedString

            // Auto-stop after final result
            if result.isFinal {
                stopRecording()
            }
        }

        if let error {
            // Ignore cancellation errors (they happen on normal stop)
            let nsError = error as NSError
            if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 {
                // Only show error if it's not a cancellation
                if isRecording {
                    errorMessage = "Recognition error: \(error.localizedDescription)"
                }
            }
            stopRecording()
        }
    }

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopRecording()
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        silenceTimer?.invalidate()
        silenceTimer = nil

        cleanupAudioSession()
    }

    private func cleanupAudioSession() {
        // Stop recognition task first
        recognitionTask?.cancel()
        recognitionTask = nil

        // End audio request
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Stop and cleanup audio engine
        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignore deactivation errors
        }
    }

}
