import SwiftUI

struct EnhancedChatPaneView: View {
    @Binding var messages: [CodeChatMessage]
    @Binding var input: String
    @Binding var isThinking: Bool
    @Binding var fileContents: [String: String]
    @Binding var currentFile: String
    let onCodeSuggestion: (String, String) -> Void
    
    @State private var selectedModel: AIModel = .gpt4o
    @State private var showingModelSelector = false
    @State private var contextMode: ContextMode = .currentFile
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundColor(.purple)
                
                Text("AI Assistant")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Model selector
                Menu {
                    ForEach(AIModel.allCases, id: \.self) { model in
                        Button(action: { selectedModel = model }) {
                            HStack {
                                Text(model.displayName)
                                if selectedModel == model {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedModel.shortName)
                            .font(.caption2)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(selectedModel.color.opacity(0.2))
                    .cornerRadius(4)
                }
                
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Context mode selector
            HStack {
                Text("Context:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Picker("Context", selection: $contextMode) {
                    ForEach(ContextMode.allCases, id: \.self) { mode in
                        Text(mode.displayName)
                            .font(.caption2)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .scaleEffect(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            EnhancedChatMessageView(
                                message: message,
                                onCodeSuggestion: onCodeSuggestion
                            )
                            .id(message.id)
                        }
                        
                        // Thinking indicator
                        if isThinking {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("AI is thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(8)
                            .id("thinking")
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: isThinking) { _ in
                    scrollToBottom(proxy)
                }
            }
            
            // Input area
            VStack(spacing: 8) {
                Divider()
                
                // Quick actions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        QuickActionButton(
                            title: "Explain Code",
                            icon: "doc.text.magnifyingglass",
                            color: .blue
                        ) {
                            sendQuickMessage("Explain this code: \n\n```\(getFileExtension(currentFile))\n\(fileContents[currentFile] ?? "")\n```")
                        }
                        
                        QuickActionButton(
                            title: "Debug",
                            icon: "ladybug",
                            color: .red
                        ) {
                            sendQuickMessage("Help me debug this code. Look for potential issues: \n\n```\(getFileExtension(currentFile))\n\(fileContents[currentFile] ?? "")\n```")
                        }
                        
                        QuickActionButton(
                            title: "Optimize",
                            icon: "speedometer",
                            color: .green
                        ) {
                            sendQuickMessage("How can I optimize this code for better performance? \n\n```\(getFileExtension(currentFile))\n\(fileContents[currentFile] ?? "")\n```")
                        }
                        
                        QuickActionButton(
                            title: "Add Feature",
                            icon: "plus.circle",
                            color: .purple
                        ) {
                            sendQuickMessage("Suggest a new feature I could add to this application and show me how to implement it.")
                        }
                        
                        QuickActionButton(
                            title: "Tests",
                            icon: "checkmark.circle",
                            color: .orange
                        ) {
                            sendQuickMessage("Write unit tests for this code: \n\n```\(getFileExtension(currentFile))\n\(fileContents[currentFile] ?? "")\n```")
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Text input
                HStack(spacing: 8) {
                    Button(action: { /* File attachment */ }) {
                        Image(systemName: "paperclip")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    TextField("Ask the AI assistant...", text: $input, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...4)
                        .onSubmit {
                            sendMessage()
                        }

                    Button(action: sendMessage) {
                        Image(systemName: isThinking ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(
                                isThinking ? .red :
                                (input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : selectedModel.color)
                            )
                    }
                    .disabled(!isThinking && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
    
    private func sendMessage() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking else { return }
        
        let userMessage = CodeChatMessage(role: .user, content: input)
        messages.append(userMessage)
        
        let userInput = input
        input = ""
        isThinking = true
        
        // Simulate AI response with context
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let response = generateAIResponse(to: userInput, model: selectedModel, context: contextMode)
            let aiMessage = CodeChatMessage(role: .assistant, content: response)
            messages.append(aiMessage)
            isThinking = false
        }
    }
    
    private func sendQuickMessage(_ message: String) {
        input = message
        sendMessage()
    }
    
    private func clearChat() {
        messages.removeAll()
        messages.append(CodeChatMessage(role: .assistant, content: "🚀 Chat cleared! How can I help you with your code today?"))
    }
    
    private func scrollToBottom(_ proxy: ScrollViewReader) {
        let lastId = isThinking ? "thinking" : messages.last?.id
        if let id = lastId {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }
    
    private func generateAIResponse(to input: String, model: AIModel, context: ContextMode) -> String {
        // Enhanced AI response simulation based on model and context
        let contextInfo = getContextInfo()
        
        if input.lowercased().contains("explain") {
            return generateExplanationResponse(model: model, context: contextInfo)
        } else if input.lowercased().contains("debug") {
            return generateDebugResponse(model: model, context: contextInfo)
        } else if input.lowercased().contains("optimize") {
            return generateOptimizationResponse(model: model, context: contextInfo)
        } else if input.lowercased().contains("feature") {
            return generateFeatureResponse(model: model, context: contextInfo)
        } else if input.lowercased().contains("test") {
            return generateTestResponse(model: model, context: contextInfo)
        } else {
            return generateGeneralResponse(model: model, input: input)
        }
    }
    
    private func getContextInfo() -> String {
        switch contextMode {
        case .currentFile:
            return "Current file: \(currentFile)\n\(fileContents[currentFile] ?? "")"
        case .allFiles:
            return fileContents.map { "\($0.key):\n\($0.value)" }.joined(separator: "\n\n")
        case .none:
            return ""
        }
    }
    
    private func generateExplanationResponse(model: AIModel, context: String) -> String {
        let responses = [
            "I'll analyze your code step by step:\n\n1. **HTML Structure**: Your HTML creates a clean layout with a canvas element for drawing\n2. **CSS Styling**: The styles create a modern, responsive design with a gradient background\n3. **JavaScript Logic**: The JS handles canvas drawing with functions for circles, squares, and clearing\n\n**Key Features:**\n• Interactive canvas drawing\n• Responsive design\n• Clean event handling\n\nWould you like me to explain any specific part in more detail?",
            
            "Looking at your code, here's what's happening:\n\n**Canvas Setup**: You're using the HTML5 Canvas API to create an interactive drawing surface. The `getContext('2d')` gives you access to 2D rendering methods.\n\n**Event Handling**: Your buttons trigger JavaScript functions that draw different shapes with random colors and positions.\n\n**Styling**: The CSS creates a professional look with:\n• Gradient background\n• Centered layout\n• Rounded corners\n• Hover effects\n\nThis is a solid foundation for a drawing app! 🎨",
            
            "Your code implements a simple but effective canvas drawing application:\n\n```javascript\n// Canvas initialization\nconst canvas = document.getElementById('canvas');\nconst ctx = canvas.getContext('2d');\n```\n\nThis gets a reference to your canvas and its 2D context for drawing.\n\nThe drawing functions use:\n• `Math.random()` for random positioning\n• `arc()` and `fillRect()` for shapes\n• HSL colors for vibrant, random colors\n\nGreat work on the modular function design!"
        ]
        
        return responses.randomElement() ?? "I can help explain your code! What specific part would you like me to focus on?"
    }
    
    private func generateDebugResponse(model: AIModel, context: String) -> String {
        return "🔍 **Debug Analysis Complete**\n\nI've reviewed your code and found these potential improvements:\n\n**✅ Good Practices:**\n• Clean function separation\n• Proper event handling\n• Canvas context management\n\n**🔧 Suggestions:**\n1. **Error Handling**: Add null checks for canvas context\n2. **Performance**: Consider using `requestAnimationFrame` for animations\n3. **Accessibility**: Add ARIA labels for buttons\n\n**🚀 Enhancement Ideas:**\n• Add undo/redo functionality\n• Implement touch events for mobile\n• Save/load canvas state\n\nWould you like me to show you how to implement any of these improvements?"
    }
    
    private func generateOptimizationResponse(model: AIModel, context: String) -> String {
        return "⚡ **Performance Optimization Suggestions**\n\n**Current Performance: Good ✅**\n\nYour code is already well-structured! Here are some optimizations:\n\n**1. Canvas Optimization:**\n```javascript\n// Use off-screen canvas for complex drawings\nconst offscreenCanvas = new OffscreenCanvas(400, 300);\n```\n\n**2. Event Debouncing:**\n```javascript\n// Prevent rapid clicking issues\nlet isDrawing = false;\nfunction drawCircle() {\n  if (isDrawing) return;\n  isDrawing = true;\n  // ... drawing code\n  setTimeout(() => isDrawing = false, 100);\n}\n```\n\n**3. Memory Management:**\n• Reuse path objects\n• Clear unused event listeners\n• Use object pooling for frequent operations\n\nWant me to implement any of these optimizations?"
    }
    
    private func generateFeatureResponse(model: AIModel, context: String) -> String {
        return "🎨 **Feature Suggestions for Your Canvas App**\n\n**1. Color Picker**\n```javascript\nfunction setDrawColor(color) {\n  ctx.fillStyle = color;\n  ctx.strokeStyle = color;\n}\n```\n\n**2. Brush Size Control**\n```javascript\nlet brushSize = 5;\nfunction setBrushSize(size) {\n  brushSize = size;\n  ctx.lineWidth = size;\n}\n```\n\n**3. Drawing Modes**\n• Freehand drawing\n• Line tool\n• Rectangle tool\n• Text tool\n\n**4. Save/Export**\n```javascript\nfunction saveCanvas() {\n  const link = document.createElement('a');\n  link.download = 'artwork.png';\n  link.href = canvas.toDataURL();\n  link.click();\n}\n```\n\nWhich feature interests you most? I can help implement it! 🚀"
    }
    
    private func generateTestResponse(model: AIModel, context: String) -> String {
        return "🧪 **Unit Tests for Your Canvas App**\n\n```javascript\n// Test suite using Jest\ndescribe('Canvas Drawing App', () => {\n  let canvas, ctx;\n  \n  beforeEach(() => {\n    document.body.innerHTML = '<canvas id=\"canvas\" width=\"400\" height=\"300\"></canvas>';\n    canvas = document.getElementById('canvas');\n    ctx = canvas.getContext('2d');\n  });\n  \n  test('should initialize canvas context', () => {\n    expect(ctx).toBeDefined();\n    expect(canvas.width).toBe(400);\n    expect(canvas.height).toBe(300);\n  });\n  \n  test('should draw circle within bounds', () => {\n    const spy = jest.spyOn(ctx, 'arc');\n    drawCircle();\n    expect(spy).toHaveBeenCalled();\n  });\n  \n  test('should clear canvas', () => {\n    const spy = jest.spyOn(ctx, 'clearRect');\n    clearCanvas();\n    expect(spy).toHaveBeenCalledWith(0, 0, 400, 300);\n  });\n});\n```\n\nWould you like me to add more test cases or help set up the testing environment?"
    }
    
    private func generateGeneralResponse(model: AIModel, input: String) -> String {
        let responses = [
            "I'm here to help with your coding project! I can assist with HTML, CSS, JavaScript, Canvas programming, debugging, optimization, and much more. What specific challenge are you working on?",
            
            "Great question! As your AI coding assistant, I can help you with:\n• Code explanation and documentation\n• Debugging and troubleshooting\n• Performance optimization\n• Feature implementation\n• Best practices and patterns\n• Testing strategies\n\nWhat would you like to explore?",
            
            "I'm powered by advanced language models and trained on extensive coding knowledge. I can help you build better applications, solve complex problems, and learn new techniques. What's your current coding challenge?"
        ]
        
        return responses.randomElement() ?? "How can I help you with your code today?"
    }
    
    private func getFileExtension(_ filename: String) -> String {
        if filename.hasSuffix(".html") { return "html" }
        if filename.hasSuffix(".css") { return "css" }
        if filename.hasSuffix(".js") { return "javascript" }
        return "text"
    }
}

struct EnhancedChatMessageView: View {
    let message: CodeChatMessage
    let onCodeSuggestion: (String, String) -> Void
    
    @State private var showingCodeBlocks = true
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar
            Circle()
                .fill(message.role == .user ? Color.blue : Color.purple)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: message.role == .user ? "person.fill" : "brain")
                        .font(.caption)
                        .foregroundColor(.white)
                )
            
            // Message content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(message.role == .user ? "You" : "AI Assistant")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Parse and display message with code blocks
                MessageContentView(
                    content: message.content,
                    onCodeSuggestion: onCodeSuggestion
                )
            }
            
            Spacer()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MessageContentView: View {
    let content: String
    let onCodeSuggestion: (String, String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let parts = parseMessageContent(content)
            
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                switch part {
                case .text(let text):
                    Text(text)
                        .font(.caption)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                        
                case .code(let code, let language):
                    CodeBlockView(
                        code: code,
                        language: language,
                        onApply: { appliedCode in
                            let filename = getFilename(for: language)
                            onCodeSuggestion(appliedCode, filename)
                        }
                    )
                }
            }
        }
    }
    
    private func parseMessageContent(_ content: String) -> [MessagePart] {
        var parts: [MessagePart] = []
        let lines = content.components(separatedBy: .newlines)
        var currentText = ""
        var inCodeBlock = false
        var currentCode = ""
        var currentLanguage = ""
        
        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    if !currentCode.isEmpty {
                        parts.append(.code(currentCode.trimmingCharacters(in: .whitespacesAndNewlines), currentLanguage))
                    }
                    currentCode = ""
                    currentLanguage = ""
                    inCodeBlock = false
                } else {
                    // Start code block
                    if !currentText.isEmpty {
                        parts.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                        currentText = ""
                    }
                    currentLanguage = String(line.dropFirst(3))
                    inCodeBlock = true
                }
            } else {
                if inCodeBlock {
                    currentCode += line + "\n"
                } else {
                    currentText += line + "\n"
                }
            }
        }
        
        // Add remaining content
        if !currentText.isEmpty {
            parts.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        if !currentCode.isEmpty {
            parts.append(.code(currentCode.trimmingCharacters(in: .whitespacesAndNewlines), currentLanguage))
        }
        
        return parts
    }
    
    private func getFilename(for language: String) -> String {
        switch language.lowercased() {
        case "html": return "index.html"
        case "css": return "style.css"
        case "javascript", "js": return "main.js"
        default: return "code.txt"
        }
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String
    let onApply: (String) -> Void
    
    @State private var showingFullCode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Code block header
            HStack {
                Image(systemName: "doc.text")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(language.isEmpty ? "Code" : language.capitalized)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showingFullCode.toggle() }) {
                    Image(systemName: showingFullCode ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                
                Button(action: { onApply(code) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.caption2)
                        Text("Apply")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            }
            
            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.caption2, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .lineLimit(showingFullCode ? nil : 5)
            }
            .background(Color.black)
            .cornerRadius(6)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Data Models

enum MessagePart {
    case text(String)
    case code(String, String) // code, language
}

enum AIModel: CaseIterable {
    case gpt4o, gpt4, claude, gemini, codellama
    
    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o"
        case .gpt4: return "GPT-4"
        case .claude: return "Claude 3.5 Sonnet"
        case .gemini: return "Gemini Pro"
        case .codellama: return "Code Llama"
        }
    }
    
    var shortName: String {
        switch self {
        case .gpt4o: return "GPT-4o"
        case .gpt4: return "GPT-4"
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .codellama: return "Llama"
        }
    }
    
    var color: Color {
        switch self {
        case .gpt4o: return .green
        case .gpt4: return .blue
        case .claude: return .orange
        case .gemini: return .purple
        case .codellama: return .red
        }
    }
}

enum ContextMode: CaseIterable {
    case none, currentFile, allFiles
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .currentFile: return "Current"
        case .allFiles: return "All Files"
        }
    }
}
