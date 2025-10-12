// Enhanced Features for GooseCode
// Additional functionality to make the coding agent more powerful

class EnhancedGooseCode extends GooseCodeEditor {
    constructor() {
        super();
        this.setupEnhancedFeatures();
    }

    setupEnhancedFeatures() {
        this.setupSyntaxHighlighting();
        this.setupAutoComplete();
        this.setupRealTimeErrorChecking();
        this.setupAdvancedVimCommands();
        this.setupAIIntegration();
    }

    // Basic syntax highlighting
    setupSyntaxHighlighting() {
        const codeEditor = document.getElementById('codeEditor');
        
        codeEditor.addEventListener('input', () => {
            this.applySyntaxHighlighting();
        });
    }

    applySyntaxHighlighting() {
        // This would integrate with a proper syntax highlighter like Prism.js or CodeMirror
        // For now, we'll add CSS classes for basic highlighting
        const codeEditor = document.getElementById('codeEditor');
        const code = codeEditor.value;
        
        // Basic HTML tag highlighting (simplified)
        const highlightedCode = code
            .replace(/(&lt;\/?)(\w+)([^&gt;]*&gt;)/g, '<span class="html-tag">$1$2$3</span>')
            .replace(/(function|const|let|var|if|else|for|while)/g, '<span class="js-keyword">$1</span>');
        
        // In a real implementation, you'd use a proper syntax highlighter
        console.log('Syntax highlighting applied');
    }

    // Auto-completion suggestions
    setupAutoComplete() {
        const codeEditor = document.getElementById('codeEditor');
        
        codeEditor.addEventListener('keydown', (e) => {
            if (e.key === 'Tab') {
                e.preventDefault();
                this.handleAutoComplete();
            }
        });
    }

    handleAutoComplete() {
        const codeEditor = document.getElementById('codeEditor');
        const cursorPos = codeEditor.selectionStart;
        const textBeforeCursor = codeEditor.value.substring(0, cursorPos);
        
        // Simple auto-completion examples
        const completions = {
            'html': '<!DOCTYPE html>\n<html lang="en">\n<head>\n    <meta charset="UTF-8">\n    <meta name="viewport" content="width=device-width, initial-scale=1.0">\n    <title>Document</title>\n</head>\n<body>\n    \n</body>\n</html>',
            'canvas': '<canvas id="myCanvas" width="800" height="600"></canvas>\n<script>\nconst canvas = document.getElementById("myCanvas");\nconst ctx = canvas.getContext("2d");\n</script>',
            'func': 'function functionName() {\n    \n}',
            'log': 'console.log();'
        };

        // Check for completion triggers
        const words = textBeforeCursor.split(/\s+/);
        const lastWord = words[words.length - 1];
        
        if (completions[lastWord]) {
            const beforeLastWord = textBeforeCursor.substring(0, textBeforeCursor.lastIndexOf(lastWord));
            const afterCursor = codeEditor.value.substring(cursorPos);
            
            codeEditor.value = beforeLastWord + completions[lastWord] + afterCursor;
            this.updateLineNumbers();
        }
    }

    // Real-time error checking
    setupRealTimeErrorChecking() {
        const codeEditor = document.getElementById('codeEditor');
        
        codeEditor.addEventListener('input', () => {
            clearTimeout(this.errorCheckTimeout);
            this.errorCheckTimeout = setTimeout(() => {
                this.checkForErrors();
            }, 1000);
        });
    }

