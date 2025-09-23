import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message content
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(message.content.enumerated()), id: \.offset) { index, content in
                        MessageContentView(content: content)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(message.role == .user ? Color.blue : Color(.systemGray6))
                )
                .foregroundColor(message.role == .user ? .white : .primary)
                
                // Timestamp
                Text(formatTimestamp(message.created))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000) // Convert from milliseconds
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MessageContentView: View {
    let content: MessageContent
    
    var body: some View {
        switch content {
        case .text(let textContent):
            MarkdownText(text: textContent.text)
                .textSelection(.enabled)
            
        case .toolRequest(let toolContent):
            ToolRequestView(toolContent: toolContent)
            
        case .toolResponse(let toolContent):
            ToolResponseView(toolContent: toolContent)
            
        case .toolConfirmationRequest(let toolContent):
            ToolConfirmationView(toolContent: toolContent)
        }
    }
}

// MARK: - Markdown Text View
struct MarkdownText: View {
    let text: String
    
    var body: some View {
        // For now, we'll use a simple text view
        // In a production app, you'd want to use a proper markdown renderer
        Text(parseSimpleMarkdown(text))
            .textSelection(.enabled)
    }
    
    private func parseSimpleMarkdown(_ text: String) -> AttributedString {
        // For now, let's use a simpler approach that doesn't cause compilation errors
        // This can be improved later with a proper markdown library
        
        // Replace markdown syntax with plain text for now
        var processedText = text
        processedText = processedText.replacingOccurrences(of: "**", with: "")
        processedText = processedText.replacingOccurrences(of: "`", with: "")
        
        var attributedString = AttributedString(processedText)
        
        // TODO: Implement proper markdown parsing with a library like swift-markdown
        // For now, we'll just display the text without formatting
        
        return attributedString
    }
}

// MARK: - Tool Views
struct ToolRequestView: View {
    let toolContent: ToolRequestContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(.orange)
                Text("Tool Request: \(toolContent.toolCall.name)")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            if !toolContent.toolCall.arguments.isEmpty {
                Text("Arguments:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                ForEach(Array(toolContent.toolCall.arguments.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text("• \(key):")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(String(describing: toolContent.toolCall.arguments[key]?.value))")
                            .font(.caption2)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ToolResponseView: View {
    let toolContent: ToolResponseContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: toolContent.toolResult.status == "success" ? "checkmark.circle" : "xmark.circle")
                    .foregroundColor(toolContent.toolResult.status == "success" ? .green : .red)
                Text("Tool Response")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            if let error = toolContent.toolResult.error {
                Text("Error: \(error)")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
            
            if let value = toolContent.toolResult.value {
                Text("Result: \(String(describing: value.value))")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
        }
        .padding(8)
        .background((toolContent.toolResult.status == "success" ? Color.green : Color.red).opacity(0.1))
        .cornerRadius(8)
    }
}

struct ToolConfirmationView: View {
    let toolContent: ToolConfirmationRequestContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.blue)
                Text("Permission Request")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            Text("Allow \(toolContent.toolName)?")
                .font(.body)
                .fontWeight(.medium)
            
            if !toolContent.arguments.isEmpty {
                Text("Arguments:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                ForEach(Array(toolContent.arguments.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text("• \(key):")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(String(describing: toolContent.arguments[key]?.value))")
                            .font(.caption2)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
            
            HStack(spacing: 12) {
                Button("Deny") {
                    // TODO: Implement permission response
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Button("Allow Once") {
                    // TODO: Implement permission response
                }
                .buttonStyle(.bordered)
                
                Button("Always Allow") {
                    // TODO: Implement permission response
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(message: Message(role: .user, text: "Hello, can you help me with **markdown** and `code`?"))
        MessageBubbleView(message: Message(role: .assistant, text: "Sure! I can help you with **bold text**, `inline code`, and other formatting."))
    }
    .padding()
}
