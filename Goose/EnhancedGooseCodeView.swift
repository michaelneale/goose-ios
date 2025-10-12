import SwiftUI

struct EnhancedGooseCodeView: View {
    // Layout state
    @State private var selectedTab: CodeTab = .editor
    @State private var showingFileExplorer = true
    @State private var showingTerminal = true
    @State private var showingChat = true
    @State private var showingPreview = true
    
    // Pane dimensions
    @State private var leftPaneWidth: CGFloat = 280
    @State private var bottomPaneHeight: CGFloat = 220
    @State private var rightPaneWidth: CGFloat = 350
    @State private var previewPaneHeight: CGFloat = 300
    
    // File management
    @State private var currentFile = "index.html"
    @State private var openFiles: [String] = ["index.html", "style.css", "main.js"]
    @State private var fileContents: [String: String] = [
        "index.html": """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GooseCode App</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div id="app">
        <h1>Welcome to GooseCode</h1>
        <canvas id="canvas" width="400" height="300"></canvas>
        <div id="controls">
            <button onclick="drawCircle()">Draw Circle</button>
            <button onclick="drawSquare()">Draw Square</button>
            <button onclick="clearCanvas()">Clear</button>
        </div>
    </div>
    <script src="main.js"></script>
</body>
</html>
""",
        "style.css": """
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    margin: 0;
    padding: 20px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
}

#app {
    max-width: 800px;
    margin: 0 auto;
    background: white;
    border-radius: 12px;
    padding: 30px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
}

h1 {
    color: #333;
    text-align: center;
    margin-bottom: 30px;
}

#canvas {
    border: 2px solid #ddd;
    border-radius: 8px;
    display: block;
    margin: 20px auto;
    background: #f9f9f9;
}

#controls {
    text-align: center;
    margin-top: 20px;
}

button {
    background: #007AFF;
    color: white;
    border: none;
    padding: 10px 20px;
    margin: 0 5px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 14px;
    transition: background 0.2s;
}

button:hover {
    background: #0056CC;
}
""",
        "main.js": """
// GooseCode Canvas Application
const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');

// Initialize canvas
function init() {
    clearCanvas();
    console.log('GooseCode app initialized!');
}

function drawCircle() {
    const x = Math.random() * (canvas.width - 100) + 50;
    const y = Math.random() * (canvas.height - 100) + 50;
    const radius = Math.random() * 30 + 20;
    
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, 2 * Math.PI);
    ctx.fillStyle = `hsl(${Math.random() * 360}, 70%, 60%)`;
    ctx.fill();
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 2;
    ctx.stroke();
    
    console.log(`Drew circle at (${x.toFixed(1)}, ${y.toFixed(1)}) with radius ${radius.toFixed(1)}`);
}

function drawSquare() {
    const x = Math.random() * (canvas.width - 80) + 10;
    const y = Math.random() * (canvas.height - 80) + 10;
    const size = Math.random() * 40 + 30;
    
    ctx.fillStyle = `hsl(${Math.random() * 360}, 70%, 60%)`;
    ctx.fillRect(x, y, size, size);
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 2;
    ctx.strokeRect(x, y, size, size);
    
    console.log(`Drew square at (${x.toFixed(1)}, ${y.toFixed(1)}) with size ${size.toFixed(1)}`);
}

function clearCanvas() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Draw grid
    ctx.strokeStyle = '#eee';
    ctx.lineWidth = 1;
    for (let i = 0; i < canvas.width; i += 20) {
        ctx.beginPath();
        ctx.moveTo(i, 0);
        ctx.lineTo(i, canvas.height);
        ctx.stroke();
    }
    for (let i = 0; i < canvas.height; i += 20) {
        ctx.beginPath();
        ctx.moveTo(0, i);
        ctx.lineTo(canvas.width, i);
        ctx.stroke();
    }
    
    console.log('Canvas cleared');
}

// Initialize when page loads
window.addEventListener('load', init);
"""
    ]
    
    // Terminal and console
    @State private var terminalOutput = """
GooseCode Terminal v1.0
Ready for development...

$ npm init -y
✓ Package.json created
$ npm install --save-dev live-server
✓ Development server installed
$ npm start
✓ Server running on http://localhost:3000
"""
    @State private var consoleOutput = ""
    
    // AI Chat
    @State private var chatMessages: [CodeChatMessage] = [
        CodeChatMessage(role: .assistant, content: "🚀 Welcome to GooseCode! I'm your AI coding assistant powered by advanced language models."),
        CodeChatMessage(role: .assistant, content: "I can help you build HTML/CSS/JavaScript applications with Canvas support. I understand VIM/EMACS shortcuts and can provide intelligent code suggestions."),
        CodeChatMessage(role: .assistant, content: "What would you like to create today? Try asking me to:\n• Add animations to the canvas\n• Create interactive UI components\n• Optimize your code\n• Debug issues\n• Implement new features")
    ]
    @State private var chatInput = ""
    @State private var isAIThinking = false
    
