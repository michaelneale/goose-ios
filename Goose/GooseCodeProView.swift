import SwiftUI

// MARK: - Main GooseCode Pro View
struct GooseCodeProView: View {
    @State private var selectedMode: EditorMode = .normal
    @State private var showingSidebar = true
    @State private var showingFileExplorer = true
    @State private var showingAssistant = true
    @State private var showingPreview = true
    
    // Layout state
    @State private var editorWidth: CGFloat = 400
    @State private var assistantWidth: CGFloat = 300
    @State private var sidebarWidth: CGFloat = 250
    
    // Editor state
    @State private var currentFile: CodeFile?
    @State private var openFiles: [CodeFile] = []
    @State private var projectFiles: [ProjectFile] = sampleProjectFiles
    
    // Assistant state
    @State private var assistantMessages: [AssistantMessage] = []
    @State private var assistantInput = ""
    
    // Preview state
    @State private var previewContent = defaultHTMLContent
    @State private var previewMode: PreviewMode = .html
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // File Explorer Sidebar
                    if showingSidebar && showingFileExplorer {
                        FileExplorerView(
                            files: $projectFiles,
                            selectedFile: $currentFile,
                            onFileSelect: { file in
                                openFile(file)
                            }
                        )
                        .frame(width: sidebarWidth)
                        .background(Color(.systemGray6))
                        
                        Divider()
                    }
                    
