# Network Resilience for ChatView Streaming

## Current Architecture

### iOS Client (goose-ios)

**ChatView.swift** is the main view that handles chat interactions:
- Uses `GooseAPIService.shared` for all API communication
- Manages streaming state with `currentStreamTask: URLSessionDataTask?`
- Has `isLoading` state to track active operations
- Session management through `currentSessionId`

**GooseAPIService.swift** handles the API layer:
- `startChatStreamWithSSE()` - Main streaming function that:
  - Creates URLRequest to `/reply` endpoint
  - Sets up SSE (Server-Sent Events) headers
  - Uses custom `SSEDelegate` to handle streaming data
  - Returns `URLSessionDataTask` for cancellation control
  - Has `isRetry: Bool` parameter (currently unused)

**SSEDelegate** (lines 667-784):
- Parses SSE stream line-by-line
- Buffers incomplete lines
- Decodes JSON events and calls callbacks
- Handles completion and errors

### Server API (goose-server)

**reply.rs** endpoint (`/reply`):
- SSE streaming endpoint
- Takes `ChatRequest` with messages and session_id
- Returns stream of `MessageEvent` types:
  - `Message` - Incremental message content
  - `Error` - Error events
  - `Finish` - Stream completion
  - `ModelChange` - Model changes
  - `Notification` - MCP notifications
  - `Ping` - Heartbeat every 500ms
- **Key**: Session state is maintained server-side
- **Key**: Messages are already persisted when streamed

## Current Flow

### New Session Start
1. ChatView calls `sendMessage()`
2. `startChatStream()` checks if `currentSessionId == nil`
3. Calls `apiService.startAgent()` to create session
4. Updates provider/model from config
5. Extends system prompt for iOS
6. Loads enabled extensions
7. Stores `currentSessionId`
8. Calls `startChatStreamWithSSE()` with messages + sessionId
9. Server streams responses via SSE

### Session Resume (from sidebar)
1. User selects session from sidebar
2. ChatView.`loadSession(sessionId)` called
3. Calls `apiService.resumeAgent(sessionId)` 
4. **Returns full message history** from server
5. Updates provider/model/prompt/extensions (same as new session)
6. Displays all messages
7. Ready for new streaming when user sends message

### Active Streaming
1. Server sends SSE events line by line
2. SSEDelegate buffers and parses data
3. Calls `handleSSEEvent()` callback on main thread
4. ChatView updates `messages` array
5. UI auto-scrolls during streaming
6. Tool calls tracked separately in `activeToolCalls` and `completedToolCalls`

## The Problem

**When network fails during streaming:**

Currently:
- `SSEDelegate.urlSession(_:task:didCompleteWithError:)` is called
- Calls `onError` callback
- ChatView shows error message in chat
- Stream stops permanently
- User must manually retry by sending another message

**Issues:**
1. ❌ Partial assistant responses are lost (not saved to server)
2. ❌ No automatic retry mechanism
3. ❌ User doesn't know if message was partially processed
4. ❌ Must re-send entire message (may duplicate work)

## What We Want

**Robust streaming that:**
1. ✅ Automatically retries on network failure
2. ✅ Resumes from where it left off
3. ✅ Shows connection status to user
4. ✅ Handles session start failures gracefully
5. ✅ Doesn't duplicate work or re-process messages

## The Challenge

### Server-Side Reality
- The `/reply` endpoint is **stateless for the stream itself**
- Each call to `/reply` processes the entire message list
- Session state (conversation history) is persisted server-side
- **BUT**: In-progress streaming responses are NOT persisted until complete

### Desktop UI Approach
The desktop app (ui/desktop) has a "resume" function but it's different:
- It's for loading a past session, not resuming an interrupted stream
- Calls `/agent/resume` to get session metadata + full message history
- Then starts fresh if user sends new message

### What This Means
To resume streaming after network failure, we have options:

#### Option 1: Polling Fallback
- On network failure, fall back to polling `/sessions/{id}` endpoint
- Check for new messages periodically
- Display when complete
- **Pros**: Simple, server already has the data
- **Cons**: Loses real-time feel, no progress indication, wastes requests

