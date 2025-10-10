# Voice Mode Improvements - Design Options

## Current State
- Separate record button and playback toggle
- Manual start/stop recording
- Automatic playback when voice output is enabled
- No continuous conversation flow

## Proposed Improvements

### Option 1: Slide-to-Voice Mode (Recommended)
A single sliding control that activates continuous voice conversation mode.

#### UI Design
```
[Text Mode] <---slider---> [Voice Mode]
```
Or a more modern approach:
```
[💬] ---○--- [🎤]  (sliding toggle)
```

#### Features
- **Continuous Listening**: Automatically restarts listening after response playback
- **Silence Detection**: Submits query after detecting 1.5-2 seconds of silence
- **Audio Feedback**:
  - Subtle "ding" when starting to listen
  - Different tone when submitting (processing)
  - Gentle chime when response starts playing
- **Visual Feedback**:
  - Pulsing microphone indicator when listening
  - Processing animation during API call
  - Speaker animation during playback

#### Implementation Details
```swift
class ContinuousVoiceManager: ObservableObject {
    @Published var mode: ConversationMode = .text
    @Published var state: VoiceState = .idle
    
    enum ConversationMode {
        case text
        case voice
    }
    
    enum VoiceState {
        case idle
        case listening
        case processing
        case speaking
        case paused
    }
    
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.5
    private var lastSpeechTime: Date = Date()
    
    func detectSilence() {
        // Monitor audio levels and trigger submission
    }
}
```

### Option 2: Wake Word Detection
Use on-device speech recognition to detect interruption commands.

#### Commands
- "Stop" / "Pause" - Stops current playback
- "Cancel" / "Never mind" - Cancels current operation
- "Hey Goose" - Interrupts and starts new query

#### Implementation
- Run continuous background speech recognition with limited vocabulary
- Use Apple's on-device models for privacy
- Low power consumption focus

### Option 3: Gesture-Based Controls
Leverage iOS gesture recognition while in voice mode.

#### Gestures
- **Tap**: Pause/Resume current operation
- **Double Tap**: Cancel and restart listening
- **Long Press**: Exit voice mode
- **Swipe Down**: Lower volume
- **Swipe Up**: Increase volume

### Option 4: Hybrid Smart Mode
Combines multiple approaches for optimal UX.

#### Features
1. **Auto-switching**: Detects when user starts typing and pauses voice
2. **Context Awareness**: 
   - Shorter silence threshold for follow-up questions
   - Longer threshold for initial queries
3. **Adaptive Feedback**: Learns user's speaking patterns

## Audio Feedback Design

### Sound Effects Needed
1. **Listen Start**: Subtle ascending tone (C-E-G, 150ms)
2. **Processing**: Soft repeating pulse (200ms intervals)
3. **Response Ready**: Pleasant chime (G-C-E-G, 300ms)
4. **Error**: Gentle descending tone (G-E-C, 250ms)
5. **Mode Switch**: Smooth transition sound (whoosh, 200ms)

### Implementation Options
- **System Sounds**: Use iOS system sounds for consistency
- **Custom Sounds**: Create branded audio experience
- **Haptic Feedback**: Combine with subtle haptics on supported devices

## Silence Detection Algorithm

### Basic Approach
```swift
extension VoiceInputManager {
    func setupSilenceDetection() {
        // Monitor audio buffer levels
        var recentLevels: [Float] = []
        let silenceThreshold: Float = 0.02 // Adjust based on testing
        
        // In audio buffer callback:
        let level = calculateRMSLevel(buffer)
        recentLevels.append(level)
        
        if recentLevels.count > 30 { // ~1.5 seconds at 20Hz sampling
            recentLevels.removeFirst()
        }
        
        let averageLevel = recentLevels.reduce(0, +) / Float(recentLevels.count)
        if averageLevel < silenceThreshold && hasSpokenContent() {
            triggerSubmission()
        }
    }
}
```

### Advanced Approach
- Use Voice Activity Detection (VAD) algorithms
- Implement end-of-utterance detection using ML models
- Consider using Apple's Speech framework's segmentation features

## Voice Activity Detection Options

### 1. Apple's Native VAD
```swift
// Using AVAudioEngine with voice processing
let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode

// Enable voice processing
try inputNode.setVoiceProcessingEnabled(true)
```

### 2. WebRTC VAD (via Swift wrapper)
- More aggressive silence detection
- Cross-platform consistency
- Requires additional framework

### 3. Custom Energy-Based Detection
- Simple RMS energy calculation
- Adaptive threshold based on ambient noise
- Lightweight and customizable

## UI/UX Considerations

### Visual Indicators
1. **Listening State**:
   - Animated waveform
   - Pulsing circle
   - Color changes (blue = listening, gray = idle)

2. **Processing State**:
   - Spinning dots
   - Progress ring
   - Subtle particle effects

3. **Speaking State**:
   - Audio waveform visualization
   - Mouth/speaker animation
   - Text appearing word-by-word

### Accessibility
- VoiceOver support for all states
- Visual indicators for hearing impaired
- Adjustable silence thresholds
- Option to use buttons instead of automatic detection

## Technical Implementation Plan

### Phase 1: Core Voice Loop
1. Implement continuous listening mode
2. Add basic silence detection
3. Create state management system

### Phase 2: Audio Feedback
1. Design and implement sound effects
2. Add haptic feedback
3. Test with users

### Phase 3: Advanced Features
1. Wake word detection
2. Gesture controls
3. Adaptive thresholds

### Phase 4: Polish
1. Optimize battery usage
2. Improve accuracy
3. Add customization options

## Battery & Performance Optimization

### Strategies
1. **Batch Processing**: Process audio in chunks
2. **Dynamic Quality**: Lower sample rate when on battery
3. **Smart Activation**: Only process when screen is on
4. **Efficient Models**: Use quantized on-device models

## Privacy Considerations
- All processing happens on-device until submission
- No continuous streaming to servers
- Clear visual indicators when microphone is active
- Easy opt-out/disable options

## Testing Scenarios
1. Noisy environments
2. Multiple speakers
3. Different accents/speaking speeds
4. Network interruptions
5. Background app scenarios

## Inspiration from Other Apps
- **Google Assistant**: Continued conversation mode
- **Amazon Alexa**: Follow-up mode
- **ChatGPT iOS**: Voice conversation mode
- **Whisper**: Push-to-talk simplicity