                    // Main Content Area
                    VStack(spacing: 0) {
                        // Toolbar
                        GooseCodeToolbar(
                            selectedMode: $selectedMode,
                            showingSidebar: $showingFileExplorer,
                            showingAssistant: $showingAssistant,
                            showingPreview: $showingPreview
                        )
                        
                        Divider()
                        
                        // Main Editor + Assistant + Preview
                        HStack(spacing: 0) {
                            // Code Editor
                            VStack(spacing: 0) {
                                // File Tabs
                                if !openFiles.isEmpty {
                                    FileTabsView(
                                        openFiles: $openFiles,
                                        currentFile: $currentFile,
                                        onCloseFile: { file in
                                            closeFile(file)
                                        }
                                    )
                                    Divider()
                                }
                                
                                // Editor
                                CodeEditorView(
                                    file: currentFile,
                                    mode: selectedMode,
                                    onContentChange: { content in
                                        updateFileContent(content)
                                        if previewMode == .html {
                                            updatePreview()
                                        }
                                    }
                                )
                            }
                            .frame(width: calculateEditorWidth(geometry: geometry))
                            
                            // Assistant Panel
                            if showingAssistant {
                                Divider()
                                
                                AssistantPanelView(
                                    messages: $assistantMessages,
                                    input: $assistantInput,
                                    currentFile: currentFile,
                                    onSendMessage: { message in
                                        sendAssistantMessage(message)
                                    },
                                    onApplyCode: { code in
                                        applyCodeSuggestion(code)
                                    }
                                )
                                .frame(width: assistantWidth)
                            }
                            
                            // Live Preview Panel
                            if showingPreview {
                                Divider()
                                
                                LivePreviewPanelView(
                                    content: previewContent,
                                    mode: $previewMode,
                                    onRefresh: {
                                        updatePreview()
                                    }
                                )
                                .frame(width: calculatePreviewWidth(geometry: geometry))
                            }
                        }
                    }
                }
            }
            .navigationTitle("GooseCode Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("New File") { createNewFile() }
                        Button("Save All") { saveAllFiles() }
                        Divider()
                        Button("Settings") { /* TODO */ }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - Layout Calculations
    private func calculateEditorWidth(geometry: GeometryProxy) -> CGFloat {
        var totalWidth = geometry.size.width
        
        if showingFileExplorer {
            totalWidth -= sidebarWidth
        }
        
        if showingAssistant {
            totalWidth -= assistantWidth
        }
        
        if showingPreview {
            totalWidth -= calculatePreviewWidth(geometry: geometry)
        }
        
        return max(totalWidth, 200) // Minimum editor width
    }
    
    private func calculatePreviewWidth(geometry: GeometryProxy) -> CGFloat {
        let remainingWidth = geometry.size.width - 
            (showingFileExplorer ? sidebarWidth : 0) - 
            (showingAssistant ? assistantWidth : 0) - 
            200 // Minimum editor width
        
        return max(min(remainingWidth * 0.4, 400), 250) // 40% of remaining or max 400px
    }
    
    // MARK: - File Management
    private func openFile(_ projectFile: ProjectFile) {
        let codeFile = CodeFile(
            id: projectFile.id,
            name: projectFile.name,
            content: projectFile.content,
            language: detectLanguage(from: projectFile.name),
            isModified: false
        )
        
        if !openFiles.contains(where: { $0.id == codeFile.id }) {
            openFiles.append(codeFile)
        }
        
        currentFile = codeFile
        
        // Update preview if HTML/CSS/JS file
        if ["html", "css", "javascript"].contains(codeFile.language.rawValue) {
            updatePreview()
        }
    }
    
    private func closeFile(_ file: CodeFile) {
        openFiles.removeAll { $0.id == file.id }
        
        if currentFile?.id == file.id {
            currentFile = openFiles.last
        }
    }
    
    private func createNewFile() {
        let newFile = CodeFile(
            id: UUID(),
            name: "untitled.html",
            content: defaultHTMLContent,
            language: .html,
            isModified: false
        )
        
        openFiles.append(newFile)
        currentFile = newFile
    }
    
    private func saveAllFiles() {
        // TODO: Implement file saving
        for file in openFiles {
            if file.isModified {
                // Save file logic here
                print("Saving file: \(file.name)")
            }
        }
    }
    
    private func updateFileContent(_ content: String) {
        guard var file = currentFile else { return }
        file.content = content
        file.isModified = true
        currentFile = file
        
        // Update in openFiles array
        if let index = openFiles.firstIndex(where: { $0.id == file.id }) {
            openFiles[index] = file
        }
    }
    
    // MARK: - Preview Management
    private func updatePreview() {
        guard let file = currentFile else { return }
        
        switch file.language {
        case .html:
            previewContent = file.content
            previewMode = .html
        case .javascript:
            // Wrap JS in HTML for preview
            previewContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>JavaScript Preview</title>
                <style>
                    body { font-family: system-ui; padding: 20px; }
                    #output { border: 1px solid #ccc; padding: 10px; margin-top: 10px; }
                </style>
            </head>
            <body>
                <h3>JavaScript Output:</h3>
                <div id="output"></div>
                <script>
                    // Redirect console.log to output div
                    const output = document.getElementById('output');
                    const originalLog = console.log;
                    console.log = function(...args) {
                        output.innerHTML += args.join(' ') + '<br>';
                        originalLog.apply(console, args);
                    };
                    
                    try {
                        \(file.content)
                    } catch (error) {
                        output.innerHTML += '<span style="color: red;">Error: ' + error.message + '</span>';
                    }
                </script>
            </body>
            </html>
            """
            previewMode = .html
        case .css:
            // Wrap CSS in HTML for preview
            previewContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>CSS Preview</title>
                <style>
                    \(file.content)
                </style>
            </head>
            <body>
                <h1>CSS Preview</h1>
                <p>This is a sample paragraph to show CSS styling.</p>
                <div class="sample-div">Sample div element</div>
                <button>Sample button</button>
            </body>
            </html>
            """
            previewMode = .html
        default:
            previewContent = file.content
            previewMode = .text
        }
    }
    
    // MARK: - Assistant Integration
    private func sendAssistantMessage(_ message: String) {
        let userMessage = AssistantMessage(
            id: UUID(),
            role: .user,
            content: message,
            timestamp: Date()
        )
        assistantMessages.append(userMessage)
        
        // Simulate AI response (replace with actual GPT-5 integration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let aiResponse = generateMockAIResponse(for: message)
            assistantMessages.append(aiResponse)
        }
        
        assistantInput = ""
    }
    
    private func applyCodeSuggestion(_ code: String) {
        guard var file = currentFile else { return }
        file.content = code
        file.isModified = true
        currentFile = file
        
        if let index = openFiles.firstIndex(where: { $0.id == file.id }) {
            openFiles[index] = file
        }
        
        updatePreview()
    }
    
    // MARK: - Helper Functions
    private func detectLanguage(from filename: String) -> ProgrammingLanguage {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "html", "htm": return .html
        case "css": return .css
        case "js", "javascript": return .javascript
        case "swift": return .swift
        case "py", "python": return .python
        case "json": return .json
        default: return .text
        }
    }
    
    private func setupInitialState() {
        // Create a default HTML file to start with
        let defaultFile = CodeFile(
            id: UUID(),
            name: "index.html",
            content: defaultHTMLContent,
            language: .html,
            isModified: false
        )
        
        openFiles = [defaultFile]
        currentFile = defaultFile
        updatePreview()
    }
    
    private func generateMockAIResponse(for message: String) -> AssistantMessage {
        let responses = [
            "I can help you with that! Let me analyze your code and provide suggestions.",
            "Here's what I think about your code structure...",
            "I notice you're working on HTML/CSS/JavaScript. Would you like me to help optimize it?",
            "Let me suggest some improvements to your code:",
            "I can help you debug this issue. Let me take a look..."
        ]
        
        return AssistantMessage(
            id: UUID(),
            role: .assistant,
            content: responses.randomElement() ?? "How can I help you with your code?",
            timestamp: Date()
        )
    }
}

