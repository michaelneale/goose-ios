import SwiftUI
import Markdown

struct MessageBubbleView: View {
    let message: Message
    @State private var showFullText = false
    @State private var isTruncated = false
    
    private let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.7 // 70% of screen height
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message content - only show if there's non-tool-response content
                let filteredContent = message.content.filter { !isToolResponse($0) }
                
                if !filteredContent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(filteredContent.enumerated()), id: \.offset) { index, content in
                            TruncatableMessageContentView(
                                content: content,
                                maxHeight: maxHeight,
                                showFullText: $showFullText,
                                isTruncated: $isTruncated
                            )
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user ? Color.blue : Color(.systemGray6))
                    )
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .onTapGesture {
                        if isTruncated {
                            showFullText = true
                        }
                    }
                    
                    // Timestamp
                    Text(formatTimestamp(message.created))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant {
                Spacer()
            }
        }
        .sheet(isPresented: $showFullText) {
            FullTextOverlay(content: message.content.filter { !isToolResponse($0) })
        }
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000) // Convert from milliseconds
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func isToolResponse(_ content: MessageContent) -> Bool {
        if case .toolResponse = content {
            return true
        }
        return false
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
            
        case .toolResponse(_):
            // Hide tool responses - user doesn't want to see them
            EmptyView()
            
        case .toolConfirmationRequest(let toolContent):
            ToolConfirmationView(toolContent: toolContent)
            
        case .summarizationRequested(_):
            // Hide summarization requests for now
            EmptyView()
        }
    }
}

// MARK: - Cached Markdown Text View
struct MarkdownText: View {
    let text: String
    @State private var cachedAttributedText: AttributedString?
    
    // Memory management - limit cache size
    private static var maxCacheSize = 1000 // characters
    private static var cacheCleanupThreshold = 2000 // characters
    
    var body: some View {
        Text(cachedAttributedText ?? AttributedString(text))
            .textSelection(.enabled)
            .onAppear {
                if cachedAttributedText == nil {
                    cachedAttributedText = parseMarkdown(text)
                }
            }
            .onChange(of: text) {
                // Only reparse if text changed significantly (not just appended)
                let newText = text
                if !newText.hasPrefix(text) || newText.count - text.count > 50 {
                    cachedAttributedText = parseMarkdown(newText)
                } else if let cached = cachedAttributedText {
                    // For streaming text, just append the new part
                    let newPart = String(newText.dropFirst(text.count))
                    cachedAttributedText = cached + AttributedString(newPart)
                }
            }
    }
    
    private func parseMarkdown(_ text: String) -> AttributedString {
        // Trim whitespace from the input text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // For large texts, only parse the last portion to avoid blocking
        let textToParse = trimmedText.count > 1000 ? String(trimmedText.suffix(1000)) : trimmedText
        
        // Parse the markdown using swift-markdown
        let document = Document(parsing: textToParse)
        
        // Convert to AttributedString with proper formatting
        var attributedString = AttributedString()
        
        for child in document.children {
            attributedString.append(processMarkdownElement(child))
        }
        
        // Return the result, using trimmed text as fallback
        if attributedString.characters.isEmpty {
            return AttributedString(trimmedText)
        }
        
        return attributedString
    }
    
    private func processMarkdownElement(_ element: Markup) -> AttributedString {
        var result = AttributedString()
        
        switch element {
        case let paragraph as Paragraph:
            for child in paragraph.children {
                if let inlineChild = child as? InlineMarkup {
                    result.append(processInlineMarkup(inlineChild))
                }
            }
            result.append(AttributedString("\n"))
            
        case let heading as Heading:
            var headingText = AttributedString()
            for child in heading.children {
                if let inlineChild = child as? InlineMarkup {
                    headingText.append(processInlineMarkup(inlineChild))
                }
            }
            headingText.font = .system(size: max(20 - CGFloat(heading.level) * 2, 14), weight: .bold)
            result.append(headingText)
            result.append(AttributedString("\n"))
            
        case let codeBlock as CodeBlock:
            var codeText = AttributedString(codeBlock.code)
            codeText.font = .monospaced(.body)()
            codeText.backgroundColor = .secondary.opacity(0.1)
            result.append(codeText)
            result.append(AttributedString("\n"))
            
        case let listItem as ListItem:
            result.append(AttributedString("• "))
            for child in listItem.children {
                result.append(processMarkdownElement(child))
            }
            
        default:
            // Handle other block elements
            if let blockElement = element as? BlockMarkup {
                for child in blockElement.children {
                    result.append(processMarkdownElement(child))
                }
            }
        }
        
        return result
    }
    
