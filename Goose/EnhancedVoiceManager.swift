import Foundation
import Speech
import AVFoundation
import SwiftUI

// MARK: - Voice Mode Types
enum VoiceMode: String, CaseIterable {
    case normal = "Normal"
    case audio = "Audio"
    case fullAudio = "Full Audio"
    
    var icon: String {
        switch self {
        case .normal: return "keyboard"
        case .audio: return "mic"
        case .fullAudio: return "mic.and.signal.meter"
        }
    }
    
    var color: Color {
        switch self {
        case .normal: return .gray
        case .audio: return .blue
        case .fullAudio: return .green
        }
    }
    
    var description: String {
        switch self {
        case .normal: return "Type messages"
        case .audio: return "Listen only, no speech"
        case .fullAudio: return "Listen and speak back"
        }
    }
}

// MARK: - Enhanced Voice Manager
@MainActor
class EnhancedVoiceManager: ObservableObject {
    // MARK: - State
    enum State: String {
        case idle = "Idle"
        case listening = "Listening"
        case awaitingConfirmation = "Confirm?"  // NEW: Waiting for yes/no
        case processing = "Processing"
        case speaking = "Speaking"
        case error = "Error"
        
        var icon: String {
            switch self {
            case .idle: return "mic.slash"
            case .listening: return "mic.fill"
            case .awaitingConfirmation: return "questionmark.circle"
            case .processing: return "ellipsis.circle"
            case .speaking: return "speaker.wave.2.fill"
            case .error: return "exclamationmark.triangle"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .gray
            case .listening: return .red
            case .awaitingConfirmation: return .orange
            case .processing: return .blue
            case .speaking: return .green
            case .error: return .orange
            }
        }
    }
    
    // MARK: - Published Properties
    @Published var voiceMode: VoiceMode = .normal {
        didSet {
            handleModeChange(from: oldValue, to: voiceMode)
        }
    }
    @Published var state: State = .idle
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    @Published var currentVolume: Float = 0.0  // RMS volume level 0.0-1.0
    
    var isListening: Bool {
        return voiceMode != .normal && state == .listening
    }
    
    var shouldSpeak: Bool {
        return voiceMode == .fullAudio
    }
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speechCoordinator: SpeechCoordinator?
    
    // RMS-based silence detection  
    private var silenceTimer: Timer?
    private var lastSpeechTime = Date()
    private var hasDetectedSpeech = false
    private let silenceThreshold: TimeInterval = 0.8  // Time after silence before submitting
    private var volumeHistory: [Float] = []
    private let volumeHistorySize = 10  // ~0.5 second of history
    private let silenceVolumeThreshold: Float = 0.03  // Volume level that counts as speech
    
    // Stop word detection
    private let stopWords = ["goose", "hey goose", "stop", "cancel"]
    private var lastStopWordCheck = Date()
    
    // Confirmation feature (NOT YET ENABLED)
    var requireConfirmation = false  // Set to true to enable "would you like to send?" flow
    private var pendingMessage: String?  // Holds message awaiting confirmation
    private let confirmWords = ["yes", "yeah", "yep", "sure", "send", "go ahead", "send it"]
    private let cancelWords = ["no", "nope", "cancel", "don't send", "never mind"]
    
    // Callbacks
    var onSubmitMessage: ((String) -> Void)?
    var onCancelRequest: (() -> Void)?  // Cancel pending API request
    