    checkForErrors() {
        const code = document.getElementById('codeEditor').value;
        const errors = [];
        
        // Basic HTML validation
        if (code.includes('<script>') && !code.includes('</script>')) {
            errors.push({ line: 0, message: 'Unclosed script tag' });
        }
        
        if (code.includes('<style>') && !code.includes('</style>')) {
            errors.push({ line: 0, message: 'Unclosed style tag' });
        }

        // Basic JavaScript validation
        try {
            // Simple check for common JS errors
            if (code.includes('function') && !code.match(/function\s+\w+\s*\(/)) {
                errors.push({ line: 0, message: 'Invalid function syntax' });
            }
        } catch (e) {
            errors.push({ line: 0, message: e.message });
        }

        this.displayErrors(errors);
    }

    displayErrors(errors) {
        const consoleOutput = document.getElementById('consoleOutput');
        
        // Clear previous errors
        const errorElements = consoleOutput.querySelectorAll('.error-line');
        errorElements.forEach(el => el.remove());
        
        // Display new errors
        errors.forEach(error => {
            const errorLine = document.createElement('div');
            errorLine.className = 'console-line error error-line';
            errorLine.textContent = `Error: ${error.message}`;
            consoleOutput.appendChild(errorLine);
        });
        
        if (errors.length > 0) {
            consoleOutput.scrollTop = consoleOutput.scrollHeight;
        }
    }

    // Advanced VIM commands
    setupAdvancedVimCommands() {
        // Extend the existing command system
        const originalExecuteCommand = this.executeCommand.bind(this);
        
        this.executeCommand = (command) => {
            const cmd = command.toLowerCase().trim();
            
            switch (cmd) {
                case 'theme dark':
                    this.setTheme('dark');
                    break;
                case 'theme light':
                    this.setTheme('light');
                    break;
                case 'zen':
                    this.toggleZenMode();
                    break;
                case 'focus':
                    this.toggleFocusMode();
                    break;
                case 'ai':
                    this.focusAIChat();
                    break;
                case 'template':
                    this.showTemplateSelector();
                    break;
                default:
                    originalExecuteCommand(command);
            }
        };
    }

    setTheme(theme) {
        const body = document.body;
        body.className = theme === 'light' ? 'light-theme' : '';
        this.addConsoleMessage(`Theme set to ${theme}`, 'info');
    }

    toggleZenMode() {
        const leftSidebar = document.getElementById('leftSidebar');
        const rightSidebar = document.getElementById('rightSidebar');
        const menuBar = document.querySelector('.menu-bar');
        const statusBar = document.querySelector('.status-bar');
        
        const isZen = leftSidebar.style.display === 'none';
        
        leftSidebar.style.display = isZen ? 'flex' : 'none';
        rightSidebar.style.display = isZen ? 'flex' : 'none';
        menuBar.style.display = isZen ? 'flex' : 'none';
        statusBar.style.display = isZen ? 'flex' : 'none';
        
        this.addConsoleMessage(`Zen mode ${isZen ? 'disabled' : 'enabled'}`, 'info');
    }

    toggleFocusMode() {
        const rightSidebar = document.getElementById('rightSidebar');
        const isFocus = rightSidebar.style.display === 'none';
        
        rightSidebar.style.display = isFocus ? 'flex' : 'none';
        this.addConsoleMessage(`Focus mode ${isFocus ? 'disabled' : 'enabled'}`, 'info');
    }

    focusAIChat() {
        const leftSidebar = document.getElementById('leftSidebar');
        this.switchTab('agent', leftSidebar);
        
        const chatInput = document.querySelector('.chat-input');
        chatInput.focus();
        
        this.addConsoleMessage('AI chat focused', 'info');
    }

    showTemplateSelector() {
        const templates = [
            'HTML5 Boilerplate',
            'React Component',
            'Vue Component',
            'Canvas Game',
            'Data Visualization',
            'Interactive Form',
            'CSS Animation',
            'WebGL Scene'
        ];
        
        const templateList = templates.map(t => `• ${t}`).join('\n');
        this.addConsoleMessage(`Available templates:\n${templateList}`, 'info');
    }

    // Enhanced AI Integration (ready for real API)
    setupAIIntegration() {
        this.aiContext = {
            currentCode: '',
            projectType: 'web',
            userPreferences: {},
            conversationHistory: []
        };
    }

    async sendToRealAI(message) {
        // This would connect to actual GPT-5 Code API
        const context = {
            message: message,
            currentCode: document.getElementById('codeEditor').value,
            fileType: this.getFileType(),
            projectContext: this.getProjectContext()
        };

        // Placeholder for real API call
        /*
        const response = await fetch('/api/ai/code', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(context)
        });
        
        const aiResponse = await response.json();
        return aiResponse.message;
        */
        
        // For now, return enhanced simulation
        return this.getEnhancedSimulatedResponse(message, context);
    }

    getEnhancedSimulatedResponse(message, context) {
        const lowerMessage = message.toLowerCase();
        
        if (lowerMessage.includes('canvas')) {
            return "I can help you create amazing Canvas applications! Here are some ideas:\n\n• Interactive animations\n• Data visualizations\n• Games (2D platformers, puzzles)\n• Drawing applications\n• Particle systems\n\nWhat type of Canvas project interests you?";
        }
        
        if (lowerMessage.includes('bug') || lowerMessage.includes('error')) {
            return "I'll help you debug! I can see your current code. Common issues I can help with:\n\n• Syntax errors\n• Logic problems\n• Performance optimization\n• Cross-browser compatibility\n\nCould you describe the specific issue you're experiencing?";
        }
        
        if (lowerMessage.includes('improve') || lowerMessage.includes('optimize')) {
            return "Great! I can suggest improvements for:\n\n• Code structure and organization\n• Performance optimizations\n• Accessibility enhancements\n• Modern JavaScript features\n• CSS best practices\n\nWhat aspect would you like to focus on?";
        }
        
        return "I'm here to help with your web development! I can assist with HTML, CSS, JavaScript, Canvas, and more. What would you like to work on?";
    }

    getFileType() {
        const fileName = this.currentFile;
        const extension = fileName.split('.').pop().toLowerCase();
        return extension;
    }

    getProjectContext() {
        return {
            files: Array.from(this.files.keys()),
            currentFile: this.currentFile,
            mode: this.currentMode,
            hasCanvas: document.getElementById('codeEditor').value.includes('canvas'),
            hasJavaScript: document.getElementById('codeEditor').value.includes('script'),
            lineCount: document.getElementById('codeEditor').value.split('\n').length
        };
    }

    // Enhanced file operations
    exportProject() {
        const projectData = {
            files: Object.fromEntries(this.files),
            settings: {
                theme: 'dark',
                mode: this.currentMode,
                currentFile: this.currentFile
            },
            timestamp: new Date().toISOString()
        };
        
        const dataStr = JSON.stringify(projectData, null, 2);
        const dataBlob = new Blob([dataStr], { type: 'application/json' });
        
        const link = document.createElement('a');
        link.href = URL.createObjectURL(dataBlob);
        link.download = 'goosecode-project.json';
        link.click();
        
        this.addConsoleMessage('Project exported successfully', 'info');
    }

    importProject(file) {
        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const projectData = JSON.parse(e.target.result);
                
                // Load files
                this.files.clear();
                Object.entries(projectData.files).forEach(([name, content]) => {
                    this.files.set(name, content);
                });
                
                // Load settings
                if (projectData.settings) {
                    this.currentFile = projectData.settings.currentFile;
                    this.switchMode(projectData.settings.mode);
                }
                
                // Update UI
                document.getElementById('codeEditor').value = this.files.get(this.currentFile) || '';
                this.updateLineNumbers();
                this.updatePreview();
                
                this.addConsoleMessage('Project imported successfully', 'info');
            } catch (error) {
                this.addConsoleMessage('Error importing project: ' + error.message, 'error');
            }
        };
        reader.readAsText(file);
    }
}

