// GooseCode Terminal - Basic terminal emulator for web
class GooseCodeTerminal {
    constructor() {
        this.output = null;
        this.input = null;
        this.history = [];
        this.historyIndex = -1;
        this.currentDirectory = '/project';
        this.commands = new Map();
        this.environment = {
            USER: 'goose',
            HOME: '/home/goose',
            PATH: '/bin:/usr/bin:/usr/local/bin',
            PWD: '/project'
        };
        
        this.init();
    }

    init() {
        this.setupElements();
        this.setupCommands();
        this.setupEventListeners();
        this.displayWelcome();
        
        console.log('💻 GooseCode Terminal initialized');
    }

    setupElements() {
        this.output = document.getElementById('terminal-output');
        this.input = document.getElementById('terminal-input');
        
        if (!this.output || !this.input) {
            console.error('Terminal elements not found');
            return;
        }
    }

    setupCommands() {
        // Basic shell commands
        this.commands.set('help', this.cmdHelp.bind(this));
        this.commands.set('clear', this.cmdClear.bind(this));
        this.commands.set('cls', this.cmdClear.bind(this));
        this.commands.set('ls', this.cmdLs.bind(this));
        this.commands.set('dir', this.cmdLs.bind(this));
        this.commands.set('pwd', this.cmdPwd.bind(this));
        this.commands.set('cd', this.cmdCd.bind(this));
        this.commands.set('cat', this.cmdCat.bind(this));
        this.commands.set('echo', this.cmdEcho.bind(this));
        this.commands.set('date', this.cmdDate.bind(this));
        this.commands.set('whoami', this.cmdWhoami.bind(this));
        this.commands.set('env', this.cmdEnv.bind(this));
        this.commands.set('history', this.cmdHistory.bind(this));
        
        // GooseCode specific commands
        this.commands.set('run', this.cmdRun.bind(this));
        this.commands.set('preview', this.cmdPreview.bind(this));
        this.commands.set('edit', this.cmdEdit.bind(this));
        this.commands.set('new', this.cmdNew.bind(this));
        this.commands.set('save', this.cmdSave.bind(this));
        this.commands.set('theme', this.cmdTheme.bind(this));
        this.commands.set('layout', this.cmdLayout.bind(this));
        this.commands.set('vim', this.cmdVim.bind(this));
        this.commands.set('ai', this.cmdAi.bind(this));
        
        // File operations
        this.commands.set('touch', this.cmdTouch.bind(this));
        this.commands.set('rm', this.cmdRm.bind(this));
        this.commands.set('cp', this.cmdCp.bind(this));
        this.commands.set('mv', this.cmdMv.bind(this));
        
        // System info
        this.commands.set('version', this.cmdVersion.bind(this));
        this.commands.set('about', this.cmdAbout.bind(this));
    }

    setupEventListeners() {
        if (!this.input) return;

        // Command input handling
        this.input.addEventListener('keydown', (e) => {
            switch (e.key) {
                case 'Enter':
                    e.preventDefault();
                    this.executeCommand();
                    break;
                case 'ArrowUp':
                    e.preventDefault();
                    this.navigateHistory(-1);
                    break;
                case 'ArrowDown':
                    e.preventDefault();
                    this.navigateHistory(1);
                    break;
                case 'Tab':
                    e.preventDefault();
                    this.autoComplete();
                    break;
                case 'c':
                    if (e.ctrlKey) {
                        e.preventDefault();
                        this.interrupt();
                    }
                    break;
            }
        });

        // Clear terminal button
        const clearBtn = document.querySelector('.clear-terminal');
        clearBtn?.addEventListener('click', () => {
            this.clear();
        });

        // Focus input when terminal panel is clicked
        const terminalPanel = document.getElementById('terminal-panel');
        terminalPanel?.addEventListener('click', () => {
            this.focus();
        });

        // Listen for console messages from preview
        document.addEventListener('goosecode:consoleMessage', (e) => {
            this.displayConsoleMessage(e.detail);
        });
    }

    displayWelcome() {
        this.writeLine('GooseCode Terminal v1.0');
        this.writeLine('Type "help" for available commands');
        this.writeLine('');
    }

    // Command execution
    executeCommand() {
        const command = this.input.value.trim();
        if (!command) return;

        // Add to history
        this.history.push(command);
        this.historyIndex = this.history.length;

        // Display command
        this.writeLine(`$ ${command}`, 'command');

        // Parse and execute
        const [cmd, ...args] = command.split(/\s+/);
        
        if (this.commands.has(cmd)) {
            try {
                this.commands.get(cmd)(args);
            } catch (error) {
                this.writeLine(`Error: ${error.message}`, 'error');
            }
        } else {
            this.writeLine(`Command not found: ${cmd}`, 'error');
            this.writeLine(`Type "help" for available commands`);
        }

        // Clear input
        this.input.value = '';
        this.scrollToBottom();
    }

