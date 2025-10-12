# 🪿 GooseCode - VIM/EMACS Style Coding Agent UI

A flexible, web-based code editor with VIM/EMACS keybindings, live preview, and AI assistance capabilities.

## 🚀 Features

### Core Editor
- **VIM Mode**: Full VIM keybindings with Normal, Insert, Visual, and Command modes
- **Syntax Highlighting**: Powered by CodeMirror with support for HTML, CSS, JavaScript
- **Live Preview**: Real-time rendering of HTML/CSS/JavaScript with Canvas support
- **File Management**: Tab-based interface with file explorer
- **Multiple Themes**: Dark, Light, Monokai, Dracula, Solarized, High-contrast

### Interface
- **Flexible Panels**: Resizable Explorer, Editor, Preview, Terminal, and AI Chat panels
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Command Palette**: VIM-style command interface (`:` commands)
- **Status Bar**: Shows cursor position, file status, mode, and errors
- **Keyboard Shortcuts**: Extensive keyboard navigation and shortcuts

### Development Tools
- **Terminal Emulator**: Built-in terminal with custom commands
- **Error Handling**: Real-time error detection and console capture
- **Code Templates**: Pre-built templates for HTML, CSS, JavaScript
- **Canvas Support**: Full HTML5 Canvas API support for graphics and animations

### AI Integration (Ready)
- **Chat Interface**: Simulated AI assistant ready for GPT-5 integration
- **Code Analysis**: Automatic code review and suggestions
- **Template Generation**: AI-powered code generation
- **Debugging Help**: Intelligent error analysis and solutions

## 🏃‍♂️ Quick Start

### Option 1: Local Server
```bash
cd goosecode
python3 -m http.server 8080
# Open http://localhost:8080 in your browser
```

### Option 2: Live Server (VS Code)
1. Install the "Live Server" extension in VS Code
2. Right-click on `index.html` and select "Open with Live Server"

### Option 3: Direct File
Simply open `index.html` in your browser (some features may be limited due to CORS)

## 🎯 VIM Commands

### File Operations
- `:w` - Save current file
- `:q` - Close current file  
- `:wq` - Save and close
- `:e <filename>` - Open file
- `:n <filename>` - Create new file

### Code Operations
- `:run` - Execute code in preview
- `:preview` - Refresh preview panel

### Panel Management
- `:split` - Toggle preview panel
- `:vsplit` - Toggle explorer panel
- `:terminal` - Toggle terminal
- `:ai` - Open AI chat

### Themes
- `:theme dark` - Switch to dark theme
- `:theme light` - Switch to light theme
- `:theme monokai` - Switch to monokai theme

## ⌨️ Keyboard Shortcuts

### Global Shortcuts
- `Ctrl/Cmd + B` - Toggle file explorer
- `Ctrl/Cmd + J` - Toggle preview panel
- `Ctrl/Cmd + \`` - Toggle terminal
- `Ctrl/Cmd + K` - Toggle AI chat
- `Ctrl/Cmd + P` - Command palette
- `F5` - Run code
- `F11` - Toggle fullscreen

### VIM Mode Shortcuts
- `<leader>w` - Save file (leader = space)
- `<leader>q` - Close file
- `<leader>r` - Run code
- `<leader>t` - Toggle terminal
- `<leader>ai` - AI chat
- `gt` / `gT` - Next/previous tab
- `Ctrl + 1-9` - Switch to tab by number

## 🎨 Themes

- **Dark** (default) - Classic dark theme
- **Light** - Clean light theme  
- **Monokai** - Popular syntax highlighting
- **Dracula** - Vibrant purple theme
- **Solarized Dark** - Easy on the eyes
- **High Contrast** - Accessibility focused

## 📱 Layouts

- **Default** - Explorer + Editor + Preview
- **Coding** - Explorer + Editor + Terminal
- **Preview** - Editor + Preview (full width)
- **Minimal** - Editor only
- **AI Assist** - Explorer + Editor + AI Chat

Switch layouts with `Alt + Shift + 1-5` or `:layout <name>`

## 🔧 Terminal Commands

### File Operations
- `ls` - List files
- `cat <file>` - Show file contents
- `edit <file>` - Open file in editor
- `touch <file>` - Create new file
- `rm <file>` - Delete file

### GooseCode Commands
- `run` - Execute code
- `preview` - Refresh preview
- `theme <name>` - Change theme
- `layout <name>` - Change layout
- `vim` - Toggle VIM mode
- `ai <message>` - Send message to AI

### System Commands
- `clear` - Clear terminal
- `history` - Show command history
- `help` - Show available commands
- `about` - About GooseCode

## 🤖 AI Assistant

The AI chat panel includes a simulated assistant that can:
- Analyze your code for errors and improvements
- Generate HTML/CSS/JavaScript templates
- Create Canvas animation examples
- Provide coding help and explanations
- Suggest best practices

**Note**: Currently simulated. Ready for GPT-5 integration when available.

## 🏗️ Architecture

```
goosecode/
├── index.html          # Main application
├── css/
│   ├── main.css        # Core styles and layout
│   ├── themes.css      # Theme system
│   └── editor.css      # CodeMirror customization
├── js/
│   ├── main.js         # Application controller
│   ├── editor.js       # CodeMirror integration
│   ├── vim-bindings.js # VIM functionality
│   ├── panels.js       # Panel management
│   ├── preview.js      # Live preview system
│   ├── terminal.js     # Terminal emulator
│   └── ai-chat.js      # AI assistant interface
└── README.md           # This file
```

## 🔮 Future Enhancements

- **GPT-5 Integration**: Real AI coding assistance
- **Cloud Sync**: Save projects to cloud storage
- **Plugin System**: Extensible architecture
- **Advanced VIM**: More VIM features and plugins
- **Collaboration**: Real-time collaborative editing
- **Package Manager**: NPM/CDN integration
- **Git Integration**: Version control support

## 🐛 Known Issues

- Some VIM commands may need refinement
- Mobile experience could be improved
- File persistence is local storage only
- AI responses are currently simulated

## 🤝 Contributing

This is a prototype/demo project. Future contributions welcome for:
- VIM functionality improvements
- Additional themes and layouts
- Mobile responsiveness
- Performance optimizations
- Real AI integration

## 📄 License

MIT License - Feel free to use and modify!

---

**Built with ❤️ for the coding community**

Enjoy coding with GooseCode! 🪿✨
