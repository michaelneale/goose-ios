import SwiftUI

// MARK: - Toolbar Component
struct GooseCodeToolbar: View {
    @Binding var selectedMode: EditorMode
    @Binding var showingSidebar: Bool
    @Binding var showingAssistant: Bool
    @Binding var showingPreview: Bool
    
    var body: some View {
        HStack {
            // Left side - Mode selector
            HStack(spacing: 8) {
                Text("Mode:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Editor Mode", selection: $selectedMode) {
                    ForEach(EditorMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            Spacer()
            
            // Center - File actions
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "doc.badge.plus")
                        .foregroundColor(.blue)
                }
                .help("New File")
                
                Button(action: {}) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(.blue)
                }
                .help("New Folder")
                
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                }
                .help("Save")
            }
            
            Spacer()
            
            // Right side - Panel toggles
            HStack(spacing: 8) {
                Button(action: {
                    showingSidebar.toggle()
                }) {
                    Image(systemName: showingSidebar ? "sidebar.left" : "sidebar.left")
                        .foregroundColor(showingSidebar ? .blue : .secondary)
                }
                .help("Toggle File Explorer")
                
                Button(action: {
                    showingAssistant.toggle()
                }) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(showingAssistant ? .blue : .secondary)
                }
                .help("Toggle AI Assistant")
                
                Button(action: {
                    showingPreview.toggle()
                }) {
                    Image(systemName: "eye")
                        .foregroundColor(showingPreview ? .blue : .secondary)
                }
                .help("Toggle Live Preview")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

// MARK: - File Explorer Component
struct FileExplorerView: View {
    @Binding var files: [ProjectFile]
    @Binding var selectedFile: CodeFile?
    let onFileSelect: (ProjectFile) -> Void
    
    @State private var expandedFolders: Set<UUID> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Files")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemGray5))
            
            Divider()
            
            // File list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(files, id: \.id) { file in
                        FileRowView(
                            file: file,
                            isSelected: selectedFile?.name == file.name,
                            onSelect: {
                                onFileSelect(file)
                            }
                        )
                    }
                }
            }
            
            Spacer()
        }
    }
}

struct FileRowView: View {
    let file: ProjectFile
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: fileIcon)
                .foregroundColor(fileColor)
                .frame(width: 16)
            
            Text(file.name)
                .font(.system(size: 14, family: .monospaced))
                .foregroundColor(isSelected ? .white : .primary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .cornerRadius(4)
        .padding(.horizontal, 4)
    }
    
    private var fileIcon: String {
        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "html", "htm": return "globe"
        case "css": return "paintbrush"
        case "js", "javascript": return "curlybraces"
        case "swift": return "swift"
        case "py", "python": return "snake"
        case "json": return "doc.text"
        default: return "doc"
        }
    }
    
    private var fileColor: Color {
        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "html", "htm": return .orange
        case "css": return .blue
        case "js", "javascript": return .yellow
        case "swift": return .orange
        case "py", "python": return .green
        case "json": return .purple
        default: return .secondary
        }
    }
}

// MARK: - File Tabs Component
struct FileTabsView: View {
    @Binding var openFiles: [CodeFile]
    @Binding var currentFile: CodeFile?
    let onCloseFile: (CodeFile) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(openFiles) { file in
                    FileTabView(
                        file: file,
                        isSelected: currentFile?.id == file.id,
                        onSelect: {
                            currentFile = file
                        },
                        onClose: {
                            onCloseFile(file)
                        }
                    )
                }
            }
        }
        .background(Color(.systemGray6))
    }
}

struct FileTabView: View {
    let file: CodeFile
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // File icon
            Image(systemName: fileIcon)
                .font(.caption)
                .foregroundColor(fileColor)
            
            // File name
            Text(file.name)
                .font(.system(size: 12, family: .monospaced))
                .foregroundColor(isSelected ? .primary : .secondary)
            
            // Modified indicator
            if file.isModified {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color(.systemBackground) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private var fileIcon: String {
        switch file.language {
        case .html: return "globe"
        case .css: return "paintbrush"
        case .javascript: return "curlybraces"
        case .swift: return "swift"
        case .python: return "snake"
        case .json: return "doc.text"
        case .text: return "doc"
        }
    }
    
    private var fileColor: Color {
        switch file.language {
        case .html: return .orange
        case .css: return .blue
        case .javascript: return .yellow
        case .swift: return .orange
        case .python: return .green
        case .json: return .purple
        case .text: return .secondary
        }
    }
}

// MARK: - Code Editor Component
struct CodeEditorView: View {
    let file: CodeFile?
    let mode: EditorMode
    let onContentChange: (String) -> Void
    