    navigateHistory(direction) {
        if (this.history.length === 0) return;

        this.historyIndex += direction;
        
        if (this.historyIndex < 0) {
            this.historyIndex = 0;
        } else if (this.historyIndex >= this.history.length) {
            this.historyIndex = this.history.length;
            this.input.value = '';
            return;
        }

        this.input.value = this.history[this.historyIndex] || '';
    }

    autoComplete() {
        const input = this.input.value;
        const [cmd] = input.split(/\s+/);
        
        if (!input.includes(' ')) {
            // Complete command names
            const matches = Array.from(this.commands.keys())
                .filter(command => command.startsWith(cmd));
            
            if (matches.length === 1) {
                this.input.value = matches[0] + ' ';
            } else if (matches.length > 1) {
                this.writeLine(`Available commands: ${matches.join(', ')}`);
            }
        } else {
            // Complete file names
            const editor = window.gooseCodeEditor;
            if (editor) {
                const files = Array.from(editor.files.keys());
                const lastWord = input.split(/\s+/).pop();
                const matches = files.filter(file => file.startsWith(lastWord));
                
                if (matches.length === 1) {
                    const words = input.split(/\s+/);
                    words[words.length - 1] = matches[0];
                    this.input.value = words.join(' ') + ' ';
                } else if (matches.length > 1) {
                    this.writeLine(`Files: ${matches.join(', ')}`);
                }
            }
        }
    }

    interrupt() {
        this.writeLine('^C', 'error');
        this.input.value = '';
    }

    // Output methods
    writeLine(text, className = '') {
        if (!this.output) return;

        const line = document.createElement('div');
        line.className = `terminal-line ${className}`;
        line.textContent = text;
        
        this.output.appendChild(line);
        this.scrollToBottom();
    }

    writeHTML(html, className = '') {
        if (!this.output) return;

        const line = document.createElement('div');
        line.className = `terminal-line ${className}`;
        line.innerHTML = html;
        
        this.output.appendChild(line);
        this.scrollToBottom();
    }

    clear() {
        if (this.output) {
            this.output.innerHTML = '';
        }
    }

    scrollToBottom() {
        if (this.output) {
            this.output.scrollTop = this.output.scrollHeight;
        }
    }

    focus() {
        if (this.input) {
            this.input.focus();
        }
    }

    // Command implementations
    cmdHelp(args) {
        if (args.length > 0) {
            const cmd = args[0];
            const helpText = this.getCommandHelp(cmd);
            this.writeLine(helpText);
        } else {
            this.writeLine('Available commands:');
            this.writeLine('');
            this.writeLine('File Operations:');
            this.writeLine('  ls, dir          - List files');
            this.writeLine('  cat <file>       - Display file contents');
            this.writeLine('  touch <file>     - Create new file');
            this.writeLine('  rm <file>        - Delete file');
            this.writeLine('  edit <file>      - Open file in editor');
            this.writeLine('');
            this.writeLine('GooseCode Commands:');
            this.writeLine('  run              - Execute current code');
            this.writeLine('  preview          - Refresh preview');
            this.writeLine('  new <file>       - Create new file');
            this.writeLine('  save             - Save current file');
            this.writeLine('  theme <name>     - Change theme');
            this.writeLine('  layout <name>    - Change layout');
            this.writeLine('  vim              - Toggle VIM mode');
            this.writeLine('  ai <message>     - Chat with AI');
            this.writeLine('');
            this.writeLine('System Commands:');
            this.writeLine('  clear, cls       - Clear terminal');
            this.writeLine('  pwd              - Show current directory');
            this.writeLine('  cd <dir>         - Change directory');
            this.writeLine('  echo <text>      - Display text');
            this.writeLine('  date             - Show current date/time');
            this.writeLine('  whoami           - Show current user');
            this.writeLine('  env              - Show environment variables');
            this.writeLine('  history          - Show command history');
            this.writeLine('  version          - Show version info');
            this.writeLine('  about            - About GooseCode');
            this.writeLine('');
            this.writeLine('Use "help <command>" for detailed help on a specific command');
        }
    }

    cmdClear() {
        this.clear();
    }

