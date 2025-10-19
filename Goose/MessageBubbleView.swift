import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let completedTasks: [CompletedToolCall]
    let sessionName: String
    @State private var showFullText = false
    @State private var isTruncated = false
    
    // Maximum height for truncation - about 70% of screen like PR #11
    private let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.7
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message content - filter out tool responses AND tool requests (we'll show them as pills)
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
            
            // Show consolidated task completion pill if there are completed tasks (PR #1 style)
            if !completedTasks.isEmpty {
                CompletedTasksSummaryView(completedTasks: completedTasks, message: message, sessionName: sessionName)
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
            Text(textContent.text)
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
    var isUserMessage: Bool = false
    @State private var codeBlocks: [(language: String, code: String)] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // First render code blocks separately
            ForEach(Array(codeBlocks.enumerated()), id: \.offset) { _, codeBlock in
                CollapsibleCodePreviewView(code: codeBlock.code, language: codeBlock.language)
            }
            
            // Render markdown content with proper formatting
            let textWithoutCode = extractCodeBlocksAndRemove()
            if !textWithoutCode.isEmpty {
                FormattedMarkdownView(text: textWithoutCode)
            }
        }
        .onAppear {
            extractCodeBlocksAndParse()
        }
    }
    
    private func extractCodeBlocksAndParse() {
        codeBlocks = extractCodeBlocks(from: text)
    }
    
    private func extractCodeBlocksAndRemove() -> String {
        let codeBlockPattern = "```[\\s\\S]*?```"
        let regex = try? NSRegularExpression(pattern: codeBlockPattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex?.stringByReplacingMatches(in: text, range: range, withTemplate: "") ?? text
    }
    
    private func extractCodeBlocks(from content: String) -> [(language: String, code: String)] {
        let codeBlockPattern = "```(\\w*)\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: codeBlockPattern) else { return [] }
        
        var blocks: [(language: String, code: String)] = []
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        
        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match = match, match.numberOfRanges == 3 else { return }
            
            let languageRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            
            let language = languageRange.location != NSNotFound ? 
                (content as NSString).substring(with: languageRange) : ""
            let code = (content as NSString).substring(with: codeRange)
            
            blocks.append((language: language, code: code))
        }
        
        return blocks
    }
}

// MARK: - Formatted Markdown View with Proper Indentation
struct FormattedMarkdownView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(parseMarkdownLines().enumerated()), id: \.offset) { _, line in
                renderMarkdownLine(line)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .textSelection(.enabled)
    }
    
    private func parseMarkdownLines() -> [MarkdownLine] {
        let lines = text.components(separatedBy: .newlines)
        var result: [MarkdownLine] = []
        
        for line in lines {
            // Skip empty lines but preserve them for spacing
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(.empty)
                continue
            }
            
            // Count leading spaces to detect nesting level
            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            let indentLevel = leadingSpaces / 2 // 2 spaces = 1 indent level
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check for bullet points
            if trimmedLine.hasPrefix("- ") {
                let content = String(trimmedLine.dropFirst(2))
                result.append(.bullet(content, indentLevel: indentLevel))
            } else if trimmedLine.hasPrefix("• ") {
                let content = String(trimmedLine.dropFirst(2))
                result.append(.bullet(content, indentLevel: indentLevel))
            } else if trimmedLine.hasPrefix("* ") {
                let content = String(trimmedLine.dropFirst(2))
                result.append(.bullet(content, indentLevel: indentLevel))
            } else if let match = trimmedLine.range(of: "^\\d+\\. ", options: .regularExpression) {
                // Numbered lists (1. 2. etc)
                let numberPart = String(trimmedLine[match])
                let endIndex = trimmedLine.index(match.lowerBound, offsetBy: numberPart.count)
                let content = String(trimmedLine[endIndex...])
                result.append(.numbered(numberPart, content, indentLevel: indentLevel))
            } else {
                result.append(.text(trimmedLine, indentLevel: indentLevel))
            }
        }
        
        return result
    }
    
    @ViewBuilder
    private func renderMarkdownLine(_ line: MarkdownLine) -> some View {
        switch line {
        case .empty:
            Spacer()
                .frame(height: 4)
            
        case .bullet(let content, let indentLevel):
            HStack(alignment: .top, spacing: 10) {
                Text("•")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 14, alignment: .leading)
                
                Text(content)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .padding(.leading, CGFloat(indentLevel) * 20) // 20pt per indent level
            
        case .numbered(let number, let content, let indentLevel):
            HStack(alignment: .top, spacing: 10) {
                Text(number)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .frame(width: 24, alignment: .leading)
                
                Text(content)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .padding(.leading, CGFloat(indentLevel) * 20) // 20pt per indent level
            
        case .text(let content, let indentLevel):
            Text(content)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
                .padding(.leading, CGFloat(indentLevel) * 20) // 20pt per indent level
        }
    }
    
    enum MarkdownLine {
        case empty
        case bullet(String, indentLevel: Int)
        case numbered(String, String, indentLevel: Int)
        case text(String, indentLevel: Int)
    }
}

