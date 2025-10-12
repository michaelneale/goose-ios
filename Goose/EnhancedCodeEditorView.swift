import SwiftUI

struct EnhancedCodeEditorView: View {
    @Binding var content: String
    let filename: String
    @Binding var editorMode: EditorMode
    @Binding var commandBuffer: String
    
    @State private var cursorPosition = 0
    @State private var selectedRange: Range<String.Index>?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Editor header
            HStack {
                Image(systemName: getFileIcon(filename))
                    .font(.caption)
                    .foregroundColor(getFileIconColor(filename))
                
                Text(filename)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Language indicator
                Text(getLanguage(filename))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(getLanguageColor(filename).opacity(0.2))
                    .cornerRadius(4)
                
                // Editor mode indicator
                Text(editorMode.displayName)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(editorMode.color.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Code editor area
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 0) {
                        // Line numbers
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(1...max(content.components(separatedBy: .newlines).count, 1), id: \.self) { lineNumber in
                                Text("\(lineNumber)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 40, alignment: .trailing)
                                    .padding(.vertical, 2)
                            }
                        }
                        .padding(.horizontal, 8)
                        .background(Color(.systemGray6))
                        
                        // Vertical separator
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 1)
                        
                        // Code content
                        VStack(alignment: .leading, spacing: 0) {
                            if editorMode == .insert || editorMode == .command {
                                // Editable text editor
                                TextEditor(text: $content)
                                    .font(.system(.body, design: .monospaced))
                                    .scrollContentBackground(.hidden)
                                    .background(Color(.systemBackground))
                                    .focused($isFocused)
                                    .onChange(of: content) { _ in
                                        // Handle content changes
                                    }
                            } else {
                                // Read-only view with syntax highlighting
                                SyntaxHighlightedText(
                                    content: content,
                                    language: getLanguage(filename)
                                )
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                                .onTapGesture {
                                    editorMode = .insert
                                    isFocused = true
                                }
                            }
                        }
                        .frame(minWidth: geometry.size.width - 60)
                    }
                }
            }
            
            // Command line (for VIM-style commands)
            if editorMode == .command {
                HStack {
                    Text(":")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                    
                    TextField("Enter command", text: $commandBuffer)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            handleCommand(commandBuffer)
                            commandBuffer = ""
                            editorMode = .normal
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
            }
        }
        .onAppear {
            isFocused = true
        }
    }
    
    private func getFileIcon(_ filename: String) -> String {
        if filename.hasSuffix(".html") { return "doc.text" }
        if filename.hasSuffix(".css") { return "paintbrush" }
        if filename.hasSuffix(".js") { return "doc.text" }
        return "doc"
    }
    
    private func getFileIconColor(_ filename: String) -> Color {
        if filename.hasSuffix(".html") { return .orange }
        if filename.hasSuffix(".css") { return .blue }
        if filename.hasSuffix(".js") { return .yellow }
        return .primary
    }
    
    private func getLanguage(_ filename: String) -> String {
        if filename.hasSuffix(".html") { return "HTML" }
        if filename.hasSuffix(".css") { return "CSS" }
        if filename.hasSuffix(".js") { return "JavaScript" }
        return "Text"
    }
    
    private func getLanguageColor(_ filename: String) -> Color {
        if filename.hasSuffix(".html") { return .orange }
        if filename.hasSuffix(".css") { return .blue }
        if filename.hasSuffix(".js") { return .yellow }
        return .gray
    }
    
    private func handleCommand(_ command: String) {
        switch command.lowercased() {
        case "w", "write":
            // Save file
            print("File saved: \(filename)")
        case "q", "quit":
            // Close file
            print("Quit editor")
        case "wq":
            // Save and quit
            print("Save and quit")
        default:
            print("Unknown command: \(command)")
        }
    }
}

struct SyntaxHighlightedText: View {
    let content: String
    let language: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(content.components(separatedBy: .newlines).indices, id: \.self) { index in
                let line = content.components(separatedBy: .newlines)[index]
                HStack {
                    highlightedLine(line, language: language)
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private func highlightedLine(_ line: String, language: String) -> some View {
        switch language.lowercased() {
        case "javascript":
            highlightJavaScript(line)
        case "html":
            highlightHTML(line)
        case "css":
            highlightCSS(line)
        default:
            Text(line)
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private func highlightJavaScript(_ line: String) -> some View {
        let keywords = ["function", "const", "let", "var", "if", "else", "for", "while", "return", "class", "import", "export"]
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        if trimmedLine.hasPrefix("//") {
            Text(line)
                .foregroundColor(.green)
        } else if keywords.contains(where: line.contains) {
            Text(line)
                .foregroundColor(.purple)
        } else {
            Text(line)
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private func highlightHTML(_ line: String) -> some View {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        if trimmedLine.hasPrefix("<") && trimmedLine.hasSuffix(">") {
            Text(line)
                .foregroundColor(.blue)
        } else {
            Text(line)
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private func highlightCSS(_ line: String) -> some View {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        if trimmedLine.contains(":") && !trimmedLine.hasPrefix("/*") {
            Text(line)
                .foregroundColor(.red)
        } else if trimmedLine.hasPrefix("/*") || trimmedLine.hasPrefix("//") {
            Text(line)
                .foregroundColor(.green)
        } else {
            Text(line)
                .foregroundColor(.primary)
        }
    }
}

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