    @State private var content: String = ""
    @State private var showingVimCommands = false
    @State private var vimCommand = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor area
            ZStack(alignment: .topLeading) {
                if let file = file {
                    TextEditor(text: Binding(
                        get: { content },
                        set: { newValue in
                            content = newValue
                            onContentChange(newValue)
                        }
                    ))
                    .font(.system(size: 14, family: .monospaced))
                    .padding(8)
                    .background(Color(.systemBackground))
                    .onAppear {
                        content = file.content
                    }
                    .onChange(of: file.id) { _ in
                        content = file.content
                    }
                } else {
                    VStack {
                        Spacer()
                        Text("No file selected")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Select a file from the explorer or create a new one")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                }
                
                // Line numbers (simplified)
                if file != nil {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(1...max(content.components(separatedBy: "\n").count, 20), id: \.self) { lineNumber in
                            Text("\(lineNumber)")
                                .font(.system(size: 12, family: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                                .padding(.vertical, 1)
                        }
                        Spacer()
                    }
                    .padding(.leading, 4)
                    .background(Color(.systemGray6))
                }
            }
            
            // Mode-specific status bar
            HStack {
                // Left side - file info
                if let file = file {
                    Text("\(file.language.displayName) • \(content.components(separatedBy: "\n").count) lines")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Right side - mode indicator
                HStack(spacing: 8) {
                    Image(systemName: mode.icon)
                        .font(.caption)
                    Text(mode.rawValue)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                if mode == .vim && showingVimCommands {
                    TextField(":", text: $vimCommand)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .font(.system(family: .monospaced))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
        }
    }
}

// MARK: - Assistant Panel Component
struct AssistantPanelView: View {
    @Binding var messages: [AssistantMessage]
    @Binding var input: String
    let currentFile: CodeFile?
    let onSendMessage: (String) -> Void
    let onApplyCode: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI Assistant")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    messages.removeAll()
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray5))
            
            Divider()
            
            // Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        AssistantMessageView(
                            message: message,
                            onApplyCode: onApplyCode
                        )
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Input area
            VStack(spacing: 8) {
                // Quick actions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        QuickActionButton(title: "Explain Code", icon: "questionmark.circle") {
                            onSendMessage("Explain this code: \(currentFile?.content ?? "")")
                        }
                        
                        QuickActionButton(title: "Optimize", icon: "speedometer") {
                            onSendMessage("Optimize this code for better performance")
                        }
                        
                        QuickActionButton(title: "Add Comments", icon: "text.bubble") {
                            onSendMessage("Add helpful comments to this code")
                        }
                        
                        QuickActionButton(title: "Find Bugs", icon: "ladybug") {
                            onSendMessage("Find potential bugs in this code")
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Text input
                HStack {
                    TextField("Ask the AI assistant...", text: $input, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...3)
                    
                    Button(action: {
                        if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSendMessage(input)
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(input.isEmpty ? .secondary : .blue)
                    }
                    .disabled(input.isEmpty)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AssistantMessageView: View {
    let message: AssistantMessage
    let onApplyCode: (String) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar
            Image(systemName: message.role == .user ? "person.circle" : "brain.head.profile")
                .foregroundColor(message.role == .user ? .blue : .purple)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                // Message content
                Text(message.content)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
                
                // Timestamp
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Code apply button (if message contains code)
                if message.role == .assistant && containsCode(message.content) {
                    Button("Apply Code") {
                        onApplyCode(extractCode(from: message.content))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Spacer()
        }
        .padding(8)
        .background(message.role == .user ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func containsCode(_ text: String) -> Bool {
        return text.contains("```") || text.contains("function") || text.contains("class") || text.contains("<html")
    }
    
    private func extractCode(from text: String) -> String {
        // Simple code extraction - in real implementation, use proper parsing
        if text.contains("```") {
            let components = text.components(separatedBy: "```")
            return components.count > 1 ? components[1] : text
        }
        return text
    }
}

// MARK: - Live Preview Panel Component
struct LivePreviewPanelView: View {
    let content: String
    @Binding var mode: PreviewMode
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.green)
                Text("Live Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Mode picker
                Picker("Preview Mode", selection: $mode) {
                    ForEach(PreviewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 150)
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemGray5))
            
            Divider()
            
            // Preview content
            Group {
                switch mode {
                case .html:
                    WebPreviewView(htmlContent: content)
                case .text:
                    TextPreviewView(content: content)
                case .canvas:
                    CanvasPreviewView(content: content)
                }
            }
        }
    }
}

struct WebPreviewView: View {
    let htmlContent: String
    
    var body: some View {
        // Placeholder for WebKit view
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("HTML Preview")
                    .font(.headline)
                    .padding()
                
                Text("WebKit preview would render here")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Show raw HTML for now
                Text(htmlContent)
                    .font(.system(size: 10, family: .monospaced))
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

struct TextPreviewView: View {
    let content: String
    
    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 14, family: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
    }
}

struct CanvasPreviewView: View {
    let content: String
    
    var body: some View {
        VStack {
            Text("Canvas Preview")
                .font(.headline)
                .padding()
            
            Text("Canvas rendering would appear here")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 200)
                .overlay(
                    Text("Canvas Output")
                        .foregroundColor(.secondary)
                )
                .padding()
            
            Spacer()
        }
    }
}

#Preview("Toolbar") {
    GooseCodeToolbar(
        selectedMode: .constant(.normal),
        showingSidebar: .constant(true),
        showingAssistant: .constant(true),
        showingPreview: .constant(true)
    )
}

#Preview("File Explorer") {
    FileExplorerView(
        files: .constant(sampleProjectFiles),
        selectedFile: .constant(nil),
        onFileSelect: { _ in }
    )
    .frame(width: 250)
}