#### Option 2: Retry from Last Known State
- On network failure, retry `/reply` with the same message list
- Server reprocesses from scratch
- **Pros**: Eventually gets the full response
- **Cons**: Duplicates server work, may see partial responses twice

#### Option 3: Reload Messages on Failure
- On network failure, call `/agent/resume` to fetch updated messages
- Check if response completed server-side while we were disconnected
- If incomplete, retry streaming with exponential backoff
- **Pros**: Gracefully handles both transient and persistent failures
- **Cons**: More complex, requires message diffing

#### Option 4: Stream Checkpointing (Requires Server Changes)
- Server persists partial assistant responses
- Client can resume from last checkpoint
- **Pros**: True resumption, no duplicate work
- **Cons**: Requires server-side changes to reply.rs

## Recommended Approach

### Phase 1: Retry with Exponential Backoff (Immediate)

**When to retry:**
- Network failures during streaming
- Connection timeouts
- HTTP 500 errors (server errors)

**When NOT to retry:**
- HTTP 4xx errors (client errors, bad request, auth failure)
- User cancellation (stop button)
- Session switching

**Implementation:**
```swift
// In GooseAPIService.swift
func startChatStreamWithSSE(
    messages: [Message],
    sessionId: String? = nil,
    workingDirectory: String = "/tmp",
    onEvent: @escaping (SSEEvent) -> Void,
    onComplete: @escaping () -> Void,
    onError: @escaping (Error) -> Void,
    retryAttempt: Int = 0,  // Add this
    maxRetries: Int = 3     // Add this
) async -> URLSessionDataTask? {
    // ... existing code ...
    
    // Replace simple error handler with retry logic
    let retryHandler: (Error) -> Void = { error in
        // Check if we should retry
        guard retryAttempt < maxRetries else {
            onError(error)
            return
        }
        
        // Check error type - only retry network errors
        let shouldRetry = isRetryableError(error)
        guard shouldRetry else {
            onError(error)
            return
        }
        
        // Exponential backoff: 1s, 2s, 4s
        let delay = pow(2.0, Double(retryAttempt))
        print("⚠️ Stream failed, retrying in \(delay)s (attempt \(retryAttempt + 1)/\(maxRetries))")
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            _ = await startChatStreamWithSSE(
                messages: messages,
                sessionId: sessionId,
                workingDirectory: workingDirectory,
                onEvent: onEvent,
                onComplete: onComplete,
                onError: onError,
                retryAttempt: retryAttempt + 1,
                maxRetries: maxRetries
            )
        }
    }
    
    let delegate = SSEDelegate(
        onEvent: onEvent,
        onComplete: onComplete,
        onError: retryHandler  // Use retry handler instead
    )
    // ... rest of existing code ...
}

private func isRetryableError(_ error: Error) -> Bool {
    // Network errors: connection lost, timeout, etc.
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .timedOut,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
    
    // HTTP 5xx errors
    if case let APIError.httpError(code, _) = error {
        return code >= 500
    }
    
    return false
}
```

**In ChatView.swift:**
```swift
// Add retry state
@State private var streamRetryCount = 0
@State private var showingRetryIndicator = false

private func startChatStream() {
    Task {
        do {
            // ... existing session setup ...
            
            currentStreamTask = await apiService.startChatStreamWithSSE(
                messages: messages,
                sessionId: sessionId,
                workingDirectory: "/tmp",
                onEvent: { event in
                    // Reset retry count on successful event
                    streamRetryCount = 0
                    showingRetryIndicator = false
                    handleSSEEvent(event)
                },
                onComplete: {
                    isLoading = false
                    currentStreamTask = nil
                    streamRetryCount = 0
                    showingRetryIndicator = false
                },
                onError: { error in
                    // Show retry indicator if retrying
                    if streamRetryCount < 3 {
                        streamRetryCount += 1
                        showingRetryIndicator = true
                    } else {
                        // Max retries exceeded
                        isLoading = false
                        currentStreamTask = nil
                        streamRetryCount = 0
                        showingRetryIndicator = false
                        
                        let errorMessage = Message(
                            role: .assistant,
                            text: "❌ Connection failed after multiple retries: \(error.localizedDescription)"
                        )
                        messages.append(errorMessage)
                    }
                },
                retryAttempt: streamRetryCount
            )
        } catch {
            // ... existing error handling ...
        }
    }
}
```

