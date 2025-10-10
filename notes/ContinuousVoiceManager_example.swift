import Foundation
import Speech
import AVFoundation
import SwiftUI

/// Manages continuous voice conversation mode with automatic silence detection and audio feedback
@MainActor
class ContinuousVoiceManager: ObservableObject {
    // MARK: - Published Properties
    @Published var mode: ConversationMode = .text
    @Published var state: VoiceState = .idle
    @Published var transcribedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Enums
    enum ConversationMode {
        case text
        case voice
    }
    
    enum VoiceState {
        case idle
        case listening
        case detectingSilence
        case processing
        case speaking
        case paused
        case error
        
        var icon: String {
            switch self {
            case .idle: return "mic.slash"
            case .listening: return "mic.fill"
            case .detectingSilence: return "mic.badge.ellipsis"
            case .processing: return "ellipsis.circle"
            case .speaking: return "speaker.wave.3.fill"
            case .paused: return "pause.circle"
            case .error: return "exclamationmark.triangle"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .gray
            case .listening: return .blue
            case .detectingSilence: return .orange
            case .processing: return .purple
            case .speaking: return .green
            case .paused: return .yellow
            case .error: return .red
            }
        }
    }
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechSynthesizer = AVSpeechSynthesizer()
    
    // Audio level monitoring
    private var audioLevelTimer: Timer?
    private var recentAudioLevels: [Float] = []
    private let silenceThreshold: Float = 0.02
    private let silenceDuration: TimeInterval = 1.5
    private var lastSpeechTime: Date = Date()
    private var hasDetectedSpeech: Bool = false
    