    // VIM/EMACS mode
    @State private var editorMode: EditorMode = .normal
    @State private var commandBuffer = ""
    @State private var showingCommandPalette = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top toolbar
                ToolbarView(
                    selectedTab: $selectedTab,
                    showingFileExplorer: $showingFileExplorer,
                    showingTerminal: $showingTerminal,
                    showingChat: $showingChat,
                    showingPreview: $showingPreview,
                    editorMode: $editorMode,
                    onRun: runCode,
                    onCommandPalette: { showingCommandPalette = true }
                )
                
                // Main content area
                HStack(spacing: 0) {
                    // Left pane - File Explorer
                    if showingFileExplorer {
                        EnhancedFileExplorerView(
                            currentFile: $currentFile,
                            openFiles: $openFiles,
                            fileContents: $fileContents
                        )
                        .frame(width: leftPaneWidth)
                        .background(Color(.systemGray6))
                        
                        Divider()
                    }
                    
                    // Center pane - Editor and Preview
                    VStack(spacing: 0) {
                        // Tab bar for open files
                        if !openFiles.isEmpty {
                            OpenFilesTabBar(
                                openFiles: $openFiles,
                                currentFile: $currentFile,
                                onCloseFile: closeFile,
                                onSelectFile: selectFile
                            )
                        }
                        
                        // Main editor/preview area
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                // Code editor
                                VStack(spacing: 0) {
                                    EnhancedCodeEditorView(
                                        content: Binding(
                                            get: { fileContents[currentFile] ?? "" },
                                            set: { fileContents[currentFile] = $0 }
                                        ),
                                        filename: currentFile,
                                        editorMode: $editorMode,
                                        commandBuffer: $commandBuffer
                                    )
                                }
                                .frame(maxWidth: showingPreview ? .infinity : .infinity)
                                
                                // Live preview (side by side)
                                if showingPreview && selectedTab == .editor {
                                    Divider()
                                    
                                    LivePreviewView(
                                        htmlContent: fileContents["index.html"] ?? "",
                                        cssContent: fileContents["style.css"] ?? "",
                                        jsContent: fileContents["main.js"] ?? "",
                                        onConsoleOutput: { output in
                                            consoleOutput += output + "\n"
                                        }
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            
                            // Bottom terminal
                            if showingTerminal {
                                Divider()
                                
                                EnhancedTerminalView(
                                    output: $terminalOutput,
                                    consoleOutput: $consoleOutput,
                                    selectedTab: $selectedTab
                                )
                                .frame(height: bottomPaneHeight)
                            }
                        }
                    }
                    
                    // Right pane - AI Chat
                    if showingChat {
                        Divider()
                        
                        EnhancedChatPaneView(
                            messages: $chatMessages,
                            input: $chatInput,
                            isThinking: $isAIThinking,
                            fileContents: $fileContents,
                            currentFile: $currentFile,
                            onCodeSuggestion: handleCodeSuggestion
                        )
                        .frame(width: rightPaneWidth)
                        .background(Color(.systemBackground))
                    }
                }
            }
        }
        .navigationTitle("GooseCode")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCommandPalette) {
            CommandPaletteView(
                isPresented: $showingCommandPalette,
                onCommand: handleCommand
            )
        }
        .onAppear {
            // Initialize with sample console output
            consoleOutput = "GooseCode app initialized!\n"
        }
    }
    
    // MARK: - Actions
    
    private func runCode() {
        terminalOutput += "\n$ goose run\n"
        terminalOutput += "🚀 Running application...\n"
        terminalOutput += "✅ Code executed successfully!\n"
        terminalOutput += "📱 Preview updated\n"
        
        // Simulate console output
        consoleOutput += "Application started\n"
    }
    
    private func closeFile(_ filename: String) {
        openFiles.removeAll { $0 == filename }
        if currentFile == filename && !openFiles.isEmpty {
            currentFile = openFiles.first!
        }
    }
    
    private func selectFile(_ filename: String) {
        currentFile = filename
    }
    
    private func handleCodeSuggestion(_ code: String, for file: String) {
        fileContents[file] = code
        if !openFiles.contains(file) {
            openFiles.append(file)
        }
        currentFile = file
    }
    
    private func handleCommand(_ command: String) {
        switch command.lowercased() {
        case "toggle explorer":
            showingFileExplorer.toggle()
        case "toggle terminal":
            showingTerminal.toggle()
        case "toggle chat":
            showingChat.toggle()
        case "toggle preview":
            showingPreview.toggle()
        case "run":
            runCode()
        case "new file":
            createNewFile()
        default:
            terminalOutput += "\n$ \(command)\n"
            terminalOutput += "Command not recognized\n"
        }
    }
    
    private func createNewFile() {
        let newFileName = "untitled.js"
        fileContents[newFileName] = "// New file\n"
        openFiles.append(newFileName)
        currentFile = newFileName
    }
}

// MARK: - Supporting Views