**UI Changes:**
```swift
// In ChatView body, show retry indicator
if showingRetryIndicator {
    HStack {
        ProgressView()
            .scaleEffect(0.8)
        Text("Connection lost, retrying... (\(streamRetryCount)/3)")
            .font(.caption)
            .foregroundColor(.orange)
        Spacer()
    }
    .padding(.horizontal)
    .id("retry-indicator")
}
```

### Phase 2: Message Reload After Failure (Enhanced)

If retries fail, offer to reload session state:

```swift
private func handleStreamFailure() {
    // Show option to reload session
    let alert = UIAlertController(
        title: "Connection Lost",
        message: "Unable to complete streaming. Would you like to check for updates?",
        preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(title: "Reload", style: .default) { _ in
        Task {
            await reloadSessionMessages()
        }
    })
    
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    
    // Present alert
}

private func reloadSessionMessages() async {
    guard let sessionId = currentSessionId else { return }
    
    do {
        // Fetch latest messages from server
        let (_, latestMessages) = try await apiService.resumeAgent(sessionId: sessionId)
        
        await MainActor.run {
            // Diff with current messages to see what's new
            let newMessages = latestMessages.filter { latest in
                !messages.contains { $0.id == latest.id }
            }
            
            if !newMessages.isEmpty {
                print("✅ Found \(newMessages.count) new messages from server")
                messages.append(contentsOf: newMessages)
                
                // Show success message
                let notice = Message(
                    role: .assistant,
                    text: "✅ Reconnected and loaded latest messages"
                )
                messages.append(notice)
            } else {
                print("⚠️ No new messages found - response may be incomplete")
            }
        }
    } catch {
        print("🚨 Failed to reload messages: \(error)")
    }
}
```

### Phase 3: Proactive Connection Monitoring (Future)

Monitor connection health and prevent failures:

```swift
import Network

class ConnectionMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// In ChatView:
@StateObject private var connectionMonitor = ConnectionMonitor()

// Show warning before sending if offline
if !connectionMonitor.isConnected {
    // Show "No connection" warning
    // Disable send button or queue message
}
```

## Does We Need Polling Mode?

**Short answer: Not immediately, but it's a good fallback.**

**Polling would be useful for:**
1. Extremely unstable connections where streaming fails repeatedly
2. Background processing - check if task completed while app was suspended
3. Fallback for older iOS versions with SSE issues (unlikely)

**Polling implementation:**
```swift
func pollForCompletion(sessionId: String, lastMessageCount: Int) async {
    var attempts = 0
    let maxAttempts = 60  // 5 minutes at 5s intervals
    
    while attempts < maxAttempts {
        try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
        
        do {
            let (_, messages) = try await apiService.resumeAgent(sessionId: sessionId)
            
            if messages.count > lastMessageCount {
                // New messages arrived!
                await MainActor.run {
                    self.messages = messages
                    print("✅ Polling found \(messages.count - lastMessageCount) new messages")
                }
                break
            }
            
            attempts += 1
        } catch {
            print("⚠️ Poll attempt failed: \(error)")
            attempts += 1
        }
    }
}
```

**When to use polling:**
1. After 3 failed stream retry attempts
2. When app returns to foreground after being backgrounded during active stream
3. User manually requests "check for updates"

## Session Start/Resume Robustness

The current `startChatStream()` and `loadSession()` functions have multiple failure points:

### Current Issues
1. If `startAgent()` fails → user stuck with error, must restart
2. If `updateProvider()` fails → session created but wrong model
3. If `extendSystemPrompt()` fails → session works but missing iOS context
4. If `loadEnabledExtensions()` fails → session works but missing tools
5. If initial streaming fails → partial session state

### Improved Error Handling