    // MARK: - Initialization
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        setupSpeechSynthesizer()
    }
    
    private func setupSpeechSynthesizer() {
        speechCoordinator = SpeechCoordinator()
        speechCoordinator?.manager = self
        speechSynthesizer.delegate = speechCoordinator
    }
    
    // MARK: - Mode Management
    private func handleModeChange(from oldMode: VoiceMode, to newMode: VoiceMode) {
        print("🔄 Voice mode changed from \(oldMode) to \(newMode)")
        
        // Stop any ongoing operations
        stopListening()
        stopSpeaking()
        
        // Handle the new mode
        switch newMode {
        case .normal:
            state = .idle
            playSound(.modeSwitch)
            
        case .audio:
            playSound(.modeSwitch)
            startListening()
            
        case .fullAudio:
            playSound(.modeSwitch)
            startListening()
        }
    }
    
    // MARK: - Public Methods
    func setMode(_ mode: VoiceMode) {
        voiceMode = mode
    }
    
    func cycleVoiceMode() {
        switch voiceMode {
        case .normal:
            setMode(.audio)
        case .audio:
            setMode(.fullAudio)
        case .fullAudio:
            setMode(.normal)
        }
    }
    
    func handleUserInteraction() {
        // If we're speaking, stop speaking and return to listening (in voice mode)
        if state == .speaking && voiceMode == .fullAudio {
            print("🛑 User interrupted speech")
            stopSpeaking()
            // Small delay before restarting listening
            Task {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second
                if voiceMode == .fullAudio {
                    startListening()
                }
            }
        }
    }
    
    func speakResponse(_ text: String) {
        guard voiceMode == .fullAudio else {
            print("🔇 Not in full voice mode, skipping speech")
            return
        }
        
        print("🎤 Speaking response: \(text.prefix(50))...")
        
        // Keep listening running so we can detect "stop" commands during speech
        // The .playAndRecord audio session with .voiceChat mode provides echo cancellation
        state = .speaking
        playSound(.responseReady)
        
        // Clean the text for speech
        let cleanedText = cleanTextForSpeech(text)
        
        // Don't change audio session - keep it in .playAndRecord mode so we can still hear "stop" commands
        // The audio session was already configured in startListening() with echo cancellation
        
        let utterance = AVSpeechUtterance(string: cleanedText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - Private Methods - Recording
    private func startListening() {
        Task {
            do {
                // Check authorization
                guard await requestAuthorization() else {
                    throw VoiceError.notAuthorized
                }
                
                // Reset state
                stopListening()
                transcribedText = ""
                hasDetectedSpeech = false
                volumeHistory.removeAll()
                state = .listening
                
                playSound(.startListening)
                
                // Configure audio session with better settings for voice chat
                let audioSession = AVAudioSession.sharedInstance()
                if voiceMode == .fullAudio {
                    // Use playAndRecord with voiceChat mode for echo cancellation
                    try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothA2DP])
                } else {
                    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                }
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                // Create recognition request with on-device recognition
                recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                guard let recognitionRequest = recognitionRequest else {
                    throw VoiceError.recognitionRequestFailed
                }
                
                recognitionRequest.shouldReportPartialResults = true
                recognitionRequest.requiresOnDeviceRecognition = true  // Privacy + speed
                
                // Setup audio engine
                audioEngine = AVAudioEngine()
                guard let audioEngine = audioEngine else {
                    throw VoiceError.audioEngineFailed
                }
                
                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)
                
                // Install tap with RMS calculation
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                    recognitionRequest.append(buffer)
                    
                    // Calculate RMS volume level
                    Task { @MainActor in
                        self?.calculateAndUpdateRMS(buffer: buffer)
                    }
                }
                
                audioEngine.prepare()
                try audioEngine.start()
                
                recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                    self?.handleRecognitionResult(result: result, error: error)
                }
                
                startSilenceDetection()
                
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - RMS Volume Calculation
    private func calculateAndUpdateRMS(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS (Root Mean Square)
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrtf(sum / Float(frameLength))
        
        // Normalize and smooth
        let normalizedRMS = min(rms * 10.0, 1.0)  // Scale up and cap at 1.0
        currentVolume = normalizedRMS * 0.7 + currentVolume * 0.3  // Smoothing
        
        // Track volume history for silence detection
        volumeHistory.append(normalizedRMS)
        if volumeHistory.count > volumeHistorySize {
            volumeHistory.removeFirst()
        }
    }
    
    private func isVolumeSilent() -> Bool {
        guard volumeHistory.count >= volumeHistorySize / 2 else { return false }
        let recentVolumes = volumeHistory.suffix(volumeHistorySize / 2)
        let avgVolume = recentVolumes.reduce(0.0, +) / Float(recentVolumes.count)
        return avgVolume < silenceVolumeThreshold
    }
    
    private func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - Recognition Handling
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        Task { @MainActor in
            if let result = result {
                let newText = result.bestTranscription.formattedString
                
                if !newText.isEmpty {
                    transcribedText = newText
                    lastSpeechTime = Date()
                    
                    if !hasDetectedSpeech {
                        hasDetectedSpeech = true
                    }
                    
                    // Check for stop words in Full Audio mode
                    if voiceMode == .fullAudio {
                        checkForStopWords(in: newText)
                    }
                }
                
                if result.isFinal {
                    submitTranscription()
                }
            }
            
            if let error = error {
                let nsError = error as NSError
                // Ignore common non-critical errors
                if nsError.code != 203 && nsError.code != 1 && nsError.code != 4 {
                    print("Speech recognition error (code: \(nsError.code)): \(error.localizedDescription)")
                    if nsError.code != 0 && nsError.domain != "kAFAssistantErrorDomain" {
                        handleError(error)
                    }
                }
            }
        }
    }
    
    // MARK: - Stop Word Detection
    private func checkForStopWords(in text: String) {
        // Throttle checks to avoid too frequent processing
        let now = Date()
        guard now.timeIntervalSince(lastStopWordCheck) > 0.3 else { return }
        lastStopWordCheck = now
        
        let lowercased = text.lowercased()
        let words = lowercased.split(separator: " ")
        let lastFewWords = words.suffix(3).joined(separator: " ")
        
        for stopWord in stopWords {
            if lastFewWords.contains(stopWord) {
                print("🛑 Stop word detected: '\(stopWord)' in '\(lastFewWords)'")
                handleStopCommand(context: state)
                return
            }
        }
    }
    
    private func handleStopCommand(context: State) {
        print("🛑 Handling stop command in state: \(context)")
        playSound(.error)  // Audio feedback
        
        switch context {
        case .listening:
            // Clear current transcription and restart
            print("🛑 Clearing transcription")
            transcribedText = ""
            hasDetectedSpeech = false
            lastSpeechTime = Date()
            
        case .processing:
            // Cancel the pending API request
            print("🛑 Cancelling API request")
            onCancelRequest?()
            // Already listening in fullAudio mode - just update state and reset buffer
            state = .listening
            transcribedText = ""
            hasDetectedSpeech = false
            lastSpeechTime = Date()
            
        case .speaking:
            // Stop speaking and return to listening
            print("🛑 Stopping speech")
            stopSpeaking()
            // Audio engine is already running, just transition state back to listening
            state = .listening
            // Clear the stop word from transcription but keep timing for auto-submit
            // Remove the stop word that was detected
            let lowercased = transcribedText.lowercased()
            for stopWord in stopWords {
                if lowercased.contains(stopWord) {
                    // Remove the stop word and any text before it (likely part of response echo)
                    if let range = lowercased.range(of: stopWord) {
                        transcribedText = String(transcribedText[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    }
                    break
                }
            }
            // If there's no remaining text, reset everything
            if transcribedText.isEmpty {
                hasDetectedSpeech = false
            }
            // Don't reset lastSpeechTime - let it track actual speech for auto-submit
            
        default:
            break
        }
    }
    
    // MARK: - Silence Detection
    private func startSilenceDetection() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForSilence()
            }
        }
    }
    
    private func checkForSilence() {
        // Only auto-submit in fullAudio mode - audio mode requires manual send
        guard voiceMode == .fullAudio, state == .listening, hasDetectedSpeech else { return }
        
        let timeSinceLastSpeech = Date().timeIntervalSince(lastSpeechTime)
        
        if timeSinceLastSpeech > silenceThreshold && !transcribedText.isEmpty {
            submitTranscription()
        }
    }
    
    private func submitTranscription() {
        guard !transcribedText.isEmpty else { return }
        
        let message = transcribedText
        transcribedText = ""
        hasDetectedSpeech = false
        
        // In fullAudio mode, keep listening even while processing (for "stop" commands)
        if voiceMode == .fullAudio {
            state = .processing
            playSound(.submit)
            // Keep the recognition running but reset the transcription buffer
            lastSpeechTime = Date()
        } else {
            // In audio mode, stop listening (but this shouldn't be called in audio mode anyway)
            stopListening()
            state = .processing
            playSound(.submit)
        }
        
        // Send the message via callback
        onSubmitMessage?(message)
        
        // Note: This is only called from checkForSilence() which only runs in fullAudio mode
        // In full audio mode, we'll wait for the response to be spoken before listening again
    }
    
    // MARK: - Audio Feedback
    private enum SoundType {
        case startListening
        case submit
        case responseReady
        case error
        case modeSwitch
        
        var systemSoundID: SystemSoundID {
            switch self {
            case .startListening: return 1113
            case .submit: return 1114
            case .responseReady: return 1025
            case .error: return 1073
            case .modeSwitch: return 1104
            }
        }
    }
    
    private func playSound(_ type: SoundType) {
        AudioServicesPlaySystemSound(type.systemSoundID)
    }
    
    // MARK: - Helpers
    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        let nsError = error as NSError
        
        if nsError.domain == "kAFAssistantErrorDomain" {
            print("⚠️ Speech recognition interrupted (expected in simulator)")
            return
        }
        
        state = .error
        errorMessage = error.localizedDescription
        playSound(.error)
        
        print("❌ Voice error: \(error)")
        
        // Try to recover
        if voiceMode != .normal && error is VoiceError {
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if voiceMode != .normal {
                    startListening()
                }
            }
        }
    }
    
    private func cleanTextForSpeech(_ text: String) -> String {
        var cleaned = text
        
        // Remove markdown
        cleaned = cleaned.replacingOccurrences(of: "```[^`]*```", with: "code block", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "`[^`]+`", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]+\\)", with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\*\\*([^\\*]+)\\*\\*", with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\*([^\\*]+)\\*", with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "__([^_]+)__", with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: [.regularExpression, .anchored])
        cleaned = cleaned.replacingOccurrences(of: "\n\n+", with: ". ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\n", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "[❌✅🚨📝🔧⚠️🛑→]", with: "", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Called when speech finishes
    fileprivate func didFinishSpeaking() {
        print("🔊 Speech synthesis finished")
        if voiceMode == .fullAudio {
            // Audio engine is already running, just transition state back to listening
            print("🎤 Returning to listening state after speech")
            state = .listening
            transcribedText = ""
            hasDetectedSpeech = false
            lastSpeechTime = Date()
        } else {
            state = .idle
        }
    }
}

