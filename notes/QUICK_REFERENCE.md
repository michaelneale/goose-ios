# Session Activity Detection - Quick Reference

## 🚀 Quick Start

```swift
import SwiftUI

// 1. Initialize detector
let detector = SessionActivityDetector()

// 2. Detect status (fast)
let status = detector.detectStatusFromTimestamp(session)

// 3. Detect status (accurate)
let status = await detector.detectStatus(for: session, useSSE: true)

// 4. Display in UI
SessionStatusView(session: session, status: status)
```

## 📊 Status Types

| Status | Condition | Icon | Color |
|--------|-----------|------|-------|
| **Active** 🟢 | Updated < 2 min or SSE activity | `circle.fill` | Green |
| **Idle** 🟡 | Updated < 30 min | `pause.circle.fill` | Orange |
| **Finished** ⚪ | Updated > 30 min | `checkmark.circle.fill` | Gray |

## 🎯 Common Patterns

### Pattern 1: Simple Status Badge
```swift
HStack {
    Text(session.title)
    Spacer()
    Image(systemName: status.icon)
        .foregroundColor(status == .active ? .green : .gray)
}
```

### Pattern 2: Auto-Detecting Row
```swift
SessionRowWithStatus(session: session)
```

### Pattern 3: Optimized List
```swift
// Fast initial load
for session in sessions {
    let status = detector.detectStatusFromTimestamp(session)
    // Show immediately
}

// Refine in background
Task {
    for session in idleSessions {
        let refined = await detector.detectStatus(for: session, useSSE: true)
        // Update UI
    }
}
```

## ⚡ Performance

- **Timestamp detection:** 0 ms, 0 network calls
- **SSE probing:** 1500 ms max, 1 connection per session
- **Cache:** 30 seconds per session
- **Memory:** ~100 bytes per cached session

## 📁 File Locations

- **Models:** `Goose/SessionModels.swift`
- **UI:** `Goose/SessionStatusView.swift`
- **Docs:** `notes/SESSION_ACTIVITY_DETECTION.md`
- **Summary:** `notes/IMPLEMENTATION_SUMMARY.md`

## 🔧 API Methods

### SessionActivityDetector

```swift
// Fast (timestamp only)
func detectStatusFromTimestamp(_ session: ChatSession) -> SessionStatus

// Accurate (with SSE)
func detectStatus(for session: ChatSession, useSSE: Bool = true) async -> SessionStatus

// Cache management
func getCachedStatus(for sessionId: String) -> SessionStatus?
func clearCache(for sessionId: String)
func clearAllCache()
```

### SessionStatus

```swift
enum SessionStatus {
    case active, idle, finished
    
    var displayText: String
    var color: String
    var icon: String
}
```

### ChatSession (Enhanced)

```swift
struct ChatSession {
    let id: String
    let description: String
    let messageCount: Int
    let createdAt: String
    let updatedAt: String        // ← Key for detection!
    let workingDir: String       // ← NEW
    
    // Optional token fields
    let totalTokens: Int?
    let accumulatedTotalTokens: Int?
    
    // Computed helpers
    var updatedDate: Date?
    var title: String
    var lastMessage: String
}
```

## 💡 Best Practices

1. **Initial Load:** Use timestamp-only for instant display
2. **Background Refine:** Use SSE for idle sessions only
3. **Cache:** Let it handle redundant calls automatically
4. **Error Handling:** SSE failures gracefully fall back to timestamp

## ⚠️ Common Pitfalls

❌ **Don't:** Call SSE detection for all sessions synchronously
```swift
// BAD - blocks UI
for session in sessions {
    let status = await detector.detectStatus(for: session, useSSE: true)
}
```

✅ **Do:** Show timestamp results first, refine async
```swift
// GOOD - instant display, progressive enhancement
sessions.forEach { session in
    session.status = detector.detectStatusFromTimestamp(session)
}

Task {
    for session in sessions.filter({ $0.status == .idle }) {
        let refined = await detector.detectStatus(for: session, useSSE: true)
        // Update
    }
}
```

## 🎨 UI Components

```swift
// Status badge
SessionStatusView(session: session, status: status)

// Auto-detecting row
SessionRowWithStatus(session: session)

// Complete list example
SessionListWithStatusView()
```

## 📝 Integration Checklist

- [ ] Import SessionModels
- [ ] Create SessionActivityDetector instance
- [ ] Load sessions from API
- [ ] Show initial status (timestamp-based)
- [ ] Refine status in background (SSE-based)
- [ ] Display with SessionStatusView
- [ ] Handle cache appropriately

## 🐛 Debugging

```swift
// Check if SSE is working
print("Starting SSE probe for session: \(session.id)")
let status = await detector.detectStatus(for: session, useSSE: true)
print("Result: \(status)")

// Check cache
if let cached = detector.getCachedStatus(for: session.id) {
    print("Using cached status: \(cached)")
}

// Force fresh detection
detector.clearCache(for: session.id)
let fresh = await detector.detectStatus(for: session, useSSE: true)
```

## 📚 Learn More

- **Architecture:** `notes/SESSION_ACTIVITY_DETECTION.md`
- **Implementation:** `notes/IMPLEMENTATION_SUMMARY.md`
- **Examples:** `Goose/SessionStatusView.swift`
