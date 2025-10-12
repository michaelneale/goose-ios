import SwiftUI

struct GooseCodeView: View {
    @State private var selectedTab: CodeTab = .editor
    @State private var showingFileExplorer = true
    @State private var showingTerminal = true
    @State private var showingChat = true
    @State private var currentFile = "main.js"
    @State private var codeContent = """
// Welcome to GooseCode
// A VIM/EMACS style coding agent interface

function createApp() {
    const canvas = document.getElementById('canvas');
    const ctx = canvas.getContext('2d');
    
    // Draw a simple circle
    ctx.beginPath();
    ctx.arc(100, 100, 50, 0, 2 * Math.PI);
    ctx.fillStyle = '#007AFF';
    ctx.fill();
    
    console.log('App initialized!');
}

createApp();
"""
    @State private var terminalOutput = """
> npm install
> Starting development server...
> Server running on http://localhost:3000
> Ready for development!
"""
    @State private var chatMessages: [CodeChatMessage] = [
        CodeChatMessage(role: .assistant, content: "Welcome to GooseCode! I'm your coding assistant. I can help you build HTML/CSS/JavaScript applications with Canvas support."),
        CodeChatMessage(role: .assistant, content: "What would you like to create today?")
    ]
    @State private var chatInput = ""
    
    // Layout state
    @State private var leftPaneWidth: CGFloat = 250
    @State private var bottomPaneHeight: CGFloat = 200
    @State private var rightPaneWidth: CGFloat = 300
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Pane - File Explorer
                if showingFileExplorer {
                    VStack(spacing: 0) {
                        FileExplorerView()
                    }
                    .frame(width: leftPaneWidth)
                    .background(Color(.systemGray6))
                    
                    // Vertical divider
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1)
                }
                
                // Center Pane - Main Editor Area
                VStack(spacing: 0) {
                    // Tab bar
                    TabBarView(selectedTab: $selectedTab)
                    
                    // Main content area
                    VStack(spacing: 0) {
                        // Editor area
                        VStack(spacing: 0) {
                            switch selectedTab {
                            case .editor:
                                CodeEditorView(content: $codeContent, filename: currentFile)
                            case .preview:
                                PreviewView()
                            case .console:
                                ConsoleView(output: terminalOutput)
                            }
                        }
                        .frame(maxHeight: showingTerminal ? 
                               geometry.size.height - bottomPaneHeight - 100 : 
                               .infinity)
                        
                        // Bottom terminal (if showing)
                        if showingTerminal {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 1)
                            
                            TerminalView(output: $terminalOutput)
                                .frame(height: bottomPaneHeight)
                        }
                    }
                }
                
                // Right Pane - Chat/Agent
                if showingChat {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1)
                    
                    VStack(spacing: 0) {
                        ChatPaneView(messages: $chatMessages, input: $chatInput)
                    }
                    .frame(width: rightPaneWidth)
                    .background(Color(.systemBackground))
                }
            }
        }
        .navigationTitle("GooseCode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingFileExplorer.toggle() }) {
                        Label("File Explorer", systemImage: showingFileExplorer ? "checkmark" : "")
                    }
                    Button(action: { showingTerminal.toggle() }) {
                        Label("Terminal", systemImage: showingTerminal ? "checkmark" : "")
                    }
                    Button(action: { showingChat.toggle() }) {
                        Label("Chat Assistant", systemImage: showingChat ? "checkmark" : "")
                    }
                    
                    Divider()
                    
                    Button(action: { resetLayout() }) {
                        Label("Reset Layout", systemImage: "rectangle.3.group")
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                }
                
                Button(action: { runCode() }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private func resetLayout() {
        leftPaneWidth = 250
        bottomPaneHeight = 200
        rightPaneWidth = 300
        showingFileExplorer = true
        showingTerminal = true
        showingChat = true
    }
    
    private func runCode() {
        // Placeholder for running code in sandbox
        terminalOutput += "\n> Running code..."
        terminalOutput += "\n✅ Code executed successfully!"
    }
}

// MARK: - Supporting Views

struct FileExplorerView: View {
    @State private var files = [
        FileItem(name: "index.html", type: .file, icon: "doc.text"),
        FileItem(name: "style.css", type: .file, icon: "paintbrush"),
        FileItem(name: "main.js", type: .file, icon: "doc.text", isSelected: true),
        FileItem(name: "assets", type: .folder, icon: "folder", children: [
            FileItem(name: "images", type: .folder, icon: "folder"),
            FileItem(name: "fonts", type: .folder, icon: "folder")
        ])
    ]
    
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
                Button(action: {}) {
                    Image(systemName: "folder.badge.plus")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            
            // File list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(files) { file in
                        FileRowView(file: file, level: 0)
                    }
                }
            }
        }
    }
}