// MARK: - Supporting Data Models
enum EditorMode: String, CaseIterable {
    case normal = "Normal"
    case vim = "VIM"
    case emacs = "EMACS"
    
    var icon: String {
        switch self {
        case .normal: return "keyboard"
        case .vim: return "terminal"
        case .emacs: return "command"
        }
    }
}

enum ProgrammingLanguage: String, CaseIterable {
    case html = "html"
    case css = "css"
    case javascript = "javascript"
    case swift = "swift"
    case python = "python"
    case json = "json"
    case text = "text"
    
    var displayName: String {
        switch self {
        case .html: return "HTML"
        case .css: return "CSS"
        case .javascript: return "JavaScript"
        case .swift: return "Swift"
        case .python: return "Python"
        case .json: return "JSON"
        case .text: return "Text"
        }
    }
}

enum PreviewMode: String, CaseIterable {
    case html = "HTML"
    case text = "Text"
    case canvas = "Canvas"
}

struct CodeFile: Identifiable, Equatable {
    let id: UUID
    var name: String
    var content: String
    let language: ProgrammingLanguage
    var isModified: Bool
    
    static func == (lhs: CodeFile, rhs: CodeFile) -> Bool {
        lhs.id == rhs.id
    }
}

struct ProjectFile: Identifiable {
    let id = UUID()
    let name: String
    let content: String
    let type: FileType
    
    enum FileType {
        case file
        case folder
    }
}

struct AssistantMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    enum MessageRole {
        case user
        case assistant
    }
}

// MARK: - Sample Data
let sampleProjectFiles: [ProjectFile] = [
    ProjectFile(name: "index.html", content: defaultHTMLContent, type: .file),
    ProjectFile(name: "style.css", content: defaultCSSContent, type: .file),
    ProjectFile(name: "script.js", content: defaultJSContent, type: .file),
    ProjectFile(name: "canvas-demo.html", content: defaultCanvasContent, type: .file),
]

