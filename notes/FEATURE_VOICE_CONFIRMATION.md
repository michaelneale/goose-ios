# Voice Confirmation Feature

## Status: **NOT YET ENABLED** ✋

This feature is fully designed but disabled by default. To enable:
```swift
voiceManager.requireConfirmation = true  // In ChatView.swift or WelcomeView.swift
```

## How It Works

### Flow Diagram
```
User speaks: "What's the weather today?"
    ↓
Silence detected (0.8s)
    ↓
[IF requireConfirmation = true]
    ↓
State → awaitingConfirmation
    ↓
Speak: "Would you like to send: What's the weather today?"
    ↓
Listen for response
    ↓
User says: "yes" / "no"
    ↓
[YES] → Send to API
[NO]  → Clear & return to listening
```

### Implementation Details

**1. State Added:**
- `.awaitingConfirmation` - Orange question mark icon
- Shows in UI that we're waiting for yes/no

**2. Word Lists:**
```swift
Confirm words: ["yes", "yeah", "yep", "sure", "send", "go ahead", "send it"]
Cancel words: ["no", "nope", "cancel", "don't send", "never mind"]
```

**3. What Needs To Be Implemented:**

#### A. Modify `submitTranscription()`:
```swift
private func submitTranscription() {
    guard !transcribedText.isEmpty else { return }
    
    let message = transcribedText
    transcribedText = ""
    hasDetectedSpeech = false
    
    // NEW: Check if confirmation is required
    if requireConfirmation && voiceMode == .fullAudio {
        // Store the message
        pendingMessage = message
        
        // Speak the confirmation prompt
        state = .speaking
        playSound(.responseReady)
        let prompt = "Would you like to send: \(message)?"
        speakConfirmationPrompt(prompt)
        
        // After speaking, move to awaitingConfirmation
        // (handled in didFinishSpeaking)
    } else {
        // Normal flow - send immediately
        state = .processing
        playSound(.submit)
        lastSpeechTime = Date()
        onSubmitMessage?(message)
    }
}
```

#### B. Add confirmation prompt speaker:
```swift
private func speakConfirmationPrompt(_ text: String) {
    // Similar to speakResponse but for prompts
    // After speaking, state → awaitingConfirmation
}
```

#### C. Modify `handleRecognitionResult()`:
```swift
// When in awaitingConfirmation state, check for confirm/cancel words
if state == .awaitingConfirmation {
    checkForConfirmationResponse(in: newText)
    return  // Don't process as normal transcription
}
```

#### D. Add confirmation response handler:
```swift
private func checkForConfirmationResponse(in text: String) {
    let lowercased = text.lowercased()
    
    // Check for YES
    for word in confirmWords {
        if lowercased.contains(word) {
            print("✅ Confirmed! Sending message")
            if let message = pendingMessage {
                pendingMessage = nil
                state = .processing
                onSubmitMessage?(message)
            }
            return
        }
    }
    
    // Check for NO
    for word in cancelWords {
        if lowercased.contains(word) {
            print("❌ Cancelled")
            pendingMessage = nil
            speakResponse("Okay, cancelled.")
            return
        }
    }
}
```

#### E. Update `didFinishSpeaking()`:
```swift
fileprivate func didFinishSpeaking() {
    print("🔊 Speech synthesis finished")
    
    if state == .speaking && pendingMessage != nil {
        // Just finished asking for confirmation
        state = .awaitingConfirmation
        startListening()  // Listen for yes/no
    } else if voiceMode == .fullAudio {
        // Normal flow
        startListening()
    } else {
        state = .idle
    }
}
```

## Complexity Analysis

### ✅ Easy Parts:
1. **State management** - Already have .awaitingConfirmation state ✓
2. **Word detection** - Reuse existing stop-word detection pattern ✓
3. **TTS integration** - Already have speakResponse() ✓
4. **Pending message storage** - Simple string variable ✓

### ⚠️ Medium Complexity:
1. **Flow control** - Branching logic in submitTranscription()
2. **Timeout handling** - What if user doesn't respond? (needs 10s timer)
3. **State transitions** - awaitingConfirmation → listening/processing

### 💡 Edge Cases to Handle:
1. **No response**: After 10s, auto-cancel or auto-send?
2. **Ambiguous response**: What if they say "maybe"?
3. **Mode switching**: What if user switches modes during confirmation?
4. **Stop words**: Should "stop" work during confirmation? (YES)

## Estimated Effort

**Time to implement**: ~2-3 hours
- Core logic: 1 hour
- Testing & edge cases: 1 hour  
- Polish & UX: 30 min

**Lines of code**: ~100-150 lines

**Risk**: Low - all building blocks exist, just need to wire them together

## When To Enable

**Good for:**
- Users who want more control
- Preventing accidental sends
- Learning/demo mode
- Accessibility (gives time to correct)

**Not good for:**
- Fast conversations (adds friction)
- Experienced users (slows them down)
- Multi-turn conversations (annoying)

## Recommendation

Keep disabled by default, but add as a **Settings toggle**:
```
Settings > Voice > Require Confirmation Before Sending
```

This way power users can enable it if they want the extra safety.