// Enhanced CSS for new features
const enhancedStyles = `
/* Light theme support */
.light-theme {
    --bg-primary: #ffffff;
    --bg-secondary: #f5f5f5;
    --bg-tertiary: #e0e0e0;
    --text-primary: #333333;
    --text-secondary: #666666;
    --border-color: #cccccc;
    --accent-color: #4CAF50;
}

.light-theme .app-container {
    background: var(--bg-primary);
    color: var(--text-primary);
}

.light-theme .menu-bar,
.light-theme .sidebar,
.light-theme .status-bar {
    background: var(--bg-secondary);
    border-color: var(--border-color);
}

.light-theme .code-editor {
    background: var(--bg-primary);
    color: var(--text-primary);
}

/* Syntax highlighting */
.html-tag {
    color: #e06c75;
}

.js-keyword {
    color: #c678dd;
}

.string {
    color: #98c379;
}

.comment {
    color: #5c6370;
    font-style: italic;
}

/* Enhanced error display */
.error-line {
    border-left: 3px solid #f44336;
    padding-left: 8px;
    margin: 2px 0;
}

/* Template selector */
.template-selector {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: #2d2d2d;
    border: 1px solid #404040;
    border-radius: 8px;
    padding: 20px;
    max-width: 400px;
    z-index: 1001;
}

.template-item {
    padding: 8px 12px;
    cursor: pointer;
    border-radius: 4px;
    margin: 4px 0;
    transition: background 0.2s;
}

.template-item:hover {
    background: #404040;
}

/* Focus mode adjustments */
.focus-mode .center-panel {
    margin: 0 20px;
}

/* Zen mode full screen */
.zen-mode .center-panel {
    margin: 0;
    border-radius: 0;
}

/* Animation for mode transitions */
.panel-transition {
    transition: all 0.3s ease-in-out;
}
`;

// Add enhanced styles to the page
const styleSheet = document.createElement('style');
styleSheet.textContent = enhancedStyles;
document.head.appendChild(styleSheet);

// Export for use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = EnhancedGooseCode;
}