```swift
private func startChatStream() {
    Task {
        do {
            // Track what succeeded for cleanup on failure
            var sessionCreated = false
            var providerUpdated = false
            
            if currentSessionId == nil {
                // Step 1: Create session (critical)
                do {
                    let (sessionId, initialMessages) = try await apiService.startAgent(workingDir: "/tmp")
                    currentSessionId = sessionId
                    sessionCreated = true
                    
                    if !initialMessages.isEmpty {
                        await MainActor.run {
                            messages = initialMessages
                        }
                    }
                } catch {
                    // CRITICAL FAILURE - can't proceed
                    throw SessionError.creationFailed(error)
                }
                
                guard let sessionId = currentSessionId else {
                    throw SessionError.invalidSession
                }
                
                // Step 2: Configure provider (important but not critical)
                do {
                    if let provider = await apiService.readConfigValue(key: "GOOSE_PROVIDER"),
                       let model = await apiService.readConfigValue(key: "GOOSE_MODEL") {
                        try await apiService.updateProvider(sessionId: sessionId, provider: provider, model: model)
                        providerUpdated = true
                    }
                } catch {
                    // NON-CRITICAL - log and continue with default provider
                    print("⚠️ Failed to set custom provider, using default: \(error)")
                }
                
                // Step 3: Extend prompt (nice to have)
                do {
                    try await apiService.extendSystemPrompt(sessionId: sessionId)
                } catch {
                    // NON-CRITICAL - iOS context missing but functional
                    print("⚠️ Failed to extend prompt: \(error)")
                }
                
                // Step 4: Load extensions (nice to have)
                do {
                    try await apiService.loadEnabledExtensions(sessionId: sessionId)
                } catch {
                    // NON-CRITICAL - fewer tools but functional
                    print("⚠️ Failed to load extensions: \(error)")
                }
            }
            
            // Step 5: Start streaming (critical)
            guard let sessionId = currentSessionId else {
                throw SessionError.invalidSession
            }
            
            currentStreamTask = await apiService.startChatStreamWithSSE(
                messages: messages,
                sessionId: sessionId,
                workingDirectory: "/tmp",
                onEvent: { event in
                    handleSSEEvent(event)
                },
                onComplete: {
                    isLoading = false
                    currentStreamTask = nil
                },
                onError: { error in
                    // Handle with retry logic (Phase 1)
                    handleStreamError(error)
                }
            )
            
        } catch {
            await MainActor.run {
                isLoading = false
                
                let errorMessage: String
                if let sessionError = error as? SessionError {
                    errorMessage = sessionError.userMessage
                } else {
                    errorMessage = "Failed to start session: \(error.localizedDescription)"
                }
                
                messages.append(Message(
                    role: .assistant,
                    text: "❌ \(errorMessage)"
                ))
                
                // Offer retry button in UI
                showingRetryOption = true
            }
        }
    }
}

enum SessionError: Error {
    case creationFailed(Error)
    case invalidSession
    case configurationFailed(Error)
    
    var userMessage: String {
        switch self {
        case .creationFailed(let error):
            return "Could not create session: \(error.localizedDescription). Please check your connection and try again."
        case .invalidSession:
            return "Session is invalid. Please try restarting the app."
        case .configurationFailed(let error):
            return "Session created but configuration failed: \(error.localizedDescription). Some features may not work."
        }
    }
}
```

## Summary

### Immediate Actions (Phase 1) - ✅ COMPLETED
1. ✅ Add retry logic with exponential backoff to `startChatStreamWithSSE()`
   - **Implementation**: Modified `GooseAPIService.swift` lines 26-101
   - Removed `maxRetries` parameter - now retries indefinitely until user leaves screen
   - Exponential backoff: 1s → 2s → 4s → 8s → 16s → capped at 30s
   - Added `isRetryableError()` helper (lines 829-850) to check network/server errors
   - Only retries on: URLError network errors, HTTP 5xx server errors
   - Does NOT retry on: HTTP 4xx client errors
2. ✅ Track retry count in ChatView
   - Uses `retryAttempt` parameter recursively
   - No artificial limit - continues until success or user action
3. ✅ Show retry indicator in UI
   - **Note**: Current implementation doesn't show retry count in UI (could be added)
   - Retry happens transparently in background
4. ✅ Only retry on network errors, not client errors
   - `isRetryableError()` filters appropriately

### Session Resume Enhancement - ✅ COMPLETED
**Problem**: When loading a session from sidebar, if goose is still processing (last message from user < 5 minutes old), user couldn't see progress.

