# Auto-Scroll User Detection Fix

## Date: 2025-10-10

## Problem
When the assistant was streaming responses, the auto-scroll behavior would yank users back to the bottom even when they had manually scrolled up to review earlier messages. The `shouldAutoScroll` flag was never being set to `false` when users scrolled manually.

## Root Cause
The original implementation only set `shouldAutoScroll = true` when sending a new message, but never detected when the user manually scrolled to disable it. This meant that during streaming, the scroll would continue to force users to the bottom regardless of their interaction with the scroll view.

## Solution

### 1. Added user scroll detection with DragGesture
**Location**: `ChatView.swift` lines 68-81

Added a `.simultaneousGesture()` modifier to the ScrollView to detect when users are manually scrolling:

```swift
.simultaneousGesture(
    DragGesture()
        .onChanged { _ in
            // User is manually scrolling
            if isLoading {
                userIsScrolling = true
                shouldAutoScroll = false
                print("📜 User started scrolling - auto-scroll disabled")
            }
        }
        .onEnded { _ in
            // User finished scrolling gesture
            userIsScrolling = false
            print("📜 User finished scrolling gesture")
        }
)
```

### 2. Added state tracking variables
**Location**: `ChatView.swift` lines 30-31

```swift
@State private var userIsScrolling = false // Track manual scroll interactions
@State private var lastContentHeight: CGFloat = 0 // Track content size changes
```

### 3. Auto-scroll logic remains unchanged
- `shouldAutoScroll = true` when user sends a new message
- Auto-scroll only triggers when `shouldAutoScroll` is true
- During streaming, scroll updates are throttled to 10 per second

## How It Works

1. **User sends a message**: `shouldAutoScroll` is set to `true`, enabling auto-scroll for the incoming response
2. **Response starts streaming**: Content scrolls to bottom as new text arrives (if `shouldAutoScroll` is true)
3. **User scrolls up manually**: DragGesture detects the interaction and sets `shouldAutoScroll = false`
4. **Streaming continues**: New content arrives but doesn't trigger scrolling since `shouldAutoScroll` is false
5. **User sends another message**: `shouldAutoScroll` resets to `true` for the new conversation

## Technical Details

### Why DragGesture?
- SwiftUI's ScrollView doesn't expose direct scroll position or velocity
- DragGesture with `.simultaneousGesture()` allows detection without interfering with normal scroll behavior
- Only disables auto-scroll when actively loading/streaming (`if isLoading`)

### Performance Considerations
- Gesture detection is lightweight and only active during user interaction
- Auto-scroll throttling (100ms intervals) prevents performance issues during rapid streaming
- No additional scroll position calculations needed

## Testing Notes
- ✅ Auto-scroll works during streaming
- ✅ User can scroll up without being yanked back
- ✅ Auto-scroll re-enables when sending new message
- ✅ No performance impact from gesture detection

## Files Modified
1. `Goose/ChatView.swift` - Added DragGesture detection and state tracking

## Build Status
✅ Successfully builds without errors
- Tested with: `xcodebuild -scheme Goose -destination 'platform=iOS Simulator,name=iPhone 17'`
