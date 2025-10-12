import SwiftUI

struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    let onCommand: (String) -> Void
    
    @State private var searchText = ""
    @State private var selectedIndex = 0
    
    private let commands = [
        Command(name: "Toggle File Explorer", description: "Show/hide the file explorer panel", shortcut: "⌘E", action: "toggle explorer"),
        Command(name: "Toggle Terminal", description: "Show/hide the terminal panel", shortcut: "⌘T", action: "toggle terminal"),
        Command(name: "Toggle Chat Assistant", description: "Show/hide the AI chat panel", shortcut: "⌘A", action: "toggle chat"),
        Command(name: "Toggle Preview", description: "Show/hide the live preview", shortcut: "⌘P", action: "toggle preview"),
        Command(name: "Run Code", description: "Execute the current application", shortcut: "⌘R", action: "run"),
        Command(name: "New File", description: "Create a new file", shortcut: "⌘N", action: "new file"),
        Command(name: "Save File", description: "Save the current file", shortcut: "⌘S", action: "save"),
        Command(name: "Clear Terminal", description: "Clear the terminal output", shortcut: "⌘K", action: "clear terminal"),
        Command(name: "Format Code", description: "Format the current file", shortcut: "⌘F", action: "format"),
        Command(name: "Find in Files", description: "Search across all files", shortcut: "⌘⇧F", action: "find"),
        Command(name: "Go to Line", description: "Jump to a specific line number", shortcut: "⌘G", action: "goto line"),
        Command(name: "Comment Toggle", description: "Toggle line/block comments", shortcut: "⌘/", action: "comment"),
        Command(name: "Duplicate Line", description: "Duplicate current line", shortcut: "⌘D", action: "duplicate"),
        Command(name: "Delete Line", description: "Delete current line", shortcut: "⌘⌫", action: "delete line"),
        Command(name: "Move Line Up", description: "Move current line up", shortcut: "⌥↑", action: "move up"),
        Command(name: "Move Line Down", description: "Move current line down", shortcut: "⌥↓", action: "move down"),
        Command(name: "Zen Mode", description: "Enter distraction-free mode", shortcut: "⌘Z", action: "zen mode"),
        Command(name: "Split Editor", description: "Split the editor vertically", shortcut: "⌘\\", action: "split editor"),
        Command(name: "Close Tab", description: "Close the current file tab", shortcut: "⌘W", action: "close tab"),
        Command(name: "Reload Preview", description: "Refresh the live preview", shortcut: "⌘⇧R", action: "reload preview")
    ]
    
    private var filteredCommands: [Command] {
        if searchText.isEmpty {
            return commands
        } else {
            return commands.filter { command in
                command.name.localizedCaseInsensitiveContains(searchText) ||
                command.description.localizedCaseInsensitiveContains(searchText) ||
                command.action.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.title3)
                    
                    TextField("Type a command or search...", text: $searchText)
                        .font(.title3)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            executeSelectedCommand()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                
                Divider()
                
                // Commands list
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                            CommandRowView(
                                command: command,
                                isSelected: index == selectedIndex
                            )
                            .onTapGesture {
                                selectedIndex = index
                                executeSelectedCommand()
                            }
                            .id(command.id)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .onChange(of: searchText) { _ in
                        selectedIndex = 0
                        scrollToSelected(proxy)
                    }
                    .onChange(of: selectedIndex) { _ in
                        scrollToSelected(proxy)
                    }
                }
                
                // Footer with shortcuts
                HStack {
                    Text("↑↓ Navigate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("⏎ Execute")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("⎋ Cancel")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
            .navigationTitle("Command Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            // Focus search field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // TextField will be focused automatically
            }
        }
        .onKeyPress(.upArrow) {
            navigateUp()
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateDown()
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }
    
    private func navigateUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }
    
    private func navigateDown() {
        if selectedIndex < filteredCommands.count - 1 {
            selectedIndex += 1
        }
    }
    
    private func executeSelectedCommand() {
        guard selectedIndex < filteredCommands.count else { return }
        let command = filteredCommands[selectedIndex]
        onCommand(command.action)
        isPresented = false
    }
    
    private func scrollToSelected(_ proxy: ScrollViewReader) {
        guard selectedIndex < filteredCommands.count else { return }
        let command = filteredCommands[selectedIndex]
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(command.id, anchor: .center)
        }
    }
}

struct CommandRowView: View {
    let command: Command
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Command icon
            Image(systemName: command.icon)
                .font(.title3)
                .foregroundColor(isSelected ? .white : .blue)
                .frame(width: 24)
            
            // Command details
            VStack(alignment: .leading, spacing: 2) {
                Text(command.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(command.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Keyboard shortcut
            if !command.shortcut.isEmpty {
                Text(command.shortcut)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color(.systemGray5))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.blue : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}

struct Command: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let shortcut: String
    let action: String
    
    var icon: String {
        switch action {
        case "toggle explorer": return "sidebar.left"
        case "toggle terminal": return "terminal"
        case "toggle chat": return "bubble.left.and.bubble.right"
        case "toggle preview": return "eye"
        case "run": return "play.fill"
        case "new file": return "doc.badge.plus"
        case "save": return "square.and.arrow.down"
        case "clear terminal": return "trash"
        case "format": return "text.alignleft"
        case "find": return "magnifyingglass"
        case "goto line": return "arrow.right.to.line"
        case "comment": return "text.bubble"
        case "duplicate": return "doc.on.doc"
        case "delete line": return "minus.circle"
        case "move up": return "arrow.up"
        case "move down": return "arrow.down"
        case "zen mode": return "eye.slash"
        case "split editor": return "rectangle.split.2x1"
        case "close tab": return "xmark"
        case "reload preview": return "arrow.clockwise"
        default: return "command"
        }
    }
}

// Key press handling for command palette
extension View {
    func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> some View {
        self.onKeyPress(key) { _ in
            action()
        }
    }
}
