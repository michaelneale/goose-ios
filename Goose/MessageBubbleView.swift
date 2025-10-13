import SwiftUI
import Markdown

struct MessageBubbleView: View {
    let message: Message
    let completedTasks: [CompletedToolCall]
    @State private var showFullText = false
    @State private var isTruncated = false
    @EnvironmentObject var themeManager: ThemeManager
    
    private let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.7 // 70% of screen height
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message content - filter out tool responses AND tool requests (we'll show them consolidated)
            let filteredContent = message.content.filter { 
                !isToolResponse($0) && !isToolRequest($0)
            }
            
            if !filteredContent.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(filteredContent.enumerated()), id: \.offset) { index, content in
                        TruncatableMessageContentView(
                            content: content,
                            maxHeight: maxHeight,
                            showFullText: $showFullText,
                            isTruncated: $isTruncated,
                            isUserMessage: message.role == .user
                        )
                    }
                }
            }
            
            // Show consolidated task completion pill if there are completed tasks
            if !completedTasks.isEmpty {
                // Show all completed tools as collapsible items
                ForEach(completedTasks, id: \.toolCall.name) { completedTask in
                    CompletedToolPillView(completedCall: completedTask)
                        .environmentObject(themeManager)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private func isToolRequest(_ content: MessageContent) -> Bool {
        if case .toolRequest = content {
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
// Compact pill view for tool requests
struct CompactToolRequestPill: View {
    let toolContent: ToolRequestContent
    let completedTasks: [CompletedToolCall]
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.secondaryTextColor)
            
            Text("\(completedTasks.count) Task\(completedTasks.count == 1 ? "" : "s") completed")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.secondaryTextColor)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(themeManager.isDarkMode ? Color(red: 0.13, green: 0.13, blue: 0.13) : Color(red: 0.97, green: 0.97, blue: 0.97))
        .cornerRadius(16)
        .frame(maxWidth: 200)
    }
}

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
            MessageBubbleView(message: Message(role: .user, text: "Hello, can you help me with **markdown** and `code`?"), completedTasks: [], sessionName: "Test Session")
            MessageBubbleView(message: Message(role: .assistant, text: "Sure! I can help you with **bold text**, `inline code`, and other formatting."), completedTasks: [], sessionName: "Test Session")
            
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
"""), completedTasks: [], sessionName: "Test Session")
            
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
"""), completedTasks: [], sessionName: "Test Session")
        }
        .padding()
    }
    .environmentObject(ThemeManager.shared)
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
    let isUserMessage: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        switch content {
        case .text(let textContent):
            Text(textContent.text)
                .font(.system(size: 16, weight: isUserMessage ? .bold : .regular))
                .lineSpacing(8)
                .foregroundColor(themeManager.primaryTextColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            
        case .toolRequest(_):
            // Tool requests are now shown as consolidated pills in MessageBubbleView
            EmptyView()
            
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
