import Foundation

/// Chat session state - matches desktop implementation
enum ChatState: String, Codable {
    case idle = "idle"
    case thinking = "thinking"
    case streaming = "streaming"
    case waitingForUserInput = "waitingForUserInput"
    case compacting = "compacting"
    case loadingConversation = "loadingConversation"
    
    /// Human-readable description for UI
    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .thinking:
            return "Thinking..."
        case .streaming:
            return "Responding..."
        case .waitingForUserInput:
            return "Waiting for approval"
        case .compacting:
            return "Compacting history..."
        case .loadingConversation:
            return "Loading..."
        }
    }
    
    /// Icon for UI display
    var icon: String {
        switch self {
        case .idle:
            return "checkmark.circle.fill"
        case .thinking:
            return "brain"
        case .streaming:
            return "arrow.down.circle"
        case .waitingForUserInput:
            return "hand.raised.fill"
        case .compacting:
            return "arrow.3.trianglepath"
        case .loadingConversation:
            return "arrow.clockwise"
        }
    }
    
    /// Whether this state indicates the session is actively processing
    var isProcessing: Bool {
        switch self {
        case .thinking, .streaming, .compacting, .loadingConversation:
            return true
        case .idle, .waitingForUserInput:
            return false
        }
    }
    
    /// Whether this state indicates waiting for user action
    var isWaitingForUser: Bool {
        return self == .waitingForUserInput
    }
    
    /// Whether this state indicates the session is complete/idle
    var isIdle: Bool {
        return self == .idle
    }
}

/// Helper to determine chat state from messages
extension ChatState {
    /// Determine state from current messages and tool calls
    static func from(messages: [Message], activeToolCalls: [String: ToolCallWithTiming]) -> ChatState {
        guard let lastMessage = messages.last else {
            return .idle
        }
        
        // Check for pending tool confirmation requests
        let hasPendingToolConfirmation = lastMessage.content.contains {
            if case .toolConfirmationRequest = $0 { return true }
            return false
        }
        
        if hasPendingToolConfirmation {
            return .waitingForUserInput
        }
        
        // Check for compacting notification
        let hasCompactingNotification = lastMessage.content.contains {
            if case .conversationCompacted = $0 { return true }
            return false
        }
        
        if hasCompactingNotification {
            return .compacting
        }
        
        // Check for thinking state (last message from user, or has active tool calls)
        if lastMessage.role == .user || !activeToolCalls.isEmpty {
            return .thinking
        }
        
        // Otherwise idle
        return .idle
    }
}
