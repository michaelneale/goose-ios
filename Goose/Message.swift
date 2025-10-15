import Foundation

// MARK: - Message Models
struct Message: Identifiable, Codable {
    var id: String  // Keep as non-optional for Identifiable, but handle nil from server
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
    
    // Custom decoder to handle optional id from server
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle optional id from server by providing a default UUID if nil
        if let id = try container.decodeIfPresent(String.self, forKey: .id) {
            self.id = id
        } else {
            self.id = UUID().uuidString  // Generate a unique ID if server sends nil
        }
        
        self.role = try container.decode(MessageRole.self, forKey: .role)
        self.content = try container.decode([MessageContent].self, forKey: .content)
        self.created = try container.decode(Int64.self, forKey: .created)
        self.metadata = try container.decodeIfPresent(MessageMetadata.self, forKey: .metadata)
        
        // Default values for display properties
        self.display = true
        self.sendToLLM = true
    }
    
    // Encoder remains the same
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(created, forKey: .created)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
    
    // Full initializer for creating messages in the app
    init(id: String, role: MessageRole, content: [MessageContent], created: Int64, metadata: MessageMetadata?, display: Bool = true, sendToLLM: Bool = true) {
        self.id = id
        self.role = role
        self.content = content
        self.created = created
        self.metadata = metadata
        self.display = display
        self.sendToLLM = sendToLLM
    }
    
    // Initializer without ID (generates UUID)
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
    case summarizationRequested(SummarizationRequestedContent)
    
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
        case "summarizationRequested":
            self = .summarizationRequested(try SummarizationRequestedContent(from: decoder))
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
        case .summarizationRequested(let content):
            try content.encode(to: encoder)
        }
    }
}

struct TextContent: Codable {
    let type: String
    let text: String
    
    init(text: String) {
        self.type = "text"
        self.text = text
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.text = try container.decode(String.self, forKey: .text)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, text
    }
}

struct ToolRequestContent: Codable {
    let type: String
    let id: String
    let toolCall: ToolCall
    
    init(id: String, toolCall: ToolCall) {
        self.type = "toolRequest"
        self.id = id
        self.toolCall = toolCall
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.id = try container.decode(String.self, forKey: .id)
        self.toolCall = try container.decode(ToolCall.self, forKey: .toolCall)
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
        case toolCall  // Server uses camelCase due to #[serde(rename_all = "camelCase")]
    }
}

struct ToolResponseContent: Codable {
    let type: String
    let id: String
    let toolResult: ToolResult
    
    init(id: String, toolResult: ToolResult) {
        self.type = "toolResponse"
        self.id = id
        self.toolResult = toolResult
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.id = try container.decode(String.self, forKey: .id)
        self.toolResult = try container.decode(ToolResult.self, forKey: .toolResult)
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
        case toolResult  // Server uses camelCase due to #[serde(rename_all = "camelCase")]
    }
}

struct ToolConfirmationRequestContent: Codable {
    let type: String
    let id: String
    let toolName: String
    let arguments: [String: AnyCodable]
    
    init(id: String, toolName: String, arguments: [String: AnyCodable]) {
        self.type = "toolConfirmationRequest"
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.id = try container.decode(String.self, forKey: .id)
        self.toolName = try container.decode(String.self, forKey: .toolName)
        self.arguments = try container.decode([String: AnyCodable].self, forKey: .arguments)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, id, toolName, arguments
    }
}

struct SummarizationRequestedContent: Codable {
    let type: String
    
    init() {
        self.type = "summarizationRequested"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
}

struct ToolCall: Codable {
    let name: String
    let arguments: [String: AnyCodable]
    
    // Simple initializer for creating ToolCall instances
    init(name: String, arguments: [String: AnyCodable]) {
        self.name = name
        self.arguments = arguments
    }
    
    // Handle both direct format and wrapped format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try direct format first
        if let name = try? container.decode(String.self, forKey: .name),
           let arguments = try? container.decode([String: AnyCodable].self, forKey: .arguments) {
            self.name = name
            self.arguments = arguments
        }
        // Try wrapped format (status/value structure)
        else if let status = try? container.decode(String.self, forKey: .status),
                status == "success",
                let value = try? container.decode(ToolCallValue.self, forKey: .value) {
            self.name = value.name
            self.arguments = value.arguments
        }
        // Fallback: try to decode value directly
        else if let value = try? container.decode(ToolCallValue.self, forKey: .value) {
            self.name = value.name
            self.arguments = value.arguments
        }
        else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Could not decode ToolCall from either direct or wrapped format"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode in the wrapped format that the server expects
        try container.encode("success", forKey: .status)
        let value = ToolCallValue(name: name, arguments: arguments)
        try container.encode(value, forKey: .value)
    }
    
    private enum CodingKeys: String, CodingKey {
        case name, arguments, status, value
    }
}

// Helper struct for the wrapped format
private struct ToolCallValue: Codable {
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
    let type: String
    let message: Message
    
    init(message: Message) {
        self.type = "Message"
        self.message = message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.message = try container.decode(Message.self, forKey: .message)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, message
    }
}

struct ErrorEvent: Codable {
    let type: String
    let error: String
    
    init(error: String) {
        self.type = "Error"
        self.error = error
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.error = try container.decode(String.self, forKey: .error)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, error
    }
}

struct FinishEvent: Codable {
    let type: String
    let reason: String
    
    init(reason: String) {
        self.type = "Finish"
        self.reason = reason
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.reason = try container.decode(String.self, forKey: .reason)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, reason
    }
}

struct ModelChangeEvent: Codable {
    let type: String
    let model: String
    let mode: String
    
    init(model: String, mode: String) {
        self.type = "ModelChange"
        self.model = model
        self.mode = mode
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.model = try container.decode(String.self, forKey: .model)
        self.mode = try container.decode(String.self, forKey: .mode)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, model, mode
    }
}

struct PingEvent: Codable {
    let type: String
    
    init() {
        self.type = "Ping"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
}

struct NotificationEvent: Codable {
    let type = "Notification"
    let requestId: String
    let message: NotificationMessage
    
    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
        case message
    }
}

struct NotificationMessage: Codable {
    let method: String
    let params: [String: AnyCodable]  // Make params flexible like desktop
}

// Remove the rigid NotificationParams and NotificationData structs
// since notifications can have various formats