// MARK: - Speech Synthesizer Delegate
private class SpeechCoordinator: NSObject, AVSpeechSynthesizerDelegate {
    weak var manager: EnhancedVoiceManager?
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            manager?.didFinishSpeaking()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            manager?.didFinishSpeaking()
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

// MARK: - Three State Slider View
struct ThreeStateVoiceSlider: View {
    @ObservedObject var manager: EnhancedVoiceManager
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let trackWidth: CGFloat = 120  // Much more compact
    private let thumbSize: CGFloat = 26
    private let trackHeight: CGFloat = 28
    
    var body: some View {
        // Compact slider without labels
        ZStack(alignment: .leading) {
            // Track background with subtle gradient
            Capsule()
                .fill(Color(.systemGray6))
                .frame(width: trackWidth, height: trackHeight)
                .overlay(
                    Capsule()
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            
            // Position indicators - just subtle marks, no dots
            HStack(spacing: 0) {
                ForEach(Array(VoiceMode.allCases.enumerated()), id: \.element) { index, mode in
                    if index > 0 {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 1, height: trackHeight * 0.4)
                    }
                    Spacer()
                }
            }
            .frame(width: trackWidth - 20)
            .offset(x: 10)
            
            // Thumb with icon only
            Circle()
                .fill(Color.white)
                .frame(width: thumbSize, height: thumbSize)
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                .overlay(
                    Circle()
                        .stroke(manager.voiceMode.color, lineWidth: 1.5)
                )
                .overlay(
                    Image(systemName: manager.voiceMode.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(manager.voiceMode.color)
                )
                .offset(x: thumbOffset + dragOffset)
                .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: thumbOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            
                            // Constrain to track bounds
                            let potentialOffset = thumbOffset + value.translation.width
                            if potentialOffset >= 0 && potentialOffset <= trackWidth - thumbSize {
                                dragOffset = value.translation.width
                            } else if potentialOffset < 0 {
                                dragOffset = -thumbOffset
                            } else {
                                dragOffset = trackWidth - thumbSize - thumbOffset
                            }
                            
                            // Check if we've moved to a new mode
                            let absolutePosition = thumbOffset + dragOffset
                            let newMode = modeForPosition(absolutePosition)
                            if newMode != manager.voiceMode {
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            let finalPosition = thumbOffset + dragOffset
                            let newMode = modeForPosition(finalPosition)
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                manager.setMode(newMode)
                                dragOffset = 0
                            }
                        }
                )
        }
        .frame(width: trackWidth, height: trackHeight)
        .onAppear {
        }
    }
    
