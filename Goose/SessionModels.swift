import Foundation

// MARK: - Session Status
enum SessionStatus: String {
    case active      // Currently processing (SSE detected activity or very recent update)
    case idle        // No recent activity but potentially resumable
    case finished    // Completed and idle for extended period
    
    var displayText: String {
        switch self {
        case .active: return "Active"
        case .idle: return "Idle"
        case .finished: return "Finished"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "green"
        case .idle: return "yellow"
        case .finished: return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .active: return "circle.fill"
        case .idle: return "pause.circle.fill"
        case .finished: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Enhanced Chat Session
struct ChatSession: Identifiable, Codable {
    let id: String
    let description: String
    let messageCount: Int
    let createdAt: String
    let updatedAt: String
    let workingDir: String
    
    // Optional fields that may not always be present
    let totalTokens: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let accumulatedTotalTokens: Int?
    let accumulatedInputTokens: Int?
    let accumulatedOutputTokens: Int?
    let scheduleId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case description
        case messageCount = "message_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case workingDir = "working_dir"
        case totalTokens = "total_tokens"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case accumulatedTotalTokens = "accumulated_total_tokens"
        case accumulatedInputTokens = "accumulated_input_tokens"
        case accumulatedOutputTokens = "accumulated_output_tokens"
        case scheduleId = "schedule_id"
    }
    
    // Computed properties for UI display
    var title: String {
        return description.isEmpty ? "Untitled Session" : description
    }
    
    var lastMessage: String {
        if let date = updatedDate {
            return formatRelativeDate(date)
        }
        return "Unknown"
    }
    
    var updatedDate: Date? {
        return parseDate(updatedAt)
    }
    
    var createdDate: Date? {
        return parseDate(createdAt)
    }
    
    // Try multiple date formats to handle different API responses
    private func parseDate(_ dateString: String) -> Date? {
        print("🔍 Attempting to parse date: '\(dateString)'")
        
        // Try ISO8601 with fractional seconds first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            print("✅ Parsed with ISO8601 fractional seconds: \(date)")
            return date
        }
        
        // Try without fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Try with time zone (common format from serde)
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Try standard DateFormatter as fallback
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        // Try common formats
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss.SSSSSS",
            "yyyy-MM-dd HH:mm:ss",
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        
        print("⚠️ Failed to parse date: \(dateString)")
        return nil
    }
    
    // Helper to format relative dates
    private func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

// MARK: - Session Activity Detector
class SessionActivityDetector {
    private let apiService: GooseAPIService
    private var statusCache: [String: (status: SessionStatus, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 30 // Cache results for 30 seconds
    
    // Activity thresholds
    private let activeThresholdSeconds: TimeInterval = 120    // 2 minutes - very recent
    private let idleThresholdSeconds: TimeInterval = 1800     // 30 minutes - still warm
    // Anything older than idle threshold is considered finished
    
    init(apiService: GooseAPIService = .shared) {
        self.apiService = apiService
    }
    
    /// Detect session status using multiple strategies
    func detectStatus(for session: ChatSession, useSSE: Bool = true) async -> SessionStatus {
        // Check cache first
        if let cached = statusCache[session.id],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            return cached.status
        }
        
        // Strategy 1: Check timestamp-based heuristic
        let timestampStatus = detectStatusFromTimestamp(session)
        
        // If timestamp says active (very recent), trust it immediately
        if timestampStatus == .active {
            cacheStatus(session.id, status: .active)
            return .active
        }
        
        // If timestamp says finished (very old), and we don't want to use SSE, return it
        if timestampStatus == .finished && !useSSE {
            cacheStatus(session.id, status: .finished)
            return .finished
        }
        
        // Strategy 2: For idle/uncertain cases, briefly check SSE for activity
        if useSSE {
            let sseStatus = await detectStatusFromSSE(session)
            
            // If SSE detected activity, it's definitely active
            if sseStatus == .active {
                cacheStatus(session.id, status: .active)
                return .active
            }
            
            // If SSE detected finish, use that
            if sseStatus == .finished {
                cacheStatus(session.id, status: .finished)
                return .finished
            }
        }
        
        // Fall back to timestamp status
        cacheStatus(session.id, status: timestampStatus)
        return timestampStatus
    }
    
    /// Fast detection using only timestamp (no network calls)
    func detectStatusFromTimestamp(_ session: ChatSession) -> SessionStatus {
        guard let updatedDate = session.updatedDate else {
            return .finished
        }
        
        let now = Date()
        let timeSinceUpdate = now.timeIntervalSince(updatedDate)
        
        if timeSinceUpdate < activeThresholdSeconds {
            return .active
        } else if timeSinceUpdate < idleThresholdSeconds {
            return .idle
        } else {
            return .finished
        }
    }
    
    /// Check for activity by briefly listening to SSE stream
    private func detectStatusFromSSE(_ session: ChatSession) async -> SessionStatus {
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            var detectedStatus: SessionStatus = .idle
            let timeoutSeconds: Double = 1.5
            
            // Create a timeout to ensure we don't hang forever
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { _ in
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: detectedStatus)
                }
            }
            
            // Start listening for SSE events
            Task {
                _ = await apiService.startChatStreamWithSSE(
                    messages: [],
                    sessionId: session.id,
                    onEvent: { event in
                        // Any event means the session is active
                        switch event {
                        case .message, .modelChange, .notification:
                            detectedStatus = .active
                        case .finish:
                            detectedStatus = .finished
                        case .ping:
                            detectedStatus = .idle
                        case .error:
                            break
                        }
                    },
                    onComplete: {
                        detectedStatus = .finished
                        if !hasResumed {
                            hasResumed = true
                            timeoutTimer.invalidate()
                            continuation.resume(returning: detectedStatus)
                        }
                    },
                    onError: { _ in
                        // On error, fall back to timestamp-based detection
                        if !hasResumed {
                            hasResumed = true
                            timeoutTimer.invalidate()
                            continuation.resume(returning: detectedStatus)
                        }
                    }
                )
            }
        }
    }
    
    /// Cache status for a session
    private func cacheStatus(_ sessionId: String, status: SessionStatus) {
        statusCache[sessionId] = (status: status, timestamp: Date())
    }
    
    /// Clear cache for a specific session
    func clearCache(for sessionId: String) {
        statusCache.removeValue(forKey: sessionId)
    }
    
    /// Clear all cached statuses
    func clearAllCache() {
        statusCache.removeAll()
    }
    
    /// Get cached status if available and not expired
    func getCachedStatus(for sessionId: String) -> SessionStatus? {
        guard let cached = statusCache[sessionId],
              Date().timeIntervalSince(cached.timestamp) < cacheTimeout else {
            return nil
        }
        return cached.status
    }
}

// MARK: - Session with Status
struct SessionWithStatus: Identifiable {
    let session: ChatSession
    var status: SessionStatus
    
    var id: String { session.id }
}