**Solution**: Implemented "faux streaming" via polling (ChatView.swift lines 540-617)
1. ✅ Added `shouldPollForUpdates()` - checks if last message is from user & recent
2. ✅ Added `startPollingForUpdates()` - polls `/agent/resume` every 3-5 seconds
3. ✅ Added `stopPollingForUpdates()` - cleanup on user action or timeout
4. ✅ UI indicator: "🔄 Catching up..." (lines 78-87) shown in orange
5. ✅ Auto-scrolls when new messages detected
6. ✅ Polls for ~20 seconds (7 checks) before assuming done
7. ✅ Exponential backoff: 3s initially, increases to 5s after 2 checks with no change
8. ✅ Stops polling when user sends new message (upgrades to real-time SSE)
9. ✅ Integrated in `loadSession()` (lines 711-719)

**Key Design Decision**: Used REST polling (`/agent/resume`) instead of SSE probing because:
- SSE `/reply` requires message payload - empty messages could corrupt server state
- SSE is request-response, not passive monitoring
- Cannot safely probe other sessions via SSE
- REST polling is simpler and safer

### Near-term (Phase 2)
1. Add message reload after retry failures
2. Improve session start error handling with fallback configurations
3. Add user option to "check for updates" manually

### Future (Phase 3)
1. Add connection monitoring to prevent failures
2. Implement polling fallback for unstable connections
3. Background refresh when app returns to foreground
4. Consider server-side changes for true stream resumption

### What About Desktop's "Resume"?
Desktop's resume is different - it's for **loading historical sessions**, not **recovering from network failures**. We already have this via `loadSession()`.

For network resilience, we need **retry + reload**, which is a different pattern focused on the current active streaming operation.

## Implementation Priority

1. **Critical**: Retry with backoff (prevents most failures)
2. **Important**: Better session start error handling (prevents stuck states)
3. **Nice to have**: Message reload (handles edge cases)
4. **Future**: Connection monitoring (proactive prevention)
5. **Optional**: Polling mode (fallback for worst-case scenarios)

---

## APPENDIX: Understanding "New Streaming Request"

### What is a Streaming Request?

A "streaming request" is just a normal HTTP POST, but with a response that streams data incrementally using Server-Sent Events (SSE).

**Regular HTTP:**
```
POST → Server processes (5s) → Complete response arrives at once
```

**SSE Streaming:**
```
POST → HTTP 200 + headers → chunk 1 → chunk 2 → chunk 3 → ... → "Finish" event
Connection stays open, data arrives incrementally
```

### Network Layer Breakdown

**Initial Stream:**
```
Application:  startChatStreamWithSSE()
    ↓
URLSession:   task = URLSessionDataTask(request)
    ↓
TCP:          socket_fd_42 = socket()
              connect(socket_fd_42, server_ip, 62996)
              send(socket_fd_42, "POST /reply HTTP/1.1\r\n...")
              recv(socket_fd_42, buffer)  ← "data: {chunk1}\n\n"
              recv(socket_fd_42, buffer)  ← "data: {chunk2}\n\n"
              ❌ recv() returns error - connection lost
```

**Network Failure:**
```
TCP:          socket_fd_42 [DEAD - cannot be revived]
    ↓
URLSession:   SSEDelegate.didCompleteWithError(error)
    ↓
Application:  onError callback triggered
```

**Retry = Brand New Connection:**
```
Application:  startChatStreamWithSSE() [CALLED AGAIN]
    ↓
URLSession:   task = URLSessionDataTask(request) [NEW OBJECT]
    ↓
TCP:          socket_fd_87 = socket() [NEW SOCKET]
              connect(socket_fd_87, server_ip, 62996) [NEW CONNECTION]
              send(socket_fd_87, "POST /reply HTTP/1.1\r\n...") [NEW REQUEST]
              recv(socket_fd_87, buffer) [NEW RESPONSE]
```

### Each Retry Creates Completely New Objects

```swift
// ATTEMPT 1 (before failure)
let delegate1 = SSEDelegate(...)        // Object A
let session1 = URLSession(delegate: delegate1)  // Object B
let task1 = session1.dataTask(urlRequest)       // Object C → Socket FD 42
task1.resume()
// ❌ Network fails - all these objects are now useless

// ATTEMPT 2 (retry)
let delegate2 = SSEDelegate(...)        // Object D (NEW!)
let session2 = URLSession(delegate: delegate2)  // Object E (NEW!)
let task2 = session2.dataTask(urlRequest)       // Object F (NEW!) → Socket FD 87
task2.resume()
```