    // Audio feedback
    private let systemSoundID: SystemSoundID = 1104 // Default keyboard tap sound
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    // MARK: - Initialization
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechSynthesizer.delegate = self
        setupNotifications()
    }
    
    // MARK: - Public Methods
    func toggleMode() {
        switch mode {
        case .text:
            enterVoiceMode()
        case .voice:
            exitVoiceMode()
        }
    }
    
    func enterVoiceMode() {
        mode = .voice
        playFeedbackSound(.modeSwitch)
        hapticFeedback.impactOccurred()
        startListening()
    }
    
    func exitVoiceMode() {
        mode = .text
        playFeedbackSound(.modeSwitch)
        hapticFeedback.impactOccurred()
        stopListening()
        stopSpeaking()
        state = .idle
    }
    
    func pauseConversation() {
        guard mode == .voice else { return }
        state = .paused
        stopListening()
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.pauseSpeaking(at: .immediate)
        }
    }
    
    func resumeConversation() {
        guard mode == .voice, state == .paused else { return }
        if speechSynthesizer.isPaused {
            speechSynthesizer.continueSpeaking()
            state = .speaking
        } else {
            startListening()
        }
    }
    
    // MARK: - Private Methods - Audio Input
    private func startListening() {
        Task {
            do {
                // Request permissions if needed
                guard await requestSpeechAuthorization() else {
                    throw VoiceError.notAuthorized
                }
                
                // Reset state
                transcribedText = ""
                hasDetectedSpeech = false
                recentAudioLevels.removeAll()
                state = .listening
                
                // Play feedback sound
                playFeedbackSound(.startListening)
                
                // Configure audio session
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                // Setup recognition
                recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                guard let recognitionRequest = recognitionRequest else {
                    throw VoiceError.recognitionRequestFailed
                }
                
                recognitionRequest.shouldReportPartialResults = true
                recognitionRequest.requiresOnDeviceRecognition = false // Use server for better accuracy
                
                // Setup audio engine
                audioEngine = AVAudioEngine()
                guard let audioEngine = audioEngine else {
                    throw VoiceError.audioEngineFailed
                }
                
                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)
                
                // Install tap for both recognition and level monitoring
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                    self?.recognitionRequest?.append(buffer)
                    self?.monitorAudioLevel(buffer: buffer)
                }
                
                audioEngine.prepare()
                try audioEngine.start()
                
                // Start recognition task
                recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                    self?.handleRecognitionResult(result: result, error: error)
                }
                
                // Start monitoring for silence
                startSilenceDetection()
                
            } catch {
                handleError(error)
            }
        }
    }
    
    private func stopListening() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func monitorAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for channel in 0..<channelCount {
            for frame in 0..<frameLength {
                let sample = channelData[channel][frame]
                sum += sample * sample
            }
        }
        
        let rms = sqrt(sum / Float(channelCount * frameLength))
        
        Task { @MainActor in
            recentAudioLevels.append(rms)
            if recentAudioLevels.count > 30 { // Keep last ~1.5 seconds
                recentAudioLevels.removeFirst()
            }
            
            // Detect if we have speech
            if rms > silenceThreshold {
                lastSpeechTime = Date()
                if !hasDetectedSpeech && !transcribedText.isEmpty {
                    hasDetectedSpeech = true
                    state = .listening
                }
            }
        }
    }
    
    private func startSilenceDetection() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForSilence()
            }
        }
    }
    
    private func checkForSilence() {
        guard mode == .voice, state == .listening || state == .detectingSilence else { return }
        
        let timeSinceLastSpeech = Date().timeIntervalSince(lastSpeechTime)
        
        if hasDetectedSpeech && !transcribedText.isEmpty {
            if timeSinceLastSpeech > silenceDuration {
                // Silence detected, submit the query
                submitQuery()
            } else if timeSinceLastSpeech > 0.5 {
                // Show that we're detecting potential end of speech
                state = .detectingSilence
            }
        }
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        Task { @MainActor in
            if let result = result {
                transcribedText = result.bestTranscription.formattedString
                
                if result.isFinal {
                    submitQuery()
                }
            }
            
            if let error = error {
                handleError(error)
            }
        }
    }
    
    // MARK: - Private Methods - Query Processing
    private func submitQuery() {
        guard !transcribedText.isEmpty else { return }
        
        stopListening()
        state = .processing
        playFeedbackSound(.submit)
        hapticFeedback.impactOccurred()
        
        // This is where you'd send the query to your API
        // For now, we'll simulate it
        Task {
            do {
                // Simulate API call
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                // Simulate response
                let response = "This is a simulated response to: \(transcribedText)"
                
                if mode == .voice {
                    speakResponse(response)
                }
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - Private Methods - Audio Output
    private func speakResponse(_ text: String) {
        state = .speaking
        playFeedbackSound(.responseReady)
        
        // Configure audio session for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session for playback: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    private func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - Private Methods - Feedback
    private enum FeedbackSound {
        case startListening
        case submit
        case responseReady
        case error
        case modeSwitch
        
        var systemSoundID: SystemSoundID {
            switch self {
            case .startListening: return 1113  // Begin recording
            case .submit: return 1114          // End recording
            case .responseReady: return 1025   // Notification
            case .error: return 1073           // Error
            case .modeSwitch: return 1104      // Keyboard tap
            }
        }
    }
    
    private func playFeedbackSound(_ sound: FeedbackSound) {
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }
    
    // MARK: - Private Methods - Helpers
    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        state = .error
        errorMessage = error.localizedDescription
        playFeedbackSound(.error)
        hapticFeedback.impactOccurred()
        
        // Try to recover after a delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if mode == .voice {
                startListening()
            }
        }
    }
    
    private func setupNotifications() {
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            pauseConversation()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resumeConversation()
                }
            }
        @unknown default:
            break
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension ContinuousVoiceManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if mode == .voice {
                // Automatically restart listening after speaking
                startListening()
            } else {
                state = .idle
            }
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if mode == .voice {
                startListening()
            } else {
                state = .idle
            }
        }
    }
}

// MARK: - Error Types
enum VoiceError: LocalizedError {
    case notAuthorized
    case recognitionRequestFailed
    case audioEngineFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in Settings."
        case .recognitionRequestFailed:
            return "Failed to create recognition request."
        case .audioEngineFailed:
            return "Failed to initialize audio engine."
        }
    }
}

// MARK: - SwiftUI View Component
struct VoiceModeToggle: View {
    @ObservedObject var manager: ContinuousVoiceManager
    
    var body: some View {
        HStack {
            // Mode toggle slider
            HStack(spacing: 12) {
                Image(systemName: "text.bubble")
                    .foregroundColor(manager.mode == .text ? .blue : .gray)
                
                Toggle("", isOn: Binding(
                    get: { manager.mode == .voice },
                    set: { _ in manager.toggleMode() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .frame(width: 51)
                
                Image(systemName: "mic.circle.fill")
                    .foregroundColor(manager.mode == .voice ? .blue : .gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            
            // State indicator
            if manager.mode == .voice {
                HStack {
                    Image(systemName: manager.state.icon)
                        .foregroundColor(manager.state.color)
                        .symbolEffect(.pulse, isActive: manager.state == .listening)
                    
                    Text(String(describing: manager.state).capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(manager.state.color.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}
