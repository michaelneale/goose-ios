# Session Activity Detection

## Overview

This feature detects whether a Goose session is actively running, idle, or finished using a hybrid approach combining timestamp analysis and brief SSE (Server-Sent Events) probing.

## Status Types

- **Active** 🟢 - Session is currently processing (updated within 2 minutes or SSE activity detected)
- **Idle** 🟡 - No recent activity but potentially resumable (updated within 30 minutes)
- **Finished** ⚪ - Completed and idle for extended period (over 30 minutes)

## Architecture

### Components

1. **SessionStatus** (`SessionModels.swift`)
   - Enum defining the three status states
   - Provides display properties (text, color, icon)

2. **ChatSession** (`SessionModels.swift`)
   - Enhanced model matching the goosed API `/sessions` endpoint
   - Includes `working_dir`, token stats, timestamps
   - Helper methods for date parsing and relative time display

3. **SessionActivityDetector** (`SessionModels.swift`)
   - Core detection logic
   - Caching mechanism (30-second cache)
   - Two-strategy approach: timestamp + SSE

4. **UI Components** (`SessionStatusView.swift`)
   - `SessionStatusView` - Visual badge for status
   - `SessionRowWithStatus` - Session list row with status
   - `SessionListWithStatusView` - Complete example list view

## Detection Strategy

### Two-Phase Approach

#### Phase 1: Timestamp-Based (Fast)
```swift
func detectStatusFromTimestamp(_ session: ChatSession) -> SessionStatus
```

- Analyzes `updated_at` timestamp
- No network calls required
- Instant results
- Thresholds:
  - Active: < 2 minutes since update
  - Idle: < 30 minutes since update
  - Finished: > 30 minutes since update

#### Phase 2: SSE Probing (Accurate)
```swift
private func detectStatusFromSSE(_ session: ChatSession) async -> SessionStatus
```

- Only used for uncertain cases (typically "idle" status)
- Brief 1.5-second SSE connection
- Detects actual agent activity
- Gracefully handles timeouts and errors

### Caching

- Results cached for 30 seconds per session
- Reduces redundant API calls
- Can be cleared per-session or globally

## Usage Examples

### Basic Status Detection

```swift
let detector = SessionActivityDetector()

// Fast timestamp-only check
let quickStatus = detector.detectStatusFromTimestamp(session)

// Full detection with SSE refinement
let status = await detector.detectStatus(for: session, useSSE: true)
```

### In a List View

```swift
struct SessionListView: View {
    @State private var sessions: [SessionWithStatus] = []
    private let detector = SessionActivityDetector()
    
    var body: some View {
        List(sessions) { sessionWithStatus in
            SessionRow(sessionWithStatus: sessionWithStatus)
        }
        .task {
            await loadSessions()
        }
    }
    
    private func loadSessions() async {
        let sessions = await GooseAPIService.shared.fetchSessions()
        
        // Quick load with timestamp-based detection
        var withStatus: [SessionWithStatus] = []
        for session in sessions {
            let status = detector.detectStatusFromTimestamp(session)
            withStatus.append(SessionWithStatus(session: session, status: status))
        }
        self.sessions = withStatus
        
        // Refine idle sessions in background
        await refineIdleSessions()
    }
    
    private func refineIdleSessions() async {
        for (index, sessionWithStatus) in sessions.enumerated() where sessionWithStatus.status == .idle {
            let refined = await detector.detectStatus(for: sessionWithStatus.session, useSSE: true)
            sessions[index].status = refined
        }
    }
}
```

### Status Badge UI

```swift
struct SessionStatusView: View {
    let session: ChatSession
    let status: SessionStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.icon)
                .foregroundColor(statusColor)
            Text(status.displayText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }
}
```

## API Changes Required

### Enhanced ChatSession Model

The API now returns these additional fields (already in goosed API):

```json
{
  "id": "session-123",
  "description": "Debug Python app",
  "message_count": 15,
  "created_at": "2025-10-15T10:00:00Z",
  "updated_at": "2025-10-15T10:30:00Z",
  "working_dir": "/home/user/project",
  "total_tokens": 1500,
  "input_tokens": 1000,
  "output_tokens": 500,
  "accumulated_total_tokens": 5000,
  "accumulated_input_tokens": 3200,
  "accumulated_output_tokens": 1800,
  "schedule_id": null
}
```

All new fields are optional in the Swift model to maintain backward compatibility.

## Performance Considerations

### Load Time Optimization

1. **Initial Load**: Use timestamp-only detection
   - Instant display of sessions with initial status
   - Users see results immediately

2. **Background Refinement**: SSE probing for idle sessions
   - Only checks uncertain cases
   - Runs in background without blocking UI
   - Updates UI progressively as results come in

3. **Caching**: 30-second cache per session
   - Prevents redundant API calls
   - Especially useful when scrolling lists

### Network Usage

- Timestamp detection: **0 additional API calls**
- SSE probing: **1.5 seconds max** per idle session
- Typical session list (10 sessions, 2 idle):
  - Initial load: 0 additional network calls
  - Background refinement: 2 × 1.5s = 3 seconds total
  - All parallel, non-blocking

## Future Enhancements

### Potential API Improvements

If the goosed backend adds explicit status tracking:

```json
{
  "id": "session-123",
  "status": "active",  // New field
  "last_activity": "2025-10-15T10:30:00Z",
  "is_agent_running": true
}
```

This would eliminate the need for SSE probing entirely.

### Client-Side Enhancements

1. **Real-time Updates**: WebSocket connection for live status updates
2. **Smart Refresh**: Auto-refresh active sessions more frequently
3. **Status History**: Track status changes over time
4. **Notifications**: Alert when active session completes

## Testing Strategy

### Test Cases

1. **Active Session**
   - Updated < 2 minutes ago
   - Should immediately show "Active"
   - SSE should confirm activity

2. **Idle Session**
   - Updated 5-30 minutes ago
   - Should show "Idle" initially
   - SSE may upgrade to "Active" or confirm "Finished"

3. **Finished Session**
   - Updated > 30 minutes ago
   - Should show "Finished"
   - No SSE probing needed

4. **Cache Behavior**
   - Same session queried twice within 30s returns cached result
   - Cache expiration works correctly

5. **Network Failures**
   - SSE timeout handled gracefully
   - Falls back to timestamp-based detection
   - No crashes or hangs

## Migration Guide

### Updating Existing Code

If you're using the old `ChatSession` model:

```swift
// Old
struct ChatSession {
    let id: String
    let description: String
    let messageCount: Int
    let createdAt: String
    let updatedAt: String
}

// New - add working_dir and optional token fields
struct ChatSession {
    let id: String
    let description: String
    let messageCount: Int
    let createdAt: String
    let updatedAt: String
    let workingDir: String                    // NEW - required
    let totalTokens: Int?                     // NEW - optional
    let accumulatedTotalTokens: Int?          // NEW - optional
    // ... other optional fields
}
```

The API should already be returning `working_dir`, so this is just consuming existing data.

## Files

- `Goose/SessionModels.swift` - Core models and detection logic
- `Goose/SessionStatusView.swift` - UI components and examples
- `Goose/GooseAPIService.swift` - Updated mock sessions
- `Goose/ChatView.swift` - Removed duplicate ChatSession definition