    cmdLs() {
        const editor = window.gooseCodeEditor;
        if (editor) {
            const files = Array.from(editor.files.keys());
            if (files.length === 0) {
                this.writeLine('No files found');
            } else {
                files.forEach(file => {
                    const fileData = editor.files.get(file);
                    const modified = fileData.modified ? '*' : ' ';
                    const size = fileData.content.length;
                    const date = fileData.lastModified.toLocaleDateString();
                    this.writeLine(`${modified} ${file.padEnd(20)} ${size.toString().padStart(8)} ${date}`);
                });
            }
        } else {
            this.writeLine('Editor not available');
        }
    }

    cmdPwd() {
        this.writeLine(this.currentDirectory);
    }

    cmdCd(args) {
        if (args.length === 0) {
            this.currentDirectory = this.environment.HOME;
        } else {
            const dir = args[0];
            if (dir === '..') {
                const parts = this.currentDirectory.split('/');
                if (parts.length > 1) {
                    parts.pop();
                    this.currentDirectory = parts.join('/') || '/';
                }
            } else if (dir.startsWith('/')) {
                this.currentDirectory = dir;
            } else {
                this.currentDirectory = `${this.currentDirectory}/${dir}`.replace('//', '/');
            }
        }
        this.environment.PWD = this.currentDirectory;
    }

    cmdCat(args) {
        if (args.length === 0) {
            this.writeLine('Usage: cat <filename>');
            return;
        }

        const filename = args[0];
        const editor = window.gooseCodeEditor;
        
        if (editor && editor.files.has(filename)) {
            const file = editor.files.get(filename);
            const lines = file.content.split('\n');
            lines.forEach(line => this.writeLine(line));
        } else {
            this.writeLine(`File not found: ${filename}`);
        }
    }

    cmdEcho(args) {
        this.writeLine(args.join(' '));
    }

    cmdDate() {
        this.writeLine(new Date().toString());
    }

    cmdWhoami() {
        this.writeLine(this.environment.USER);
    }

    cmdEnv() {
        Object.entries(this.environment).forEach(([key, value]) => {
            this.writeLine(`${key}=${value}`);
        });
    }

    cmdHistory() {
        this.history.forEach((cmd, index) => {
            this.writeLine(`${(index + 1).toString().padStart(4)} ${cmd}`);
        });
    }

    // GooseCode specific commands
    cmdRun() {
        this.writeLine('Executing code...');
        window.gooseCodeEditor?.runCode();
    }

    cmdPreview() {
        this.writeLine('Refreshing preview...');
        window.gooseCodePreview?.refreshPreview();
    }

    cmdEdit(args) {
        if (args.length === 0) {
            this.writeLine('Usage: edit <filename>');
            return;
        }

        const filename = args[0];
        window.gooseCodeEditor?.openFile(filename);
        this.writeLine(`Opening ${filename} in editor`);
    }

    cmdNew(args) {
        const filename = args.length > 0 ? args[0] : null;
        const newFile = window.gooseCodeEditor?.newFile(filename);
        this.writeLine(`Created new file: ${newFile}`);
    }

    cmdSave() {
        const success = window.gooseCodeEditor?.saveFile();
        this.writeLine(success ? 'File saved successfully' : 'Failed to save file');
    }

    cmdTheme(args) {
        if (args.length === 0) {
            this.writeLine('Available themes: dark, light, high-contrast, monokai, solarized-dark, dracula');
            return;
        }

        const theme = args[0];
        window.gooseCode?.setTheme(theme);
        this.writeLine(`Theme changed to: ${theme}`);
    }

    cmdLayout(args) {
        if (args.length === 0) {
            this.writeLine('Available layouts: default, coding, preview, minimal, ai-assist');
            return;
        }

        const layout = args[0];
        window.gooseCodePanels?.setLayout(layout);
        this.writeLine(`Layout changed to: ${layout}`);
    }

    cmdVim() {
        const vim = window.gooseCodeVim;
        if (vim) {
            if (vim.isEnabled) {
                vim.disable();
                this.writeLine('VIM mode disabled');
            } else {
                vim.enable();
                this.writeLine('VIM mode enabled');
            }
        } else {
            this.writeLine('VIM bindings not available');
        }
    }

    cmdAi(args) {
        if (args.length === 0) {
            window.gooseCode?.switchPanel('aiChat');
            this.writeLine('AI chat panel opened');
        } else {
            const message = args.join(' ');
            window.gooseCode?.switchPanel('aiChat');
            window.gooseCodeAI?.sendMessage(message);
            this.writeLine(`Sent message to AI: ${message}`);
        }
    }