    private func processInlineMarkup(_ element: InlineMarkup) -> AttributedString {
        switch element {
        case let text as Markdown.Text:
            return AttributedString(text.plainText)
            
        case let strong as Strong:
            var strongText = AttributedString()
            for child in strong.children {
                if let inlineChild = child as? InlineMarkup {
                    strongText.append(processInlineMarkup(inlineChild))
                }
            }
            strongText.font = .body.bold()
            return strongText
            
        case let emphasis as Emphasis:
            var emphasisText = AttributedString()
            for child in emphasis.children {
                if let inlineChild = child as? InlineMarkup {
                    emphasisText.append(processInlineMarkup(inlineChild))
                }
            }
            emphasisText.font = .body.italic()
            return emphasisText
            
        case let inlineCode as InlineCode:
            var codeText = AttributedString(inlineCode.code)
            codeText.font = .monospaced(.body)()
            codeText.backgroundColor = .secondary.opacity(0.1)
            return codeText
            
        case let link as Markdown.Link:
            var linkText = AttributedString()
            for child in link.children {
                if let inlineChild = child as? InlineMarkup {
                    linkText.append(processInlineMarkup(inlineChild))
                }
            }
            linkText.foregroundColor = .blue
            linkText.underlineStyle = .single
            if let destination = link.destination {
                linkText.link = URL(string: destination)
            }
            return linkText
            
        default:
            // Fallback for other inline elements
            return AttributedString(element.plainText)
        }
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
    ScrollView {
        VStack(spacing: 16) {
            // Basic message examples
            MessageBubbleView(message: Message(role: .user, text: "Hello, can you help me with **markdown** and `code`?"))
            MessageBubbleView(message: Message(role: .assistant, text: "Sure! I can help you with **bold text**, `inline code`, and other formatting."))
            
            // Comprehensive markdown test examples
            MessageBubbleView(message: Message(role: .assistant, text: """
# Markdown Test

Here are various **formatting** examples:

## Text Styles
- **Bold text**
- *Italic text* 
- `Inline code`
- ***Bold and italic***

## Code Block
```swift
func testFunction() {
    print("Hello World")
}
```

## Links
Visit [Apple](https://apple.com) for more info.

## Lists
• First item
• Second **bold** item
• Third `code` item

*This tests comprehensive markdown rendering.*
"""))
            
            MessageBubbleView(message: Message(role: .user, text: """
Testing more complex markdown:

### Headings Work?
#### Smaller Heading
##### Even Smaller

Mixed content: **bold** with *italic* and `code` plus [links](https://github.com).

```python
# Code blocks with different languages
def hello_world():
    return "Hello from Python!"
```

**Note**: This should all render properly.
"""))
        }
        .padding()
    }
}

// MARK: - Tool Call Progress View
struct ToolCallProgressView: View {
    let toolCall: ToolCall
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(toolCall.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let firstArgument = getFirstArgument() {
                        Text(firstArgument)
                            .font(.caption2)
                            .monospaced()
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            )
            
            Text("executing...")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.6)
    }
    
    private func getFirstArgument() -> String? {
        guard let firstKey = toolCall.arguments.keys.sorted().first,
              let firstValue = toolCall.arguments[firstKey] else {
            return nil
        }
        
        let valueString = String(describing: firstValue.value)
        // Truncate if too long
        return valueString.count > 50 ? String(valueString.prefix(50)) + "..." : valueString
    }
}

