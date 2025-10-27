import SwiftUI
import Markdown


// MARK: - Markdown Text View with Table and Code Block Support
struct MarkdownText: View {
    let text: String
    var isUserMessage: Bool = false
    @State private var cachedAttributedText: AttributedString?
    @State private var tables: [TableData] = []
    @State private var codeBlocks: [CodeBlockData] = []
    @State private var previousText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Regular markdown text
            if let attributedText = cachedAttributedText, !attributedText.characters.isEmpty {
                Group {
                    if isUserMessage {
                        Text(attributedText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(attributedText)
                            .font(.system(size: 14, weight: .regular))
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                    }
                }
            }
            
            // Render code blocks
            ForEach(codeBlocks) { codeBlock in
                CodeBlockView(codeBlock: codeBlock)
            }
            
            // Render tables - they handle their own positioning and scrolling
            ForEach(tables) { table in
                MarkdownTableView(tableData: table)
                    .padding(.leading, -28)  // Break out of container padding
                    .padding(.trailing, -28) // Break out to allow full-width scrolling
            }
        }
        .onAppear {
            if cachedAttributedText == nil {
                parseContent()
            }
        }
        .onChange(of: text) { _, newText in
            // For streaming, check if we need to reparse
            let hasTable = newText.contains("|") && newText.contains("---")
            let hadTable = previousText.contains("|") && previousText.contains("---")
            let hasCodeBlock = newText.contains("```")
            let hadCodeBlock = previousText.contains("```")
            
            if !newText.hasPrefix(previousText) || (hasTable && !hadTable) || (hasCodeBlock && !hadCodeBlock) {
                // Text changed significantly or special content detected - reparse
                withAnimation(.easeOut(duration: 0.15)) {
                    parseContent()
                }
            } else if newText != previousText {
                // Simple append for streaming
                let delta = String(newText.dropFirst(previousText.count))
                if let cached = cachedAttributedText {
                    if delta.contains("**") || delta.contains("*") || delta.contains("`") || 
                       delta.contains("[") || delta.contains("#") || delta.contains("\n\n") {
                        withAnimation(.easeOut(duration: 0.15)) {
                            parseContent()
                        }
                    } else {
                        // Plain text - just append efficiently
                        withAnimation(.easeOut(duration: 0.1)) {
                            cachedAttributedText = cached + AttributedString(delta)
                        }
                    }
                } else {
                    parseContent()
                }
            }
            previousText = newText
        }
        .animation(.easeOut(duration: 0.1), value: cachedAttributedText)
    }
    
    private func parseContent() {
        // Extract tables and code blocks first
        tables = MarkdownParser.extractTables(text)
        codeBlocks = MarkdownParser.extractCodeBlocks(text)
        
        // Parse the rest as attributed string (tables and code blocks will be skipped)
        cachedAttributedText = MarkdownParser.parseWithoutTablesAndCodeBlocks(text)
        previousText = text
    }
}




struct MarkdownParser {
    static func parse(_ text: String) -> AttributedString {
        let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let document = Document(parsing: trimmedText)
        
        var attributedString = AttributedString()
        for child in document.children {
            attributedString.append(processElement(child))
        }
        
        // Trim trailing newlines for cleaner output
        while attributedString.characters.last == "\n" {
            attributedString = AttributedString(attributedString.characters.dropLast())
        }
        
        return attributedString.characters.isEmpty ? AttributedString(trimmedText) : attributedString
    }
    