struct FileRowView: View {
    let file: FileItem
    let level: Int
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                // Indentation
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(level * 16))
                
                // Expand/collapse button for folders
                if file.type == .folder {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 12)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 12)
                }
                
                // File icon
                Image(systemName: file.icon)
                    .font(.caption)
                    .foregroundColor(file.type == .folder ? .blue : .primary)
                    .frame(width: 16)
                
                // File name
                Text(file.name)
                    .font(.caption)
                    .foregroundColor(file.isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(file.isSelected ? Color.blue : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .onTapGesture {
                if file.type == .folder {
                    isExpanded.toggle()
                } else {
                    // Select file
                    print("Selected file: \(file.name)")
                }
            }
            
            // Children (if folder is expanded)
            if file.type == .folder && isExpanded {
                ForEach(file.children ?? []) { child in
                    FileRowView(file: child, level: level + 1)
                }
            }
        }
    }
}

struct TabBarView: View {
    @Binding var selectedTab: CodeTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CodeTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.blue : Color.clear)
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
    }
}

struct CodeEditorView: View {
    @Binding var content: String
    let filename: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Editor header
            HStack {
                Image(systemName: "doc.text")
                    .font(.caption)
                Text(filename)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("JavaScript")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Code editor area
            ScrollView([.horizontal, .vertical]) {
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...content.components(separatedBy: .newlines).count, id: \.self) { lineNumber in
                            Text("\(lineNumber)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(minWidth: 30, alignment: .trailing)
                                .padding(.vertical, 1)
                        }
                    }
                    .padding(.horizontal, 8)
                    .background(Color(.systemGray6))
                    
                    // Code content
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .background(Color(.systemBackground))
                }
            }
        }
    }
}

struct PreviewView: View {
    var body: some View {
        VStack {
            // Preview header
            HStack {
                Image(systemName: "eye")
                    .font(.caption)
                Text("Live Preview")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Preview content (placeholder)
            ZStack {
                Color(.systemBackground)
                
                VStack(spacing: 20) {
                    // Simulated canvas preview
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                        .frame(width: 100, height: 100)
                    
                    Text("Canvas Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("🚧 Live preview will show your HTML/CSS/JS output here")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
    }
}

struct ConsoleView: View {
    let output: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Console header
            HStack {
                Image(systemName: "terminal")
                    .font(.caption)
                Text("Console")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Console output
            ScrollView {
                HStack {
                    Text(output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding()
            }
            .background(Color.black)
        }
    }
}

struct TerminalView: View {
    @Binding var output: String
    @State private var input = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            HStack {
                Image(systemName: "terminal")
                    .font(.caption)
                Text("Terminal")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Button(action: { output = "" }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            
            // Terminal content
            VStack(spacing: 0) {
                // Output area
                ScrollView {
                    HStack {
                        Text(output)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .background(Color.black)
                
                // Input area
                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                    
                    TextField("Enter command...", text: $input)
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            if !input.isEmpty {
                                output += "\n$ \(input)"
                                output += "\n> Command executed"
                                input = ""
                            }
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black)
            }
        }
    }
}

struct ChatPaneView: View {
    @Binding var messages: [CodeChatMessage]
    @Binding var input: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.caption)
                Text("AI Assistant")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        ChatMessageView(message: message)
                    }
                }
                .padding()
            }
            
            // Input area
            VStack(spacing: 8) {
                Divider()
                
                HStack(spacing: 8) {
                    TextField("Ask the AI assistant...", text: $input, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...3)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(input.isEmpty ? .gray : .blue)
                    }
                    .disabled(input.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
    
    private func sendMessage() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = CodeChatMessage(role: .user, content: input)
        messages.append(userMessage)
        
        let userInput = input
        input = ""
        
        // Simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = generateAIResponse(to: userInput)
            let aiMessage = CodeChatMessage(role: .assistant, content: response)
            messages.append(aiMessage)
        }
    }
    
    private func generateAIResponse(to input: String) -> String {
        // Simple placeholder responses
        let responses = [
            "I can help you with that! Let me analyze your code and provide suggestions.",
            "Great question! Here's what I recommend for your JavaScript application.",
            "I see you're working with Canvas. Would you like me to help you add some interactive features?",
            "Let me help you debug that. I notice a few areas we could improve.",
            "That's a good approach! Here are some additional techniques you might find useful."
        ]
        return responses.randomElement() ?? "I'm here to help with your coding project!"
    }
}

struct ChatMessageView: View {
    let message: CodeChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar
            Circle()
                .fill(message.role == .user ? Color.blue : Color.green)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: message.role == .user ? "person.fill" : "brain")
                        .font(.caption2)
                        .foregroundColor(.white)
                )
            
            // Message content
            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "AI Assistant")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .font(.caption)
                    .padding(8)
                    .background(message.role == .user ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
    }
}

// MARK: - Data Models

enum CodeTab: CaseIterable {
    case editor, preview, console
    
    var title: String {
        switch self {
        case .editor: return "Editor"
        case .preview: return "Preview"
        case .console: return "Console"
        }
    }
    
    var icon: String {
        switch self {
        case .editor: return "doc.text"
        case .preview: return "eye"
        case .console: return "terminal"
        }
    }
}

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let type: FileType
    let icon: String
    var isSelected: Bool = false
    var children: [FileItem]?
    
    enum FileType {
        case file, folder
    }
}

struct CodeChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()
    
    enum Role {
        case user, assistant
    }
}

#Preview {
    NavigationView {
        GooseCodeView()
    }
}