struct ToolbarView: View {
    @Binding var selectedTab: CodeTab
    @Binding var showingFileExplorer: Bool
    @Binding var showingTerminal: Bool
    @Binding var showingChat: Bool
    @Binding var showingPreview: Bool
    @Binding var editorMode: EditorMode
    let onRun: () -> Void
    let onCommandPalette: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Mode indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(editorMode.color)
                    .frame(width: 8, height: 8)
                Text(editorMode.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .cornerRadius(12)
            
            Spacer()
            
            // Tab selection
            HStack(spacing: 4) {
                ForEach(CodeTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.title)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedTab == tab ? Color.blue : Color.clear)
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onCommandPalette) {
                    Image(systemName: "command")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Button(action: onRun) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                        Text("Run")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct EnhancedFileExplorerView: View {
    @Binding var currentFile: String
    @Binding var openFiles: [String]
    @Binding var fileContents: [String: String]
    
    @State private var files = [
        FileItem(name: "index.html", type: .file, icon: "doc.text"),
        FileItem(name: "style.css", type: .file, icon: "paintbrush"),
        FileItem(name: "main.js", type: .file, icon: "doc.text"),
        FileItem(name: "assets", type: .folder, icon: "folder", children: [
            FileItem(name: "images", type: .folder, icon: "folder"),
            FileItem(name: "fonts", type: .folder, icon: "folder")
        ]),
        FileItem(name: "components", type: .folder, icon: "folder", children: [
            FileItem(name: "Button.js", type: .file, icon: "doc.text"),
            FileItem(name: "Modal.js", type: .file, icon: "doc.text")
        ])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Explorer")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Menu {
                    Button("New File") {
                        createNewFile()
                    }
                    Button("New Folder") {
                        createNewFolder()
                    }
                    Divider()
                    Button("Refresh") {
                        // Refresh file tree
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            
            // File tree
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(files) { file in
                        EnhancedFileRowView(
                            file: file,
                            level: 0,
                            currentFile: $currentFile,
                            openFiles: $openFiles,
                            onFileSelect: selectFile
                        )
                    }
                }
            }
        }
    }
    
    private func selectFile(_ filename: String) {
        currentFile = filename
        if !openFiles.contains(filename) {
            openFiles.append(filename)
        }
    }
    
    private func createNewFile() {
        let newFile = FileItem(name: "untitled.js", type: .file, icon: "doc.text")
        files.append(newFile)
        fileContents["untitled.js"] = "// New file\n"
        selectFile("untitled.js")
    }
    
    private func createNewFolder() {
        let newFolder = FileItem(name: "new-folder", type: .folder, icon: "folder", children: [])
        files.append(newFolder)
    }
}

struct EnhancedFileRowView: View {
    let file: FileItem
    let level: Int
    @Binding var currentFile: String
    @Binding var openFiles: [String]
    let onFileSelect: (String) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // Indentation
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: CGFloat(level * 16))
                
                // Expand/collapse for folders
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
                    .foregroundColor(file.type == .folder ? .blue : getFileIconColor(file.name))
                    .frame(width: 16)
                
                // File name
                Text(file.name)
                    .font(.caption)
                    .foregroundColor(currentFile == file.name ? .white : .primary)
                
                Spacer()
                
                // Open indicator
                if openFiles.contains(file.name) && file.type == .file {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(currentFile == file.name ? Color.blue : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .onTapGesture {
                if file.type == .folder {
                    isExpanded.toggle()
                } else {
                    onFileSelect(file.name)
                }
            }
            
            // Children
            if file.type == .folder && isExpanded {
                ForEach(file.children ?? []) { child in
                    EnhancedFileRowView(
                        file: child,
                        level: level + 1,
                        currentFile: $currentFile,
                        openFiles: $openFiles,
                        onFileSelect: onFileSelect
                    )
                }
            }
        }
    }
    
    private func getFileIconColor(_ filename: String) -> Color {
        if filename.hasSuffix(".html") { return .orange }
        if filename.hasSuffix(".css") { return .blue }
        if filename.hasSuffix(".js") { return .yellow }
        return .primary
    }
}

struct OpenFilesTabBar: View {
    @Binding var openFiles: [String]
    @Binding var currentFile: String
    let onCloseFile: (String) -> Void
    let onSelectFile: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(openFiles, id: \.self) { file in
                    HStack(spacing: 6) {
                        Image(systemName: getFileIcon(file))
                            .font(.caption2)
                            .foregroundColor(getFileIconColor(file))
                        
                        Text(file)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Button(action: { onCloseFile(file) }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(currentFile == file ? Color.blue : Color(.systemGray5))
                    .foregroundColor(currentFile == file ? .white : .primary)
                    .cornerRadius(6, corners: [.topLeading, .topTrailing])
                    .onTapGesture {
                        onSelectFile(file)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .background(Color(.systemGray6))
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
}

// MARK: - Editor Mode

enum EditorMode {
    case normal, insert, visual, command
    
    var displayName: String {
        switch self {
        case .normal: return "NORMAL"
        case .insert: return "INSERT"
        case .visual: return "VISUAL"
        case .command: return "COMMAND"
        }
    }
    
    var color: Color {
        switch self {
        case .normal: return .blue
        case .insert: return .green
        case .visual: return .orange
        case .command: return .purple
        }
    }
}

#Preview {
    NavigationView {
        EnhancedGooseCodeView()
    }
}