let defaultHTMLContent = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GooseCode Pro - HTML Preview</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
            color: #333;
        }
        .header {
            text-align: center;
            margin-bottom: 2rem;
            padding: 2rem;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 10px;
        }
        .feature {
            background: #f8f9fa;
            padding: 1rem;
            margin: 1rem 0;
            border-radius: 8px;
            border-left: 4px solid #007bff;
        }
        button {
            background: #007bff;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
        }
        button:hover {
            background: #0056b3;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🦆 GooseCode Pro</h1>
        <p>VIM/EMACS Style Coding Agent with AI Assistant</p>
    </div>
    
    <div class="feature">
        <h3>🎯 Smart Code Editor</h3>
        <p>Full-featured code editor with syntax highlighting and multiple editing modes.</p>
    </div>
    
    <div class="feature">
        <h3>🤖 AI Assistant</h3>
        <p>GPT-5 powered coding assistant for real-time help and code generation.</p>
    </div>
    
    <div class="feature">
        <h3>👁️ Live Preview</h3>
        <p>Instant preview of HTML, CSS, JavaScript, and Canvas applications.</p>
    </div>
    
    <div style="text-align: center; margin-top: 2rem;">
        <button onclick="showAlert()">Test JavaScript</button>
    </div>
    
    <script>
        function showAlert() {
            alert('JavaScript is working! 🎉');
        }
        
        console.log('GooseCode Pro initialized successfully!');
    </script>
</body>
</html>
"""

let defaultCSSContent = """
/* GooseCode Pro - Sample CSS */
:root {
    --primary-color: #007bff;
    --secondary-color: #6c757d;
    --success-color: #28a745;
    --warning-color: #ffc107;
    --danger-color: #dc3545;
    --light-color: #f8f9fa;
    --dark-color: #343a40;
}

* {
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    margin: 0;
    padding: 0;
    background-color: var(--light-color);
    color: var(--dark-color);
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 15px;
}

.btn {
    display: inline-block;
    padding: 0.375rem 0.75rem;
    margin-bottom: 0;
    font-size: 1rem;
    font-weight: 400;
    line-height: 1.5;
    text-align: center;
    text-decoration: none;
    vertical-align: middle;
    cursor: pointer;
    border: 1px solid transparent;
    border-radius: 0.25rem;
    transition: all 0.15s ease-in-out;
}

.btn-primary {
    color: #fff;
    background-color: var(--primary-color);
    border-color: var(--primary-color);
}

.btn-primary:hover {
    background-color: #0056b3;
    border-color: #004085;
}

.card {
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    padding: 1.5rem;
    margin-bottom: 1rem;
}

.gradient-bg {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
}

@media (max-width: 768px) {
    .container {
        padding: 0 10px;
    }
    
    .card {
        padding: 1rem;
    }
}
"""

let defaultJSContent = """
// GooseCode Pro - Sample JavaScript
console.log('🦆 GooseCode Pro JavaScript Demo');

// Modern JavaScript features demonstration
class CodeEditor {
    constructor(element) {
        this.element = element;
        this.content = '';
        this.language = 'javascript';
        this.init();
    }
    
    init() {
        console.log('Initializing code editor...');
        this.setupEventListeners();
        this.loadSyntaxHighlighting();
    }
    
    setupEventListeners() {
        // Simulate editor event listeners
        console.log('Setting up event listeners');
    }
    
    loadSyntaxHighlighting() {
        console.log(`Loading syntax highlighting for ${this.language}`);
    }
    
    async saveFile() {
        try {
            // Simulate async file saving
            await new Promise(resolve => setTimeout(resolve, 1000));
            console.log('✅ File saved successfully!');
            return true;
        } catch (error) {
            console.error('❌ Failed to save file:', error);
            return false;
        }
    }
    
    // ES6+ features demo
    formatCode = () => {
        console.log('Formatting code with arrow function');
    }
    
    get lineCount() {
        return this.content.split('\\n').length;
    }
}

// Async/await demo
async function initializeApp() {
    console.log('🚀 Initializing GooseCode Pro...');
    
    const editor = new CodeEditor(document.body);
    
    // Destructuring and template literals
    const { language } = editor;
    console.log(`Current language: ${language}`);
    
    // Array methods
    const features = ['Syntax Highlighting', 'Auto-completion', 'Live Preview', 'AI Assistant'];
    const activeFeatures = features
        .filter(feature => feature.includes('Auto') || feature.includes('AI'))
        .map(feature => `✨ ${feature}`);
    
    console.log('Active features:', activeFeatures);
    
    // Promise handling
    try {
        const saved = await editor.saveFile();
        if (saved) {
            console.log('🎉 App initialized successfully!');
        }
    } catch (error) {
        console.error('Failed to initialize:', error);
    }
}

// DOM manipulation demo
function createDemoElements() {
    const container = document.createElement('div');
    container.className = 'demo-container';
    container.innerHTML = `
        <h3>JavaScript Demo</h3>
        <p>This is dynamically generated content!</p>
        <button onclick="showMessage()">Click me!</button>
    `;
    
    document.body.appendChild(container);
}

function showMessage() {
    const messages = [
        '🎯 Great job!',
        '🚀 Keep coding!',
        '💡 You\\'re awesome!',
        '🦆 Goose power!'
    ];
    
    const randomMessage = messages[Math.floor(Math.random() * messages.length)];
    alert(randomMessage);
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeApp);
} else {
    initializeApp();
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { CodeEditor, initializeApp };
}
"""

let defaultCanvasContent = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Canvas Demo - GooseCode Pro</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .canvas-container {
            text-align: center;
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin: 20px 0;
        }
        canvas {
            border: 2px solid #ddd;
            border-radius: 8px;
            cursor: crosshair;
        }
        .controls {
            margin: 20px 0;
        }
        button {
            background: #007bff;
            color: white;
            border: none;
            padding: 10px 15px;
            margin: 5px;
            border-radius: 5px;
            cursor: pointer;
        }
        button:hover {
            background: #0056b3;
        }
        .color-picker {
            margin: 10px;
        }
    </style>
</head>
<body>
    <h1>🎨 Canvas Demo</h1>
    <p>Interactive canvas with drawing capabilities and animations.</p>
    
    <div class="canvas-container">
        <canvas id="drawingCanvas" width="600" height="400"></canvas>
        
        <div class="controls">
            <button onclick="clearCanvas()">Clear Canvas</button>
            <button onclick="startAnimation()">Start Animation</button>
            <button onclick="stopAnimation()">Stop Animation</button>
            <button onclick="drawShapes()">Draw Shapes</button>
            
            <div class="color-picker">
                <label>Brush Color: </label>
                <input type="color" id="colorPicker" value="#007bff" onchange="changeColor()">
                <label>Brush Size: </label>
                <input type="range" id="brushSize" min="1" max="20" value="5" onchange="changeBrushSize()">
            </div>
        </div>
    </div>
    
    <script>
        const canvas = document.getElementById('drawingCanvas');
        const ctx = canvas.getContext('2d');
        
        let isDrawing = false;
        let currentColor = '#007bff';
        let currentBrushSize = 5;
        let animationId = null;
        
        // Drawing functionality
        canvas.addEventListener('mousedown', startDrawing);
        canvas.addEventListener('mousemove', draw);
        canvas.addEventListener('mouseup', stopDrawing);
        canvas.addEventListener('mouseout', stopDrawing);
        
        function startDrawing(e) {
            isDrawing = true;
            draw(e);
        }
        
        function draw(e) {
            if (!isDrawing) return;
            
            const rect = canvas.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            
            ctx.lineWidth = currentBrushSize;
            ctx.lineCap = 'round';
            ctx.strokeStyle = currentColor;
            
            ctx.lineTo(x, y);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(x, y);
        }
        
        function stopDrawing() {
            if (isDrawing) {
                isDrawing = false;
                ctx.beginPath();
            }
        }
        
        function clearCanvas() {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
        }
        
        function changeColor() {
            currentColor = document.getElementById('colorPicker').value;
        }
        
        function changeBrushSize() {
            currentBrushSize = document.getElementById('brushSize').value;
        }
        
        function drawShapes() {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            
            // Draw rectangle
            ctx.fillStyle = '#ff6b6b';
            ctx.fillRect(50, 50, 100, 80);
            
            // Draw circle
            ctx.beginPath();
            ctx.arc(250, 90, 40, 0, 2 * Math.PI);
            ctx.fillStyle = '#4ecdc4';
            ctx.fill();
            
            // Draw triangle
            ctx.beginPath();
            ctx.moveTo(400, 50);
            ctx.lineTo(350, 130);
            ctx.lineTo(450, 130);
            ctx.closePath();
            ctx.fillStyle = '#45b7d1';
            ctx.fill();
            
            // Draw text
            ctx.font = '24px Arial';
            ctx.fillStyle = '#333';
            ctx.fillText('GooseCode Pro Canvas!', 150, 200);
        }
        
        // Animation
        let animationTime = 0;
        
        function animate() {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            
            // Animated circle
            const x = 300 + Math.cos(animationTime * 0.02) * 100;
            const y = 200 + Math.sin(animationTime * 0.02) * 50;
            
            ctx.beginPath();
            ctx.arc(x, y, 20, 0, 2 * Math.PI);
            ctx.fillStyle = `hsl(${animationTime % 360}, 70%, 50%)`;
            ctx.fill();
            
            // Animated text
            ctx.font = '20px Arial';
            ctx.fillStyle = '#333';
            ctx.textAlign = 'center';
            ctx.fillText('Animated Canvas!', 300, 300);
            
            animationTime++;
            animationId = requestAnimationFrame(animate);
        }
        
        function startAnimation() {
            if (!animationId) {
                animate();
            }
        }
        
        function stopAnimation() {
            if (animationId) {
                cancelAnimationFrame(animationId);
                animationId = null;
            }
        }
        
        // Initialize with some demo content
        drawShapes();
        
        console.log('🎨 Canvas demo initialized!');
    </script>
</body>
</html>
"""

#Preview {
    GooseCodeProView()
}