// MARK: - Completed Tool Call View
struct CompletedToolCallView: View {
    let completedCall: CompletedToolCall
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: completedCall.result.status == "success" ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(completedCall.result.status == "success" ? .green : .red)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(completedCall.toolCall.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let firstArgument = getFirstArgument() {
                        Text(firstArgument)
                            .font(.caption2)
                            .monospaced()
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 4) {
                        Text(String(format: "%.2fs", completedCall.duration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(completedCall.result.status)
                            .font(.caption2)
                            .foregroundColor(completedCall.result.status == "success" ? .green : .red)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(completedCall.result.status == "success" ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
            
            Text(formatCompletionTime(completedCall.completedAt))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.6)
    }
    
    private func getFirstArgument() -> String? {
        guard let firstKey = completedCall.toolCall.arguments.keys.sorted().first,
              let firstValue = completedCall.toolCall.arguments[firstKey] else {
            return nil
        }
        
        let valueString = String(describing: firstValue.value)
        // Truncate if too long
        return valueString.count > 50 ? String(valueString.prefix(50)) + "..." : valueString
    }
    
    private func formatCompletionTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "completed \(formatter.string(from: date))"
    }
}

// MARK: - Truncatable Message Content View
struct TruncatableMessageContentView: View {
    let content: MessageContent
    let maxHeight: CGFloat
    @Binding var showFullText: Bool
    @Binding var isTruncated: Bool
    
    var body: some View {
        switch content {
        case .text(let textContent):
            TruncatableMarkdownText(
                text: textContent.text,
                maxHeight: maxHeight,
                isTruncated: $isTruncated
            )
            .textSelection(.enabled)
            
        case .toolRequest(let toolContent):
            ToolRequestView(toolContent: toolContent)
            
        case .toolResponse(_):
            // Hide tool responses - user doesn't want to see them
            EmptyView()
            
        case .toolConfirmationRequest(let toolContent):
            ToolConfirmationView(toolContent: toolContent)
            
        case .summarizationRequested(_):
            // Hide summarization requests for now
            EmptyView()
        }
    }
}

// MARK: - Truncatable Markdown Text View
struct TruncatableMarkdownText: View {
    let text: String
    let maxHeight: CGFloat
    @Binding var isTruncated: Bool
    @State private var fullHeight: CGFloat = 0
    
    var body: some View {
        Text(parseMarkdown(text))
            .textSelection(.enabled)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            fullHeight = geometry.size.height
                            isTruncated = fullHeight > maxHeight
                        }
                        .onChange(of: geometry.size.height) {
                            fullHeight = geometry.size.height
                            isTruncated = fullHeight > maxHeight
                        }
                }
            )
            .frame(maxHeight: isTruncated ? maxHeight : nil)
            .clipped()
            .overlay(
                // Show gradient fade and "tap to expand" if truncated
                Group {
                    if isTruncated {
                        VStack {
                            Spacer()
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color(.systemGray6)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 30)
                            .overlay(
                                Text("Tap to expand")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 4)
                            )
                        }
                    }
                }
            )
    }
    
    private func parseMarkdown(_ text: String) -> AttributedString {
        // Same markdown parsing logic as before
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = Document(parsing: trimmedText)
        var attributedString = AttributedString()
        
        for child in document.children {
            attributedString.append(processMarkdownElement(child))
        }
        
        if attributedString.characters.isEmpty {
            return AttributedString(trimmedText)
        }
        
        return attributedString
    }
    
    private func processMarkdownElement(_ element: Markup) -> AttributedString {
        var result = AttributedString()
        
        switch element {
        case let paragraph as Paragraph:
            for child in paragraph.children {
                if let inlineChild = child as? InlineMarkup {
                    result.append(processInlineMarkup(inlineChild))
                }
            }
            result.append(AttributedString("\n"))
            
        case let heading as Heading:
            var headingText = AttributedString()
            for child in heading.children {
                if let inlineChild = child as? InlineMarkup {
                    headingText.append(processInlineMarkup(inlineChild))
                }
            }
            headingText.font = .system(size: max(20 - CGFloat(heading.level) * 2, 14), weight: .bold)
            result.append(headingText)
            result.append(AttributedString("\n"))
            
        case let codeBlock as CodeBlock:
            var codeText = AttributedString(codeBlock.code)
            codeText.font = .monospaced(.body)()
            codeText.backgroundColor = .secondary.opacity(0.1)
            result.append(codeText)
            result.append(AttributedString("\n"))
            
        case let listItem as ListItem:
            result.append(AttributedString("• "))
            for child in listItem.children {
                result.append(processMarkdownElement(child))
            }
            
        default:
            if let blockElement = element as? BlockMarkup {
                for child in blockElement.children {
                    result.append(processMarkdownElement(child))
                }
            }
        }
        
        return result
    }
    
    private func processInlineMarkup(_ element: InlineMarkup) -> AttributedString {
        switch element {
        case let text as Markdown.Text:
            return AttributedString(text.plainText)
            
        case let strong as Strong:
            var strongText = AttributedString()
            for child in strong.children {
                if let inlineChild = child as? InlineMarkup {
                    strongText.append(processInlineMarkup(inlineChild))
                }
            }
            strongText.font = .body.bold()
            return strongText
            
        case let emphasis as Emphasis:
            var emphasisText = AttributedString()
            for child in emphasis.children {
                if let inlineChild = child as? InlineMarkup {
                    emphasisText.append(processInlineMarkup(inlineChild))
                }
            }
            emphasisText.font = .body.italic()
            return emphasisText
            
        case let inlineCode as InlineCode:
            var codeText = AttributedString(inlineCode.code)
            codeText.font = .monospaced(.body)()
            codeText.backgroundColor = .secondary.opacity(0.1)
            return codeText
            
        case let link as Markdown.Link:
            var linkText = AttributedString()
            for child in link.children {
                if let inlineChild = child as? InlineMarkup {
                    linkText.append(processInlineMarkup(inlineChild))
                }
            }
            linkText.foregroundColor = .blue
            linkText.underlineStyle = .single
            if let destination = link.destination {
                linkText.link = URL(string: destination)
            }
            return linkText
            
        default:
            return AttributedString(element.plainText)
        }
    }
}

// MARK: - Full Text Overlay
struct FullTextOverlay: View {
    let content: [MessageContent]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(content.enumerated()), id: \.offset) { index, messageContent in
                        MessageContentView(content: messageContent)
                    }
                }
                .padding()
            }
            .navigationTitle("Full Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