// MARK: - Tool Views
struct CollapsibleToolRequestView: View {
    let toolContent: ToolRequestContent
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Tool: \(toolContent.toolCall.name)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if !isExpanded && !toolContent.toolCall.arguments.isEmpty {
                        Text("(\(toolContent.toolCall.arguments.count) args)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded && !toolContent.toolCall.arguments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .padding(.horizontal, 8)
                    
                    Text("Arguments:")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                    
                    ForEach(Array(toolContent.toolCall.arguments.keys.sorted()), id: \.self) { key in
                        HStack(alignment: .top) {
                            Text("\(key):")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 60, alignment: .trailing)
                            
                            Text("\(String(describing: toolContent.toolCall.arguments[key]?.value))")
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                    }
                    .padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// Keep original for compatibility if needed
struct ToolRequestView: View {
    let toolContent: ToolRequestContent
    
    var body: some View {
        CollapsibleToolRequestView(toolContent: toolContent)
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

struct CollapsibleToolConfirmationView: View {
    let toolContent: ToolConfirmationRequestContent
    @State private var isExpanded: Bool = true // Start expanded for permission requests
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("Permission: \(toolContent.toolName)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if !isExpanded {
                        Text("(action required)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .padding(8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 8)
                    
                    Text("Allow \(toolContent.toolName)?")
                        .font(.body)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                    
                    if !toolContent.arguments.isEmpty {
                        Text("Arguments:")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                        
                        ForEach(Array(toolContent.arguments.keys.sorted()), id: \.self) { key in
                            HStack(alignment: .top) {
                                Text("\(key):")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 60, alignment: .trailing)
                                
                                Text("\(String(describing: toolContent.arguments[key]?.value))")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// Keep original for compatibility if needed
struct ToolConfirmationView: View {
    let toolContent: ToolConfirmationRequestContent
    
    var body: some View {
        CollapsibleToolConfirmationView(toolContent: toolContent)
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
}

// MARK: - Completed Tool Pill View (PR #1 style - navigable)
struct CompletedToolPillView: View {
    let completedCall: CompletedToolCall
    let message: Message
    let sessionName: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationLink(destination: TaskDetailView(
            message: message,
            completedTasks: [completedCall],
            sessionName: sessionName
        ).environmentObject(ThemeManager.shared)) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(completedCall.toolCall.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeManager.chatInputBackgroundColor.opacity(0.85))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
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



// MARK: - Truncatable Message Content View
struct TruncatableMessageContentView: View {
    let content: MessageContent
    let maxHeight: CGFloat
    @Binding var showFullText: Bool
    @Binding var isTruncated: Bool
    let isUserMessage: Bool
    
    var body: some View {
        switch content {
        case .text(let textContent):
            // Use MarkdownText for proper markdown rendering  
            MarkdownText(text: textContent.text, isUserMessage: isUserMessage)
                .lineSpacing(8)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
        case .toolRequest(_):
            // Hide tool requests - they'll be shown as consolidated pills
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
    @State private var displayText: String = ""
    
    // Configuration for smart truncation
    private let maxPreviewLines = 8  // Show more lines (6-8 depending on content)
    private let showLastLines = true // Show last lines instead of first
    
    var body: some View {
        Text(AttributedString(displayText.isEmpty ? text : displayText))
            .textSelection(.enabled)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            fullHeight = geometry.size.height
                            updateTruncation()
                        }
                        .onChange(of: geometry.size.height) { oldValue, newValue in
                            fullHeight = geometry.size.height
                            updateTruncation()
                        }
                        .onChange(of: text) { oldValue, newValue in
                            updateTruncation()
                        }
                }
            )
            .overlay(
                // Show indicator if truncated
                Group {
                    if isTruncated {
                        VStack {
                            // Show fade from top since we're showing last lines
                            if showLastLines {
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(.systemGray6).opacity(0.9), Color.clear]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 30)
                                .overlay(
                                    Text("Tap to see more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 6),
                                    alignment: .top
                                )
                                
                                Spacer()
                            } else {
                                // Original bottom fade for first lines
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
                                        .padding(.bottom, 4),
                                    alignment: .bottom
                                )
                            }
                        }
                    }
                }
            )
    }
    
    private func updateTruncation() {
        // Split text into lines for smarter truncation
        let lines = text.components(separatedBy: .newlines)
        
        // If text is short enough, show everything
        if lines.count <= maxPreviewLines || fullHeight <= maxHeight {
            displayText = text
            isTruncated = false
            return
        }
        
        // Text needs truncation
        isTruncated = true
        
        if showLastLines {
            // Show the last N lines (often contains conclusion/summary)
            let lastLines = lines.suffix(maxPreviewLines)
            
            // Just show the last lines without adding extra text
            displayText = "…\n" + lastLines.joined(separator: "\n")
        } else {
            // Show first N lines (traditional approach)
            let firstLines = lines.prefix(maxPreviewLines)
            displayText = firstLines.joined(separator: "\n") + "\n…"
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

// MARK: - Collapsible Code Preview View
struct CollapsibleCodePreviewView: View {
    let code: String
    let language: String
    @State private var isExpanded = false
    @EnvironmentObject var themeManager: ThemeManager
    
    private var lines: [String] {
        code.components(separatedBy: .newlines)
    }
    
    private var previewLines: [String] {
        Array(lines.prefix(5))
    }
    
    private var hasMoreLines: Bool {
        lines.count > 5
    }
    
    private var moreLineCount: Int {
        max(0, lines.count - 5)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    Image(systemName: "code")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(language.isEmpty ? "Code" : language)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    if hasMoreLines && !isExpanded {
                        Text("(\(moreLineCount) more lines)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Code preview
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    ScrollView(.horizontal) {
                        Text(code)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding(12)
                    }
                    .frame(maxHeight: 300)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(previewLines.enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.chatInputBackgroundColor.opacity(0.85))
        )
    }
}

// MARK: - Completed Tasks Summary View (Collapsible)
struct CompletedTasksSummaryView: View {
    let completedTasks: [CompletedToolCall]
    let message: Message
    let sessionName: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("Executed \(completedTasks.count) tool\(completedTasks.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded pills list
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(completedTasks.enumerated()), id: \.offset) { index, completedTask in
                            CompletedToolPillView(completedCall: completedTask, message: message, sessionName: sessionName)
                        }
                    }
                    .padding(12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