**Nothing is shared or "reconnected"** - it's a fresh start at every layer.

### The Server-Side Problem

When the server receives a retry, it compares incoming messages to stored session:

```rust
// In goose-server/src/agents/agent.rs
match incoming.len().cmp(&stored.len()) {
    Equal => { 
        // Same length - OK
    }
    Greater if incoming.len() == stored.len() + 1 => { 
        // One new message - OK, add it
    }
    _ => {
        // ⚠️ Unexpected state!
        // If client has FEWER messages than server (e.g. retry without response)
        // Server will REPLACE stored conversation with incoming
        // This DELETES the response server just generated!
        warn!("Unexpected session state: stored={}, incoming={}. Replacing.",
              stored.len(), incoming.len());
        SessionManager::replace_conversation(&session_id, &incoming).await?;
    }
}
```

**The bug**: If we retry sending only `[user_message]` after the server already has `[user_message, assistant_response]`, the server will **delete its own response** and regenerate from scratch!

### The Correct Retry Implementation

We must **check server state before retrying**:

```swift
private func handleStreamError(_ error: Error) {
    guard streamRetryCount < 3 else { /* max retries */ }
    
    streamRetryCount += 1
    showingRetryIndicator = true
    
    Task {
        // Wait with exponential backoff
        let delay = pow(2.0, Double(streamRetryCount - 1))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // CRITICAL: Check server state BEFORE retrying
        let (_, serverMessages) = try await apiService.resumeAgent(
            sessionId: currentSessionId!
        )
        
        await MainActor.run {
            // Diff: does server have messages we don't?
            let currentIds = Set(messages.map { $0.id })
            let newMessages = serverMessages.filter { !currentIds.contains($0.id) }
            
            if !newMessages.isEmpty {
                // Server finished while we were disconnected!
                print("✅ Response completed on server")
                messages.append(contentsOf: newMessages)
                isLoading = false
                showingRetryIndicator = false
                return  // Done - no need to retry!
            }
            
            // Response still incomplete - retry streaming
            print("⚠️ Retrying stream with server's message list")
            currentStreamTask = await apiService.startChatStreamWithSSE(
                messages: serverMessages,  // Use SERVER'S state, not ours!
                sessionId: currentSessionId!,
                workingDirectory: "/tmp",
                onEvent: { event in handleSSEEvent(event) },
                onComplete: { /* ... */ },
                onError: { error in handleStreamError(error) }  // Recursive
            )
        }
    }
}
```

### Why This Works

```
Network fails during streaming
    ↓
Wait 1s (exponential backoff)
    ↓
GET /agent/resume → Fetch server's current session state
    ↓
Compare server's messages to client's messages
    ↓
┌─────────────────────────────────────┬──────────────────────────────────────┐
│ Server has NEW messages             │ Server has SAME messages             │
│ (response completed server-side)    │ (response incomplete)                │
├─────────────────────────────────────┼──────────────────────────────────────┤
│ ✅ Just append to UI                │ Continue ↓                           │
│ ✅ Done - no retry needed!          │                                      │
└─────────────────────────────────────┴──────────────────────────────────────┘
                                          ↓
                            POST /reply with server's message list
                                          ↓
                            Creates NEW URLSessionDataTask
                                          ↓
                            Opens NEW TCP socket
                                          ↓
                            Sends NEW HTTP request
                                          ↓
                            Receives NEW SSE stream
                                          ↓
                            Chunks arrive from beginning
```

### Summary

**"New streaming request" is:**

1. **Not a reconnection** - the old TCP socket is dead forever
2. **A brand new HTTP POST** - same endpoint, same parameters
3. **Creates new objects** - new URLSession, URLSessionDataTask, SSEDelegate
4. **Opens new socket** - different file descriptor, new TCP connection
5. **Gets new response** - server sends data from the beginning again

**The key insight**: We don't repair the broken stream. We **check if server finished without us**, and if not, we **start over** with a fresh request that reflects the current server state.