    private var thumbOffset: CGFloat {
        let segmentWidth = (trackWidth - thumbSize) / 2
        switch manager.voiceMode {
        case .normal:
            return 0
        case .audio:
            return segmentWidth
        case .fullAudio:
            return trackWidth - thumbSize
        }
    }
    
    private func modeForPosition(_ position: CGFloat) -> VoiceMode {
        let normalizedPosition = position / (trackWidth - thumbSize)
        
        if normalizedPosition < 0.33 {
            return .normal
        } else if normalizedPosition < 0.67 {
            return .audio
        } else {
            return .fullAudio
        }
    }
}

// MARK: - Voice Mode Selector View (Original Segmented Style)
struct VoiceModeSelector: View {
    @ObservedObject var manager: EnhancedVoiceManager
    @State private var dragOffset: CGFloat = 0
    
    private let modes = VoiceMode.allCases
    private let segmentWidth: CGFloat = 100
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
                
                // Selected segment highlight
                RoundedRectangle(cornerRadius: 18)
                    .fill(manager.voiceMode.color.opacity(0.3))
                    .frame(width: segmentWidth - 4)
                    .offset(x: selectedOffset)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: manager.voiceMode)
                
                // Mode indicators
                HStack(spacing: 0) {
                    ForEach(modes, id: \.self) { mode in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                manager.setMode(mode)
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(manager.voiceMode == mode ? mode.color : .gray)
                                
                                Text(mode.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(manager.voiceMode == mode ? mode.color : .gray)
                            }
                            .frame(width: segmentWidth)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .frame(height: 50)
        .frame(width: CGFloat(modes.count) * segmentWidth)
    }
    
    private var selectedOffset: CGFloat {
        let index = modes.firstIndex(of: manager.voiceMode) ?? 0
        return CGFloat(index - 1) * segmentWidth
    }
}

// MARK: - Compact Voice Mode Toggle
struct CompactVoiceModeToggle: View {
    @ObservedObject var manager: EnhancedVoiceManager
    
    var body: some View {
        Menu {
            ForEach(VoiceMode.allCases, id: \.self) { mode in
                Button(action: {
                    manager.setMode(mode)
                }) {
                    Label {
                        VStack(alignment: .leading) {
                            Text(mode.rawValue)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: mode.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: manager.voiceMode.icon)
                    .foregroundColor(manager.voiceMode.color)
                    .symbolEffect(.variableColor.iterative, isActive: manager.state == .listening)
                
                if manager.voiceMode != .normal {
                    Text(manager.state.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(manager.voiceMode.color)
                } else {
                    Text(manager.voiceMode.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(manager.voiceMode.color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(manager.voiceMode.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
