import Foundation

// MARK: - Message Models
struct Message: Identifiable, Codable {
    var id: String
    let role: MessageRole
    let content: [MessageContent]
    let created: Int64
    let metadata: MessageMetadata?
    var display: Bool
    var sendToLLM: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case created
        case metadata
    }
    
    // Full initializer for server messages
    init(id: String, role: MessageRole, content: [MessageContent], created: Int64, metadata: MessageMetadata?, display: Bool = true, sendToLLM: Bool = true) {
        self.id = id
        self.role = role
        self.content = content
        self.created = created
        self.metadata = metadata
        self.display = display
        self.sendToLLM = sendToLLM
    }
    
    init(role: MessageRole, content: [MessageContent], created: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        self.role = role
        self.content = content
        self.created = created
        self.id = UUID().uuidString
        self.metadata = nil
        self.display = true
        self.sendToLLM = true
    }
    
    // Convenience initializer for text messages
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        role = try container.decode(MessageRole.self, forKey: .role)
        content = try container.decode([MessageContent].self, forKey: .content)
        created = try container.decode(Int64.self, forKey: .created)
        metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)
        
        // Set default values for fields not in server response
        display = true
        sendToLLM = true
    }
    
    // Custom encoder (if needed)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(created, forKey: .created)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
    
    // Convenience initializer for text messages
    init(role: MessageRole, text: String, created: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        self.role = role
        self.content = [MessageContent.text(TextContent(text: text))]
        self.created = created
        self.id = UUID().uuidString
        self.metadata = nil
        self.display = true
        self.sendToLLM = true
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Message Metadata
struct MessageMetadata: Codable {
    let userVisible: Bool
    let agentVisible: Bool
    
    enum CodingKeys: String, CodingKey {
        case userVisible
        case agentVisible
    }
}

// MARK: - Message Content
enum MessageContent: Codable {
    case text(TextContent)
    case toolRequest(ToolRequestContent)
    case toolResponse(ToolResponseContent)
    case toolConfirmationRequest(ToolConfirmationRequestContent)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            self = .text(try TextContent(from: decoder))
        case "toolRequest":
            self = .toolRequest(try ToolRequestContent(from: decoder))
        case "toolResponse":
            self = .toolResponse(try ToolResponseContent(from: decoder))
        case "toolConfirmationRequest":
            self = .toolConfirmationRequest(try ToolConfirmationRequestContent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown message content type: \(type)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try content.encode(to: encoder)
        case .toolRequest(let content):
            try content.encode(to: encoder)
        case .toolResponse(let content):
            try content.encode(to: encoder)
        case .toolConfirmationRequest(let content):
            try content.encode(to: encoder)
        }
    }
}

struct TextContent: Codable {
    let type = "text"
    let text: String
}

struct ToolRequestContent: Codable {
    let type = "toolRequest"
    let id: String
    let toolCall: ToolCall
}

struct ToolResponseContent: Codable {
    let type = "toolResponse"
    let id: String
    let toolResult: ToolResult
}

struct ToolConfirmationRequestContent: Codable {
    let type = "toolConfirmationRequest"
    let id: String
    let toolName: String
    let arguments: [String: AnyCodable]
}

struct ToolCall: Codable {
    let name: String
    let arguments: [String: AnyCodable]
}

struct ToolResult: Codable {
    let status: String
    let value: AnyCodable?
    let error: String?
}

// MARK: - Helper for Any Codable
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Chat Request/Response Models
struct ChatRequest: Codable {
    let messages: [Message]
    let sessionId: String?
    let sessionWorkingDir: String
    let scheduledJobId: String?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case sessionId = "session_id"
        case sessionWorkingDir = "session_working_dir"
        case scheduledJobId = "scheduled_job_id"
    }
}

// MARK: - SSE Event Models
enum SSEEvent: Codable {
    case message(MessageEvent)
    case error(ErrorEvent)
    case finish(FinishEvent)
    case modelChange(ModelChangeEvent)
    case notification(NotificationEvent)
    case ping(PingEvent)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "Message":
            self = .message(try MessageEvent(from: decoder))
        case "Error":
            self = .error(try ErrorEvent(from: decoder))
        case "Finish":
            self = .finish(try FinishEvent(from: decoder))
        case "ModelChange":
            self = .modelChange(try ModelChangeEvent(from: decoder))
        case "Notification":
            self = .notification(try NotificationEvent(from: decoder))
        case "Ping":
            self = .ping(try PingEvent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown SSE event type: \(type)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .message(let event):
            try event.encode(to: encoder)
        case .error(let event):
            try event.encode(to: encoder)
        case .finish(let event):
            try event.encode(to: encoder)
        case .modelChange(let event):
            try event.encode(to: encoder)
        case .notification(let event):
            try event.encode(to: encoder)
        case .ping(let event):
            try event.encode(to: encoder)
        }
    }
}

struct MessageEvent: Codable {
    let type = "Message"
    let message: Message
}

struct ErrorEvent: Codable {
    let type = "Error"
    let error: String
}

struct FinishEvent: Codable {
    let type = "Finish"
    let reason: String
}

struct ModelChangeEvent: Codable {
    let type = "ModelChange"
    let model: String
    let mode: String
}

struct PingEvent: Codable {
    let type = "Ping"
}

struct NotificationEvent: Codable {
    let type = "Notification"
    let requestId: String
    let message: String // Simplified for now
    
    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
        case message
    }
}
