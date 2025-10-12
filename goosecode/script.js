// GooseCode - AI Coding Agent Interface
class GooseCodeEditor {
    constructor() {
        this.currentMode = 'vim';
        this.currentFile = 'index.html';
        this.files = {
            'index.html': '',
            'style.css': '',
            'script.js': ''
        };
        this.commandHistory = [];
        this.isCommandPaletteOpen = false;
        this.vimMode = 'insert'; // insert, normal, visual
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.updateLineNumbers();
        this.loadInitialCode();
        this.updatePreview();
        this.setupKeyboardShortcuts();
    }

    setupEventListeners() {
        // Mode switching
        document.querySelectorAll('.mode-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.switchMode(e.target.dataset.mode);
            });
        });

        // Sidebar toggle
        document.getElementById('sidebar-toggle').addEventListener('click', () => {
            this.toggleSidebar();
        });

        // Preview toggle
        document.getElementById('preview-toggle').addEventListener('click', () => {
            this.togglePreview();
        });

        // Chat toggle
        document.getElementById('chat-toggle').addEventListener('click', () => {
            this.toggleChat();
        });

        // Run button
        document.getElementById('run-btn').addEventListener('click', () => {
            this.runCode();
        });

        // Refresh preview
        document.getElementById('refresh-preview').addEventListener('click', () => {
            this.updatePreview();
        });

        // Code editor
        const editor = document.getElementById('code-editor');
        editor.addEventListener('input', () => {
            this.updateLineNumbers();
            this.updatePreview();
            this.updateCursorPosition();
        });

        editor.addEventListener('keydown', (e) => {
            this.handleEditorKeydown(e);
        });

        editor.addEventListener('click', () => {
            this.updateCursorPosition();
        });

        // Chat input
        const chatInput = document.getElementById('chat-input');
        chatInput.addEventListener('keydown', (e) => {
            if (e.ctrlKey && e.key === 'Enter') {
                this.sendMessage();
            }
        });

        document.getElementById('send-btn').addEventListener('click', () => {
            this.sendMessage();
        });

        // File tree
        document.querySelectorAll('.file-item').forEach(item => {
            item.addEventListener('click', (e) => {
                const fileName = e.target.textContent.trim();
                this.switchFile(fileName);
            });
        });

        // Tab switching
        document.querySelectorAll('.tab').forEach(tab => {
            tab.addEventListener('click', (e) => {
                if (!e.target.classList.contains('tab-close')) {
                    const fileName = tab.dataset.file;
                    this.switchFile(fileName);
                }
            });
        });

        // Tab closing
        document.querySelectorAll('.tab-close').forEach(closeBtn => {
            closeBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                const tab = e.target.closest('.tab');
                const fileName = tab.dataset.file;
                this.closeTab(fileName);
            });
        });
    }

    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Command palette
            if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'P') {
                e.preventDefault();
                this.toggleCommandPalette();
            }

            // Save
            if ((e.ctrlKey || e.metaKey) && e.key === 's') {
                e.preventDefault();
                this.saveFile();
            }

            // Run
            if ((e.ctrlKey || e.metaKey) && e.key === 'r') {
                e.preventDefault();
                this.runCode();
            }

            // Toggle sidebar
            if ((e.ctrlKey || e.metaKey) && e.key === 'b') {
                e.preventDefault();
                this.toggleSidebar();
            }

            // Escape to close command palette
            if (e.key === 'Escape' && this.isCommandPaletteOpen) {
                this.toggleCommandPalette();
            }

            // Vim mode shortcuts
            if (this.currentMode === 'vim') {
                this.handleVimShortcuts(e);
            }
        });
    }

    handleVimShortcuts(e) {
        const editor = document.getElementById('code-editor');
        
        if (e.key === 'Escape' && this.vimMode === 'insert') {
            this.vimMode = 'normal';
            this.updateModeIndicator();
            editor.blur();
        }
        
        if (this.vimMode === 'normal' && !e.ctrlKey && !e.metaKey) {
            switch(e.key) {
                case 'i':
                    e.preventDefault();
                    this.vimMode = 'insert';
                    this.updateModeIndicator();
                    editor.focus();
                    break;
                case 'a':
                    e.preventDefault();
                    this.vimMode = 'insert';
                    this.updateModeIndicator();
                    editor.focus();
                    // Move cursor one position right
                    editor.selectionStart = editor.selectionStart + 1;
                    editor.selectionEnd = editor.selectionStart;
                    break;
                case 'o':
                    e.preventDefault();
                    this.vimMode = 'insert';
                    this.updateModeIndicator();
                    this.insertNewLine();
                    editor.focus();
                    break;
            }
        }
    }

    handleEditorKeydown(e) {
        // Tab handling
        if (e.key === 'Tab') {
            e.preventDefault();
            const editor = e.target;
            const start = editor.selectionStart;
            const end = editor.selectionEnd;
            
            // Insert 2 spaces instead of tab
            editor.value = editor.value.substring(0, start) + '  ' + editor.value.substring(end);
            editor.selectionStart = editor.selectionEnd = start + 2;
            
            this.updateLineNumbers();
        }
    }

    switchMode(mode) {
        this.currentMode = mode;
        
        // Update UI
        document.querySelectorAll('.mode-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.mode === mode);
        });
        
        // Update body class for styling
        document.body.className = `${mode}-mode`;
        
        // Update mode indicator
        this.vimMode = mode === 'vim' ? 'insert' : 'emacs';
        this.updateModeIndicator();
        
        this.showStatus(`Switched to ${mode.toUpperCase()} mode`);
    }

    updateModeIndicator() {
        const indicator = document.getElementById('mode-indicator');
        if (this.currentMode === 'vim') {
            indicator.textContent = `-- ${this.vimMode.toUpperCase()} --`;
        } else {
            indicator.textContent = '-- EMACS --';
        }
    }

    toggleSidebar() {
        const sidebar = document.getElementById('sidebar');
        sidebar.classList.toggle('collapsed');
        
        const toggle = document.getElementById('sidebar-toggle');
        const icon = toggle.querySelector('i');
        
        if (sidebar.classList.contains('collapsed')) {
            icon.className = 'fas fa-chevron-right';
        } else {
            icon.className = 'fas fa-chevron-left';
        }
    }

    togglePreview() {
        const preview = document.getElementById('preview-panel');
        preview.classList.toggle('collapsed');
        
        const toggle = document.getElementById('preview-toggle');
        const icon = toggle.querySelector('i');
        
        if (preview.classList.contains('collapsed')) {
            icon.className = 'fas fa-chevron-left';
        } else {
            icon.className = 'fas fa-chevron-right';
        }
    }

    toggleChat() {
        const chat = document.getElementById('ai-chat');
        chat.classList.toggle('collapsed');
        
        const toggle = document.getElementById('chat-toggle');
        const icon = toggle.querySelector('i');
        
        if (chat.classList.contains('collapsed')) {
            icon.className = 'fas fa-chevron-up';
        } else {
            icon.className = 'fas fa-chevron-down';
        }
    }

    toggleCommandPalette() {
        const palette = document.getElementById('command-palette');
        this.isCommandPaletteOpen = !this.isCommandPaletteOpen;
        
        if (this.isCommandPaletteOpen) {
            palette.classList.add('active');
            document.getElementById('command-input').focus();
            this.populateCommandSuggestions();
        } else {
            palette.classList.remove('active');
        }
    }

    populateCommandSuggestions() {
        const suggestions = document.getElementById('command-suggestions');
        const commands = [
            { icon: 'fas fa-play', name: 'Run Code', action: 'run' },
            { icon: 'fas fa-save', name: 'Save File', action: 'save' },
            { icon: 'fas fa-file-plus', name: 'New File', action: 'new' },
            { icon: 'fas fa-sync-alt', name: 'Refresh Preview', action: 'refresh' },
            { icon: 'fas fa-cog', name: 'Settings', action: 'settings' },
            { icon: 'fas fa-robot', name: 'Ask AI Assistant', action: 'ai' }
        ];
        
        suggestions.innerHTML = commands.map(cmd => `
            <div class="command-suggestion" data-action="${cmd.action}">
                <i class="${cmd.icon}"></i>
                <span>${cmd.name}</span>
            </div>
        `).join('');
        
        // Add click handlers
        suggestions.querySelectorAll('.command-suggestion').forEach(item => {
            item.addEventListener('click', () => {
                this.executeCommand(item.dataset.action);
                this.toggleCommandPalette();
            });
        });
    }

    executeCommand(action) {
        switch(action) {
            case 'run':
                this.runCode();
                break;
            case 'save':
                this.saveFile();
                break;
            case 'new':
                this.createNewFile();
                break;
            case 'refresh':
                this.updatePreview();
                break;
            case 'ai':
                document.getElementById('chat-input').focus();
                break;
        }
    }

    updateLineNumbers() {
        const editor = document.getElementById('code-editor');
        const lineNumbers = document.getElementById('line-numbers');
        const lines = editor.value.split('\n');
        
        lineNumbers.innerHTML = lines.map((_, index) => 
            `<div>${index + 1}</div>`
        ).join('');
    }

    updateCursorPosition() {
        const editor = document.getElementById('code-editor');
        const text = editor.value.substring(0, editor.selectionStart);
        const lines = text.split('\n');
        const line = lines.length;
        const col = lines[lines.length - 1].length + 1;
        
        document.querySelector('.cursor-position').textContent = `Ln ${line}, Col ${col}`;
    }

    loadInitialCode() {
        const editor = document.getElementById('code-editor');
        this.files[this.currentFile] = editor.value;
    }

    switchFile(fileName) {
        // Save current file content
        const editor = document.getElementById('code-editor');
        this.files[this.currentFile] = editor.value;
        
        // Switch to new file
        this.currentFile = fileName;
        editor.value = this.files[fileName] || this.getDefaultContent(fileName);
        
        // Update UI
        document.querySelectorAll('.tab').forEach(tab => {
            tab.classList.toggle('active', tab.dataset.file === fileName);
        });
        
        // Update file type indicator
        const extension = fileName.split('.').pop().toUpperCase();
        document.querySelector('.file-type').textContent = extension;
        
        this.updateLineNumbers();
        this.updatePreview();
        this.showStatus(`Switched to ${fileName}`);
    }

    getDefaultContent(fileName) {
        const templates = {
            'index.html': `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My App</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <h1>Hello World!</h1>
    <script src="script.js"></script>
</body>
</html>`,
            'style.css': `body {
    font-family: Arial, sans-serif;
    margin: 0;
    padding: 20px;
    background: #f0f0f0;
}

h1 {
    color: #333;
    text-align: center;
}`,
            'script.js': `// Your JavaScript code here
console.log('Hello from GooseCode!');

document.addEventListener('DOMContentLoaded', function() {
    // Your code here
});`
        };
        
        return templates[fileName] || '';
    }

    closeTab(fileName) {
        // Don't close if it's the last tab
        const tabs = document.querySelectorAll('.tab');
        if (tabs.length <= 1) return;
        
        // Remove the tab
        const tab = document.querySelector(`[data-file="${fileName}"]`);
        tab.remove();
        
        // If closing current file, switch to first available tab
        if (fileName === this.currentFile) {
            const remainingTabs = document.querySelectorAll('.tab');
            if (remainingTabs.length > 0) {
                this.switchFile(remainingTabs[0].dataset.file);
            }
        }
        
        // Clear file content
        delete this.files[fileName];
    }

    runCode() {
        this.showStatus('Running code...', 'loading');
        this.updatePreview();
        setTimeout(() => {
            this.showStatus('Code executed successfully');
        }, 1000);
    }

    updatePreview() {
        const iframe = document.getElementById('preview-frame');
        const htmlContent = this.files['index.html'] || document.getElementById('code-editor').value;
        
        // Create a complete HTML document with inline CSS and JS
        const cssContent = this.files['style.css'] || '';
        const jsContent = this.files['script.js'] || '';
        
        const fullHTML = htmlContent.replace(
            '<link rel="stylesheet" href="style.css">',
            `<style>${cssContent}</style>`
        ).replace(
            '<script src="script.js"></script>',
            `<script>${jsContent}</script>`
        );
        
        iframe.srcdoc = fullHTML;
    }

    saveFile() {
        const editor = document.getElementById('code-editor');
        this.files[this.currentFile] = editor.value;
        this.showStatus(`Saved ${this.currentFile}`);
    }

    insertNewLine() {
        const editor = document.getElementById('code-editor');
        const cursorPos = editor.selectionStart;
        const textBefore = editor.value.substring(0, cursorPos);
        const textAfter = editor.value.substring(cursorPos);
        
        editor.value = textBefore + '\n' + textAfter;
        editor.selectionStart = editor.selectionEnd = cursorPos + 1;
    }

    sendMessage() {
        const input = document.getElementById('chat-input');
        const message = input.value.trim();
        
        if (!message) return;
        
        // Add user message
        this.addChatMessage(message, 'user');
        input.value = '';
        
        // Simulate AI response
        this.showStatus('AI is thinking...', 'loading');
        setTimeout(() => {
            this.simulateAIResponse(message);
            this.showStatus('AI Ready');
        }, 1500);
    }

    addChatMessage(content, type) {
        const messages = document.getElementById('chat-messages');
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${type}-message fade-in`;
        
        const avatar = type === 'ai' ? '<i class="fas fa-robot"></i>' : '<i class="fas fa-user"></i>';
        
        messageDiv.innerHTML = `
            <div class="message-avatar">
                ${avatar}
            </div>
            <div class="message-content">
                <p>${content}</p>
            </div>
        `;
        
        messages.appendChild(messageDiv);
        messages.scrollTop = messages.scrollHeight;
    }

    simulateAIResponse(userMessage) {
        const responses = {
            'hello': 'Hello! I\'m your AI coding assistant. How can I help you with your code today?',
            'help': 'I can help you with HTML, CSS, and JavaScript. Try asking me to create components, fix bugs, or explain code concepts.',
            'create a button': 'Here\'s a simple button:\n\n```html\n<button onclick="handleClick()">Click Me</button>\n```\n\nAnd the JavaScript:\n\n```javascript\nfunction handleClick() {\n    alert("Button clicked!");\n}\n```',
            'default': 'I understand you want help with coding. Could you be more specific about what you\'d like me to help you with? I can assist with HTML structure, CSS styling, JavaScript functionality, or debugging.'
        };
        
        const lowerMessage = userMessage.toLowerCase();
        let response = responses.default;
        
        for (const [key, value] of Object.entries(responses)) {
            if (lowerMessage.includes(key)) {
                response = value;
                break;
            }
        }
        
        this.addChatMessage(response, 'ai');
    }

    showStatus(message, type = '') {
        const status = document.getElementById('status');
        status.textContent = message;
        
        if (type === 'loading') {
            status.parentElement.classList.add('loading');
        } else {
            status.parentElement.classList.remove('loading');
        }
        
        // Clear status after 3 seconds
        setTimeout(() => {
            if (status.textContent === message) {
                status.textContent = 'Ready';
                status.parentElement.classList.remove('loading');
            }
        }, 3000);
    }
}

// Initialize the editor when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.gooseCode = new GooseCodeEditor();
    
    // Add some welcome animations
    document.body.classList.add('fade-in');
    
    // Auto-focus the editor
    setTimeout(() => {
        document.getElementById('code-editor').focus();
    }, 500);
});

// Handle window resize
window.addEventListener('resize', () => {
    // Auto-collapse panels on small screens
    if (window.innerWidth < 768) {
        document.getElementById('sidebar').classList.add('collapsed');
        document.getElementById('preview-panel').classList.add('collapsed');
    }
});

// Prevent default drag and drop
document.addEventListener('dragover', (e) => e.preventDefault());
document.addEventListener('drop', (e) => e.preventDefault());