    cmdTouch(args) {
        if (args.length === 0) {
            this.writeLine('Usage: touch <filename>');
            return;
        }

        const filename = args[0];
        const editor = window.gooseCodeEditor;
        
        if (editor) {
            if (!editor.files.has(filename)) {
                editor.newFile(filename);
                this.writeLine(`Created file: ${filename}`);
            } else {
                // Update last modified time
                const file = editor.files.get(filename);
                file.lastModified = new Date();
                this.writeLine(`Updated timestamp for: ${filename}`);
            }
        }
    }

    cmdRm(args) {
        if (args.length === 0) {
            this.writeLine('Usage: rm <filename>');
            return;
        }

        const filename = args[0];
        const editor = window.gooseCodeEditor;
        
        if (editor && editor.files.has(filename)) {
            if (confirm(`Delete file ${filename}?`)) {
                editor.closeFile(filename);
                this.writeLine(`Deleted file: ${filename}`);
            } else {
                this.writeLine('Operation cancelled');
            }
        } else {
            this.writeLine(`File not found: ${filename}`);
        }
    }

    cmdCp(args) {
        if (args.length < 2) {
            this.writeLine('Usage: cp <source> <destination>');
            return;
        }

        const [source, dest] = args;
        const editor = window.gooseCodeEditor;
        
        if (editor && editor.files.has(source)) {
            const sourceFile = editor.files.get(source);
            editor.files.set(dest, {
                content: sourceFile.content,
                mode: sourceFile.mode,
                modified: false,
                created: new Date(),
                lastModified: new Date()
            });
            this.writeLine(`Copied ${source} to ${dest}`);
        } else {
            this.writeLine(`Source file not found: ${source}`);
        }
    }

    cmdMv(args) {
        if (args.length < 2) {
            this.writeLine('Usage: mv <source> <destination>');
            return;
        }

        const [source, dest] = args;
        const editor = window.gooseCodeEditor;
        
        if (editor && editor.files.has(source)) {
            const sourceFile = editor.files.get(source);
            editor.files.set(dest, sourceFile);
            editor.files.delete(source);
            
            // Update current file if it was renamed
            if (editor.currentFile === source) {
                editor.currentFile = dest;
            }
            
            this.writeLine(`Moved ${source} to ${dest}`);
        } else {
            this.writeLine(`Source file not found: ${source}`);
        }
    }

    cmdVersion() {
        this.writeLine('GooseCode v1.0.0');
        this.writeLine('Built with ❤️ by the GooseCode team');
        this.writeLine('');
        this.writeLine('Components:');
        this.writeLine('- CodeMirror 6.65.7');
        this.writeLine('- VIM bindings enabled');
        this.writeLine('- Live preview system');
        this.writeLine('- AI integration ready');
    }

    cmdAbout() {
        this.writeLine('🪿 GooseCode - VIM/EMACS Style Coding Agent');
        this.writeLine('');
        this.writeLine('A flexible web-based code editor with:');
        this.writeLine('- VIM/EMACS keybindings');
        this.writeLine('- Live HTML/CSS/JavaScript preview');
        this.writeLine('- Canvas support for graphics');
        this.writeLine('- AI coding assistance (coming soon)');
        this.writeLine('- Multiple themes and layouts');
        this.writeLine('- Terminal emulator');
        this.writeLine('');
        this.writeLine('Perfect for rapid prototyping and learning!');
    }

    getCommandHelp(cmd) {
        const help = {
            'ls': 'List files in the current project\nUsage: ls',
            'cat': 'Display the contents of a file\nUsage: cat <filename>',
            'edit': 'Open a file in the editor\nUsage: edit <filename>',
            'run': 'Execute the current code in the preview\nUsage: run',
            'theme': 'Change the editor theme\nUsage: theme <theme-name>\nAvailable: dark, light, monokai, etc.',
            'ai': 'Interact with the AI assistant\nUsage: ai <message>'
        };
        
        return help[cmd] || `No help available for command: ${cmd}`;
    }

    // Console message handling
    displayConsoleMessage(data) {
        const { level, args, timestamp } = data;
        const time = new Date(timestamp).toLocaleTimeString();
        const content = args.join(' ');
        
        this.writeHTML(
            `<span class="timestamp">[${time}]</span> <span class="level level-${level}">${level.toUpperCase()}:</span> ${content}`,
            `console-${level}`
        );
    }
}

// Initialize terminal when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.gooseCodeTerminal = new GooseCodeTerminal();
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = GooseCodeTerminal;
}
