# Streaming Scroll Fix

## Date: 2025-10-10

## Problem
When assistant messages were streaming in (getting longer as text arrived), the view wasn't automatically scrolling to follow the new content. The message would grow beyond the visible area but the scroll position would remain static, causing users to miss the incoming response.

## Root Cause
The scroll was only triggered on:
1. `messages.count` changes (new message added)
2. `scrollRefreshTrigger` changes (session loaded) 
3. App coming to foreground

However, during streaming, the message count doesn't change - the existing message just gets longer as text is appended. The code was updating `messages[existingIndex]` without triggering any scroll.

## Solution

### 1. Added scroll trigger for message updates
**Location**: `ChatView.swift` line 327-334

When an existing message is updated during streaming:
```swift
self.messages[existingIndex] = updatedMessage
// Trigger scroll when message content is updated during streaming
// Throttle to avoid excessive scrolling during rapid updates
if self.shouldAutoScroll {
    let now = Date()
    if now.timeIntervalSince(self.lastScrollUpdate) > 0.1 { // Throttle to 10 updates per second
        self.lastScrollUpdate = now
        self.scrollRefreshTrigger = UUID()
    }
}
```

### 2. Added throttling mechanism
**Location**: `ChatView.swift` line 17

Added state variable to track last scroll update:
```swift
@State private var lastScrollUpdate = Date() // Throttle streaming scrolls
```

This prevents excessive scrolling during rapid streaming updates by limiting scroll triggers to 10 per second (0.1 second intervals).

### 3. Added final scroll on stream completion
**Location**: `ChatView.swift` line 361-365

When streaming finishes, force a final scroll to ensure we're at the bottom:
```swift
case .finish(let finishEvent):
    // ... handle tool calls ...
    
    // Force final scroll to bottom when streaming completes
    if shouldAutoScroll {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollRefreshTrigger = UUID()
        }
    }
```

## Technical Details

### Scroll Triggering
- Uses `scrollRefreshTrigger` UUID to force ScrollViewReader updates
- `onChange(of: scrollRefreshTrigger)` detects changes and calls `scrollToBottom()`
- Animated scroll with `.easeOut(duration: 0.3)`

### Performance Optimization
- Throttling prevents janky scrolling during rapid text updates
- 100ms interval (10 updates/sec) provides smooth following without performance issues
- Final scroll ensures complete message is visible even if last updates were throttled

### Edge Cases Handled
- Works with long messages that exceed screen height
- Maintains scroll position when `shouldAutoScroll` is false
- Properly scrolls to tool calls when they're the last element
- Handles both new messages and updated messages

## Testing Notes
- Streaming text now follows along as it arrives ✓
- Scroll remains smooth even with rapid updates ✓
- Final position is correct when stream completes ✓
- No performance degradation with throttling ✓

## Files Modified
1. `Goose/ChatView.swift` - Added scroll triggering and throttling logic

## Build Status
✅ Successfully builds without errors
- Tested with: `xcodebuild -scheme Goose -destination 'platform=iOS Simulator,name=iPhone 17'`
