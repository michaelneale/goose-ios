# GooseCode - VIM/EMACS Style Coding Agent UI

GooseCode is a flexible, VIM/EMACS-inspired coding interface integrated into the Goose iOS app. It provides a powerful development environment with AI assistance for building HTML/CSS/JavaScript applications.

## Features

### 🎯 Core Interface
- **Multi-pane Layout**: File explorer, code editor, live preview, terminal, and AI chat
- **VIM/EMACS Mode Support**: Normal, Insert, Visual, and Command modes
- **Flexible Layout**: Resizable panes, toggle visibility, customizable workspace
- **Tab Management**: Multiple open files with easy switching

### 🧠 AI Assistant Integration
- **Multiple AI Models**: GPT-4o, GPT-4, Claude 3.5 Sonnet, Gemini Pro, Code Llama
- **Context Awareness**: Current file, all files, or no context modes
- **Smart Code Suggestions**: Explanations, debugging, optimization, feature additions
- **Quick Actions**: One-click access to common AI tasks

### 💻 Code Editor
- **Syntax Highlighting**: HTML, CSS, JavaScript support
- **Line Numbers**: Professional editor appearance
- **VIM Commands**: Basic VIM command support (:w, :q, :wq)
- **Multi-file Editing**: Work with multiple files simultaneously

### 🌐 Live Preview
- **Real-time Updates**: See changes instantly as you code
- **WebKit Integration**: Full browser environment in-app
- **Console Capture**: JavaScript console output displayed in terminal
- **Error Handling**: Runtime errors captured and displayed

### 🖥️ Enhanced Terminal
- **Dual Mode**: Terminal commands and JavaScript console output
- **Command History**: Navigate previous commands with arrow keys
- **Built-in Commands**: ls, pwd, clear, npm commands, git status
- **Split View**: Separate terminal and console tabs

### 📁 File Management
- **Tree View**: Hierarchical file and folder display
- **File Icons**: Language-specific icons and colors
- **Quick Actions**: New file/folder creation
- **Open File Indicators**: Visual indication of open files

### ⌨️ Command Palette
- **Quick Access**: ⌘+P to open command palette
- **Fuzzy Search**: Find commands by name or description
- **Keyboard Shortcuts**: Full keyboard navigation support
- **Comprehensive Commands**: 20+ built-in commands

## Usage

### Accessing GooseCode

1. **From Sidebar Menu**: Tap the hamburger menu → "GooseCode Pro"
2. **From Test Page**: Navigate to Test Page → "GooseCode" link

### Basic Workflow

1. **File Management**: Use the file explorer to create/open files
2. **Code Editing**: Write code in the main editor with syntax highlighting
3. **Live Preview**: See your changes in real-time in the preview pane
4. **AI Assistance**: Ask the AI for help, explanations, or code improvements
5. **Terminal**: Run commands and see console output

### VIM Mode Commands

- **Normal Mode**: Default mode for navigation
- **Insert Mode**: Press 'i' or tap editor to start editing
- **Command Mode**: Press ':' to enter commands
  - `:w` - Save file
  - `:q` - Quit/close file
  - `:wq` - Save and quit

### AI Assistant Usage

#### Quick Actions
- **Explain Code**: Get detailed code explanations
- **Debug**: Find and fix issues in your code
- **Optimize**: Improve performance and best practices
- **Add Feature**: Get suggestions for new functionality
- **Tests**: Generate unit tests for your code

#### Context Modes
- **None**: AI has no code context
- **Current**: AI sees only the current file
- **All Files**: AI has access to all project files

### Command Palette

Press `⌘` button or use the command palette for quick actions:
- Toggle panels (Explorer, Terminal, Chat, Preview)
- File operations (New, Save, Close)
- Editor commands (Format, Find, Go to Line)
- Layout management (Split, Zen Mode)

## Sample Project

The default project includes:
- **index.html**: Basic HTML structure with canvas element
- **style.css**: Modern CSS with gradient backgrounds and responsive design
- **main.js**: Interactive canvas drawing with circles and squares

## Technical Implementation

### Architecture
- **SwiftUI**: Native iOS interface
- **WebKit**: Live preview rendering
- **Combine**: Reactive data flow
- **Core Animation**: Smooth transitions and animations

### File Structure
```
Goose/
├── EnhancedGooseCodeView.swift      # Main container view
├── EnhancedCodeEditorView.swift     # Code editor with syntax highlighting
├── LivePreviewView.swift            # WebKit-based preview
├── EnhancedTerminalView.swift       # Terminal and console
├── EnhancedChatPaneView.swift       # AI assistant interface
├── CommandPaletteView.swift         # Command palette
└── Supporting Views/                # File explorer, tabs, etc.
```

### Key Features Implementation
- **Syntax Highlighting**: Custom text parsing and coloring
- **VIM Mode**: State machine for editor modes
- **Live Preview**: HTML/CSS/JS compilation and WebKit rendering
- **AI Integration**: Simulated responses with context awareness
- **Command System**: Extensible command architecture

## Future Enhancements

### Planned Features
- **Real AI Integration**: Connect to actual AI APIs
- **Git Integration**: Version control within the editor
- **Plugin System**: Extensible architecture for custom tools
- **Collaborative Editing**: Multi-user editing support
- **Cloud Sync**: Project synchronization across devices
- **Advanced VIM**: More VIM commands and features
- **Debugger**: Step-through debugging for JavaScript
- **Package Manager**: NPM integration for dependencies

### Technical Improvements
- **Performance**: Optimize for large files and projects
- **Memory Management**: Better resource handling
- **Accessibility**: Full VoiceOver and accessibility support
- **Internationalization**: Multi-language support
- **Testing**: Comprehensive unit and UI tests

## Contributing

This is part of the open-source Goose project. Contributions are welcome!

### Development Setup
1. Clone the repository
2. Open `Goose.xcodeproj` in Xcode
3. Build and run on iOS Simulator or device
4. Navigate to GooseCode Pro from the sidebar menu

### Code Style
- Follow Swift best practices
- Use SwiftUI for all UI components
- Maintain VIM/EMACS compatibility where possible
- Keep AI interactions context-aware and helpful

## License

Part of the Goose project by Block, Inc. Open source under the project's license terms.
