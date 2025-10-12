import SwiftUI

struct EnhancedTerminalView: View {
    @Binding var output: String
    @Binding var consoleOutput: String
    @Binding var selectedTab: CodeTab
    
    @State private var input = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex = -1
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal tabs
            HStack(spacing: 0) {
                Button(action: { selectedTab = .console }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.caption2)
                        Text("Terminal")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == .console ? Color.blue : Color.clear)
                    .foregroundColor(selectedTab == .console ? .white : .primary)
                    .cornerRadius(6, corners: [.topLeading, .topTrailing])
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { selectedTab = .preview }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                        Text("Console")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == .preview ? Color.blue : Color.clear)
                    .foregroundColor(selectedTab == .preview ? .white : .primary)
                    .cornerRadius(6, corners: [.topLeading, .topTrailing])
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Terminal controls
                HStack(spacing: 8) {
                    Button(action: clearOutput) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: splitTerminal) {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .background(Color(.systemGray6))
            
            // Terminal content
            VStack(spacing: 0) {
                // Output area
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if selectedTab == .console {
                                // Terminal output
                                ForEach(output.components(separatedBy: .newlines).indices, id: \.self) { index in
                                    let line = output.components(separatedBy: .newlines)[index]
                                    TerminalLineView(line: line)
                                        .id("terminal-\(index)")
                                }
                            } else {
                                // Console output
                                ForEach(consoleOutput.components(separatedBy: .newlines).indices, id: \.self) { index in
                                    let line = consoleOutput.components(separatedBy: .newlines)[index]
                                    ConsoleLineView(line: line)
                                        .id("console-\(index)")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    .background(Color.black)
                    .onChange(of: output) { _ in
                        scrollToBottom(proxy, prefix: "terminal")
                    }
                    .onChange(of: consoleOutput) { _ in
                        scrollToBottom(proxy, prefix: "console")
                    }
                }
                
                // Input area (only for terminal)
                if selectedTab == .console {
                    HStack(spacing: 8) {
                        Text("$")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                        
                        TextField("Enter command...", text: $input)
                            .font(.system(.caption, design: .monospaced))
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.white)
                            .onSubmit {
                                executeCommand()
                            }
                            .onKeyPress(.upArrow) {
                                navigateHistory(direction: .up)
                                return .handled
                            }
                            .onKeyPress(.downArrow) {
                                navigateHistory(direction: .down)
                                return .handled
                            }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.black)
                }
            }
        }
    }
    
    private func executeCommand() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        commandHistory.append(command)
        historyIndex = -1
        
        output += "\n$ \(command)"
        
        // Process command
        switch command.lowercased() {
        case "clear":
            output = "GooseCode Terminal v1.0\nReady for development..."
        case "ls", "dir":
            output += "\nindex.html  style.css  main.js  assets/  components/"
        case "pwd":
            output += "\n/Users/goose/projects/goosecode"
        case let cmd where cmd.hasPrefix("echo "):
            let message = String(cmd.dropFirst(5))
            output += "\n\(message)"
        case "npm start":
            output += "\n> Starting development server..."
            output += "\n✓ Server running on http://localhost:3000"
            output += "\n✓ Live reload enabled"
        case "npm install":
            output += "\n> Installing dependencies..."
            output += "\n✓ Dependencies installed successfully"
        case "git status":
            output += "\nOn branch main"
            output += "\nYour branch is up to date with 'origin/main'."
            output += "\n"
            output += "\nChanges not staged for commit:"
            output += "\n  modified:   main.js"
            output += "\n  modified:   style.css"
        case "help":
            output += "\nAvailable commands:"
            output += "\n  ls/dir     - List files"
            output += "\n  pwd        - Show current directory"
            output += "\n  clear      - Clear terminal"
            output += "\n  npm start  - Start development server"
            output += "\n  git status - Show git status"
            output += "\n  help       - Show this help"
        default:
            output += "\nCommand not found: \(command)"
            output += "\nType 'help' for available commands"
        }
        
        input = ""
    }
    
    private func navigateHistory(direction: HistoryDirection) {
        guard !commandHistory.isEmpty else { return }
        
        switch direction {
        case .up:
            if historyIndex == -1 {
                historyIndex = commandHistory.count - 1
            } else if historyIndex > 0 {
                historyIndex -= 1
            }
        case .down:
            if historyIndex != -1 {
                historyIndex += 1
                if historyIndex >= commandHistory.count {
                    historyIndex = -1
                    input = ""
                    return
                }
            }
        }
        
        if historyIndex >= 0 && historyIndex < commandHistory.count {
            input = commandHistory[historyIndex]
        }
    }
    
    private func clearOutput() {
        if selectedTab == .console {
            output = "GooseCode Terminal v1.0\nReady for development..."
        } else {
            consoleOutput = ""
        }
    }
    
    private func splitTerminal() {
        // Placeholder for split terminal functionality
        output += "\n> Split terminal feature coming soon..."
    }
    
    private func scrollToBottom(_ proxy: ScrollViewReader, prefix: String) {
        let lines = selectedTab == .console ? 
            output.components(separatedBy: .newlines) : 
            consoleOutput.components(separatedBy: .newlines)
        
        if !lines.isEmpty {
            let lastIndex = lines.count - 1
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("\(prefix)-\(lastIndex)", anchor: .bottom)
            }
        }
    }
}

struct TerminalLineView: View {
    let line: String
    
    var body: some View {
        HStack {
            Text(line)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(getLineColor(line))
                .textSelection(.enabled)
            Spacer()
        }
    }
    
    private func getLineColor(_ line: String) -> Color {
        if line.hasPrefix("$") {
            return .green
        } else if line.hasPrefix(">") {
            return .blue
        } else if line.contains("✓") || line.contains("✅") {
            return .green
        } else if line.contains("❌") || line.contains("Error") {
            return .red
        } else if line.contains("⚠️") || line.contains("Warning") {
            return .yellow
        }
        return .white
    }
}

struct ConsoleLineView: View {
    let line: String
    
    var body: some View {
        HStack {
            Text(line)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(getConsoleLineColor(line))
                .textSelection(.enabled)
            Spacer()
        }
    }
    
    private func getConsoleLineColor(_ line: String) -> Color {
        if line.contains("ERROR") {
            return .red
        } else if line.contains("WARN") {
            return .yellow
        } else if line.contains("LOG") {
            return .white
        } else if line.contains("Error:") {
            return .red
        }
        return .green
    }
}

enum HistoryDirection {
    case up, down
}

// Key press handling extension
extension View {
    func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> some View {
        self.onKeyPress(key) { _ in
            action()
        }
    }
}