    private static func processElement(_ element: Markup) -> AttributedString {
        var result = AttributedString()
        
        switch element {
        case let paragraph as Paragraph:
            for child in paragraph.children {
                if let inlineChild = child as? InlineMarkup {
                    result.append(processInline(inlineChild))
                }
            }
            result.append(AttributedString("\n\n"))
            
        case let heading as Heading:
            var headingText = AttributedString()
            for child in heading.children {
                if let inlineChild = child as? InlineMarkup {
                    headingText.append(processInline(inlineChild))
                }
            }
            headingText.font = .system(size: max(18 - CGFloat(heading.level) * 2, 14), weight: .bold)
            result.append(headingText)
            result.append(AttributedString("\n\n"))
            
        case let codeBlock as CodeBlock:
            var codeText = AttributedString(codeBlock.code)
            codeText.font = .system(size: 14, design: .monospaced)
            codeText.backgroundColor = .secondary.opacity(0.1)
            result.append(codeText)
            result.append(AttributedString("\n\n"))
            
        case let list as UnorderedList:
            for child in list.children {
                result.append(processElement(child))
            }
            result.append(AttributedString("\n\n"))  // Paragraph break after list
            
        case let list as OrderedList:
            for child in list.children {
                result.append(processElement(child))
            }
            result.append(AttributedString("\n\n"))  // Paragraph break after list
            
        case let listItem as ListItem:
            result.append(AttributedString("• "))
            for child in listItem.children {
                var childResult = processElement(child)
                // Strip trailing newlines from list item content
                while childResult.characters.last == "\n" {
                    childResult = AttributedString(childResult.characters.dropLast())
                }
                result.append(childResult)
            }
            // Add a smaller line break for tighter spacing
            var smallBreak = AttributedString("\n")
            smallBreak.font = .system(size: 7)  // Half the normal 14pt font
            result.append(smallBreak)
        default:
            if let blockElement = element as? BlockMarkup {
                for child in blockElement.children {
                    result.append(processElement(child))
                }
            }
        }
        
        return result
    }
    
    private static func processInline(_ element: InlineMarkup) -> AttributedString {
        switch element {
        case let text as Markdown.Text:
            return AttributedString(text.plainText)
            
        case let strong as Strong:
            var strongText = AttributedString()
            for child in strong.children {
                if let inlineChild = child as? InlineMarkup {
                    strongText.append(processInline(inlineChild))
                }
            }
            strongText.font = .system(size: 14, weight: .bold)
            return strongText
            
        case let emphasis as Emphasis:
            var emphasisText = AttributedString()
            for child in emphasis.children {
                if let inlineChild = child as? InlineMarkup {
                    emphasisText.append(processInline(inlineChild))
                }
            }
            emphasisText.font = .system(size: 14).italic()
            return emphasisText
            
        case let inlineCode as InlineCode:
            var codeText = AttributedString(inlineCode.code)
            codeText.font = .system(size: 14, design: .monospaced)
            codeText.backgroundColor = .secondary.opacity(0.1)
            return codeText
            
        case let link as Markdown.Link:
            var linkText = AttributedString()
            for child in link.children {
                if let inlineChild = child as? InlineMarkup {
                    linkText.append(processInline(inlineChild))
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
    
    // MARK: - Table Support
    
    /// Extract all tables from markdown text
    static func extractTables(_ text: String) -> [TableData] {
        let document = Document(parsing: text)
        var tables: [TableData] = []
        
        func findTables(in element: Markup) {
            if let table = element as? Markdown.Table {
                if let tableData = extractTableData(from: table) {
                    tables.append(tableData)
                }
            }
            
            // Recursively search children
            for child in element.children {
                findTables(in: child)
            }
        }
        
        for child in document.children {
            findTables(in: child)
        }
        
        return tables
    }
    
    /// Extract table data from a Table markup element

    /// Extract table data from a Table markup element
    private static func extractTableData(from table: Markdown.Table) -> TableData? {
        var headers: [String] = []
        var rows: [[String]] = []
        var alignments: [TextAlignment] = []
        
        // Extract headers from table head
        let head = table.head
        for cell in head.cells {
            headers.append(cell.plainText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
        }
        
        // Extract column alignments
        for columnIndex in 0..<table.columnAlignments.count {
            let alignment = table.columnAlignments[columnIndex]
            switch alignment {
            case .left:
                alignments.append(.leading)
            case .center:
                alignments.append(.center)
            case .right:
                alignments.append(.trailing)
            default:
                alignments.append(.leading)
            }
        }
        
        // Extract data rows from table body
        let body = table.body
        for row in body.rows {
            var rowData: [String] = []
            for cell in row.cells {
                rowData.append(cell.plainText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
            }
            // Ensure row has same number of columns as headers
            while rowData.count < headers.count {
                rowData.append("")
            }
            rows.append(rowData)
        }
        
        // Only return if we have headers and at least one row
        guard !headers.isEmpty, !rows.isEmpty else { return nil }
        
        return TableData(headers: headers, rows: rows, columnAlignments: alignments)
    }

    static func parseWithoutTables(_ text: String) -> AttributedString {
        let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let document = Document(parsing: trimmedText)
        
        var attributedString = AttributedString()
        for child in document.children {
            // Skip tables - they'll be rendered as SwiftUI views
            if child is Markdown.Table {
                continue
            }
            attributedString.append(processElement(child))
        }
        
        // Trim trailing newlines
        while attributedString.characters.last == "\n" {
            attributedString = AttributedString(attributedString.characters.dropLast())
        }
        
        return attributedString.characters.isEmpty ? AttributedString(trimmedText) : attributedString
    }
    
    // MARK: - Code Block Support
    
    /// Extract all code blocks from markdown text
    static func extractCodeBlocks(_ text: String) -> [CodeBlockData] {
        let document = Document(parsing: text)
        var codeBlocks: [CodeBlockData] = []
        
        func findCodeBlocks(in element: Markup) {
            if let codeBlock = element as? CodeBlock {
                let language = codeBlock.language
                codeBlocks.append(CodeBlockData(code: codeBlock.code, language: language))
            }
            
            // Recursively search children
            for child in element.children {
                findCodeBlocks(in: child)
            }
        }
        
        for child in document.children {
            findCodeBlocks(in: child)
        }
        
        return codeBlocks
    }
    
    /// Parse markdown without rendering code blocks (they'll be rendered separately)
    static func parseWithoutTablesAndCodeBlocks(_ text: String) -> AttributedString {
        let trimmedText = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let document = Document(parsing: trimmedText)
        
        var attributedString = AttributedString()
        for child in document.children {
            // Skip tables and code blocks - they'll be rendered as SwiftUI views
            if child is Markdown.Table || child is CodeBlock {
                continue
            }
            attributedString.append(processElement(child))
        }
        
        // Trim trailing newlines
        while attributedString.characters.last == "\n" {
            attributedString = AttributedString(attributedString.characters.dropLast())
        }
        
        return attributedString.characters.isEmpty ? AttributedString(trimmedText) : attributedString
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
                    ForEach(Array(content.enumerated()), id: \.offset) { _, messageContent in
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

// MARK: - Tool Call Progress View

struct ToolCallProgressView: View {
    let toolCall: ToolCall
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with tool name and spinner
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                
                Text(toolCall.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Arguments snippet
            if !toolCall.arguments.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(getArgumentSnippets()), id: \.key) { item in
                        HStack(alignment: .top, spacing: 4) {
                            Text("\(item.key):")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text(item.value)
                                .font(.caption2)
                                .monospaced()
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.leading, 24) // Align with text after spinner
            }
            
            // Status text
            Text("executing...")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 24)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7)
    }
    
    private func getArgumentSnippets() -> [(key: String, value: String)] {
        let maxArgs = 3 // Show up to 3 arguments
        let maxValueLength = 40 // Truncate values longer than this
        
        return toolCall.arguments
            .sorted { $0.key < $1.key }
            .prefix(maxArgs)
            .map { key, value in
                let valueString = String(describing: value.value)
                let truncated = valueString.count > maxValueLength 
                    ? String(valueString.prefix(maxValueLength)) + "..." 
                    : valueString
                return (key: key, value: truncated)
            }
    }
}


// MARK: - Code Block Data Model

struct CodeBlockData: Hashable, Identifiable {
    let id = UUID()
    let code: String
    let language: String?
    
    init(code: String, language: String? = nil) {
        self.code = code
        self.language = language
    }
}

// MARK: - Code Block View Component

struct CodeBlockView: View {
    let codeBlock: CodeBlockData
    @Environment(\.colorScheme) var colorScheme
    
    private let fontSize: CGFloat = 13
    private let padding: CGFloat = 12
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Language label if available - with colored badge
                if let language = codeBlock.language, !language.isEmpty {
                    HStack(spacing: 6) {
                        Text(language.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(languageColor)
                            .cornerRadius(4)
                        
                        Spacer()
                    }
                    .padding(.horizontal, padding)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
                
                // Code content
                Text(codeBlock.code)
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundColor(codeTextColor)
                    .padding(padding)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    // Language-specific colors for badges
    private var languageColor: Color {
        guard let language = codeBlock.language?.lowercased() else {
            return .gray
        }
        
        switch language {
        case "swift":
            return Color.orange
        case "python", "py":
            return Color.blue
        case "javascript", "js", "typescript", "ts":
            return Color.yellow.opacity(0.8)
        case "ruby", "rb":
            return Color.red
        case "rust", "rs":
            return Color.orange.opacity(0.8)
        case "go":
            return Color.cyan
        case "java", "kotlin":
            return Color.orange.opacity(0.7)
        case "c", "cpp", "c++":
            return Color.blue.opacity(0.7)
        case "shell", "bash", "sh", "zsh":
            return Color.green
        case "json":
            return Color.purple.opacity(0.7)
        case "xml", "html":
            return Color.orange.opacity(0.6)
        case "css", "scss":
            return Color.blue.opacity(0.6)
        case "sql":
            return Color.indigo
        case "markdown", "md":
            return Color.gray
        default:
            return Color.gray
        }
    }
    
    private var backgroundColor: Color {
        guard let language = codeBlock.language?.lowercased() else {
            return defaultBackgroundColor
        }
        
        // Subtle tinted backgrounds based on language
        let baseColor: Color
        switch language {
        case "swift":
            baseColor = Color.orange
        case "python", "py":
            baseColor = Color.blue
        case "javascript", "js", "typescript", "ts":
            baseColor = Color.yellow
        case "ruby", "rb":
            baseColor = Color.red
        case "rust", "rs":
            baseColor = Color.orange
        case "go":
            baseColor = Color.cyan
        case "shell", "bash", "sh", "zsh":
            baseColor = Color.green
        case "json":
            baseColor = Color.purple
        default:
            return defaultBackgroundColor
        }
        
        // Apply very subtle tint
        return colorScheme == .dark 
            ? baseColor.opacity(0.08)
            : baseColor.opacity(0.04)
    }
    
    private var defaultBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(.systemGray6) 
            : Color(.systemGray6).opacity(0.5)
    }
    
    private var borderColor: Color {
        guard let language = codeBlock.language?.lowercased() else {
            return Color(.systemGray4).opacity(0.5)
        }
        
        // Colored borders matching the language
        let baseColor: Color
        switch language {
        case "swift":
            baseColor = Color.orange
        case "python", "py":
            baseColor = Color.blue
        case "javascript", "js", "typescript", "ts":
            baseColor = Color.yellow
        case "ruby", "rb":
            baseColor = Color.red
        case "rust", "rs":
            baseColor = Color.orange
        case "go":
            baseColor = Color.cyan
        case "shell", "bash", "sh", "zsh":
            baseColor = Color.green
        case "json":
            baseColor = Color.purple
        default:
            return Color(.systemGray4).opacity(0.5)
        }
        
        return baseColor.opacity(0.3)
    }
    
    private var codeTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
}
