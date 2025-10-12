// GooseCode Editor - CodeMirror Integration
class GooseCodeEditor {
    constructor() {
        this.editor = null;
        this.currentFile = 'index.html';
        this.files = new Map();
        this.isVimMode = true;
        this.autoSave = true;
        this.autoSaveDelay = 2000;
        this.autoSaveTimer = null;
        
        this.init();
    }

    init() {
        this.setupEditor();
        this.setupFileSystem();
        this.setupEventListeners();
        this.loadInitialContent();
        
        console.log('📝 GooseCode Editor initialized');
    }

    setupEditor() {
        const textarea = document.getElementById('code-editor');
        if (!textarea) {
            console.error('Code editor textarea not found');
            return;
        }

        // CodeMirror configuration
        this.editor = CodeMirror.fromTextArea(textarea, {
            mode: 'htmlmixed',
            theme: 'monokai',
            lineNumbers: true,
            lineWrapping: false,
            indentUnit: 4,
            indentWithTabs: false,
            smartIndent: true,
            electricChars: true,
            autoCloseBrackets: true,
            autoCloseTags: true,
            matchBrackets: true,
            matchTags: true,
            showCursorWhenSelecting: true,
            styleActiveLine: true,
            foldGutter: true,
            gutters: ['CodeMirror-linenumbers', 'CodeMirror-foldgutter'],
            extraKeys: {
                'Ctrl-Space': 'autocomplete',
                'Ctrl-/': 'toggleComment',
                'Ctrl-D': 'selectNextOccurrence',
                'Ctrl-Shift-K': 'deleteLine',
                'Alt-Up': 'swapLineUp',
                'Alt-Down': 'swapLineDown',
                'Ctrl-F': 'findPersistent',
                'Ctrl-H': 'replace',
                'F3': 'findNext',
                'Shift-F3': 'findPrev',
                'Ctrl-G': 'jumpToLine',
                'Ctrl-S': (cm) => this.saveFile(),
                'Ctrl-O': (cm) => this.openFileDialog(),
                'Ctrl-N': (cm) => this.newFile(),
                'F5': (cm) => this.runCode(),
                'Ctrl-Enter': (cm) => this.runCode()
            }
        });

        // Enable VIM mode by default
        if (this.isVimMode) {
            this.enableVimMode();
        }

        // Setup editor event listeners
        this.editor.on('change', (cm, change) => {
            this.onContentChange(cm, change);
        });

        this.editor.on('cursorActivity', (cm) => {
            this.updateStatusBar(cm);
        });

        this.editor.on('vim-mode-change', (obj) => {
            this.onVimModeChange(obj);
        });

        // Focus the editor
        this.editor.focus();
    }

    setupFileSystem() {
        // Initialize with sample files
        this.files.set('index.html', {
            content: this.getDefaultHtmlContent(),
            mode: 'htmlmixed',
            modified: false,
            created: new Date(),
            lastModified: new Date()
        });

        this.files.set('style.css', {
            content: this.getDefaultCssContent(),
            mode: 'css',
            modified: false,
            created: new Date(),
            lastModified: new Date()
        });

        this.files.set('script.js', {
            content: this.getDefaultJsContent(),
            mode: 'javascript',
            modified: false,
            created: new Date(),
            lastModified: new Date()
        });
    }

    setupEventListeners() {
        // Listen for theme changes
        document.addEventListener('goosecode:themeChanged', (e) => {
            this.updateEditorTheme(e.detail.theme);
        });

        // Listen for tab switches
        document.addEventListener('goosecode:tabSwitched', (e) => {
            this.switchToFile(e.detail.filename);
        });

        // Listen for file operations
        document.addEventListener('goosecode:fileOpened', (e) => {
            this.openFile(e.detail.filename);
        });

        // Auto-save on window blur
        window.addEventListener('blur', () => {
            if (this.autoSave) {
                this.saveFile();
            }
        });

        // Prevent data loss on page unload
        window.addEventListener('beforeunload', (e) => {
            if (this.hasUnsavedChanges()) {
                e.preventDefault();
                e.returnValue = 'You have unsaved changes. Are you sure you want to leave?';
                return e.returnValue;
            }
        });
    }

    loadInitialContent() {
        const file = this.files.get(this.currentFile);
        if (file) {
            this.editor.setValue(file.content);
            this.editor.setOption('mode', file.mode);
            this.clearHistory();
        }
    }

    // VIM Mode Management
    enableVimMode() {
        this.editor.setOption('keyMap', 'vim');
        this.isVimMode = true;
        
        // Setup VIM command handlers
        CodeMirror.Vim.defineEx('write', 'w', () => {
            this.saveFile();
        });

        CodeMirror.Vim.defineEx('quit', 'q', () => {
            this.closeFile();
        });

        CodeMirror.Vim.defineEx('wq', 'wq', () => {
            this.saveFile();
            this.closeFile();
        });

        CodeMirror.Vim.defineEx('theme', 'theme', (cm, params) => {
            if (params.args && params.args[0]) {
                window.gooseCode?.setTheme(params.args[0]);
            }
        });

        CodeMirror.Vim.defineEx('run', 'run', () => {
            this.runCode();
        });

        console.log('🎯 VIM mode enabled');
    }

    disableVimMode() {
        this.editor.setOption('keyMap', 'default');
        this.isVimMode = false;
        console.log('📝 Normal mode enabled');
    }

    onVimModeChange(obj) {
        const mode = obj.mode;
        const subMode = obj.subMode;
        
        let displayMode = mode;
        if (subMode) {
            displayMode += ` (${subMode})`;
        }
        
        // Update the global mode indicator
        if (window.gooseCode) {
            window.gooseCode.setMode(mode);
        }
        
        // Update editor class for styling
        this.editor.getWrapperElement().className = 
            this.editor.getWrapperElement().className.replace(/vim-mode-\w+/g, '');
        this.editor.getWrapperElement().classList.add(`vim-mode-${mode}`);
    }

    // File Management
    newFile(filename = null) {
        if (!filename) {
            filename = `untitled-${Date.now()}.html`;
        }

        const content = filename.endsWith('.css') ? this.getDefaultCssContent() :
                       filename.endsWith('.js') ? this.getDefaultJsContent() :
                       this.getDefaultHtmlContent();

        const mode = this.getModeFromFilename(filename);

        this.files.set(filename, {
            content,
            mode,
            modified: false,
            created: new Date(),
            lastModified: new Date()
        });

        // Create tab if it doesn't exist
        if (!document.querySelector(`[data-file="${filename}"]`)) {
            window.gooseCode?.createNewTab();
        }

        this.switchToFile(filename);
        return filename;
    }

    openFile(filename) {
        if (this.files.has(filename)) {
            this.switchToFile(filename);
        } else {
            // Create new file if it doesn't exist
            this.newFile(filename);
        }
    }

    switchToFile(filename) {
        // Save current file state
        if (this.currentFile && this.files.has(this.currentFile)) {
            const currentFile = this.files.get(this.currentFile);
            currentFile.content = this.editor.getValue();
            currentFile.lastModified = new Date();
        }

        // Switch to new file
        const file = this.files.get(filename);
        if (file) {
            this.currentFile = filename;
            this.editor.setValue(file.content);
            this.editor.setOption('mode', file.mode);
            this.clearHistory();
            
            // Update syntax highlighting
            this.updateSyntaxHighlighting(file.mode);
            
            // Update status bar
            this.updateStatusBar();
            
            console.log(`📄 Switched to file: ${filename}`);
        }
    }

    saveFile(filename = null) {
        const targetFile = filename || this.currentFile;
        const file = this.files.get(targetFile);
        
        if (file) {
            file.content = this.editor.getValue();
            file.modified = false;
            file.lastModified = new Date();
            
            // Update tab indicator
            const tab = document.querySelector(`[data-file="${targetFile}"]`);
            if (tab) {
                const tabName = tab.querySelector('.tab-name');
                if (tabName) {
                    tabName.textContent = targetFile; // Remove * indicator
                }
            }
            
            // Update status bar
            this.updateStatusBar();
            
            // Trigger preview update if it's an HTML file
            if (targetFile.endsWith('.html') || targetFile === this.currentFile) {
                this.updatePreview();
            }
            
            console.log(`💾 Saved file: ${targetFile}`);
            return true;
        }
        
        return false;
    }

    closeFile(filename = null) {
        const targetFile = filename || this.currentFile;
        
        if (this.files.has(targetFile)) {
            const file = this.files.get(targetFile);
            
            if (file.modified) {
                const shouldSave = confirm(`Save changes to ${targetFile}?`);
                if (shouldSave) {
                    this.saveFile(targetFile);
                }
            }
            
            this.files.delete(targetFile);
            
            // If this was the current file, switch to another one
            if (targetFile === this.currentFile) {
                const remainingFiles = Array.from(this.files.keys());
                if (remainingFiles.length > 0) {
                    this.switchToFile(remainingFiles[0]);
                } else {
                    // Create a new file if no files remain
                    this.newFile();
                }
            }
            
            console.log(`🗑️ Closed file: ${targetFile}`);
        }
    }

    // Content Management
    onContentChange(cm, change) {
        // Mark file as modified
        const file = this.files.get(this.currentFile);
        if (file && !file.modified) {
            file.modified = true;
            
            // Update tab indicator
            const tab = document.querySelector(`[data-file="${this.currentFile}"]`);
            if (tab) {
                const tabName = tab.querySelector('.tab-name');
                if (tabName && !tabName.textContent.endsWith('*')) {
                    tabName.textContent += '*';
                }
            }
        }

        // Auto-save timer
        if (this.autoSave) {
            clearTimeout(this.autoSaveTimer);
            this.autoSaveTimer = setTimeout(() => {
                this.saveFile();
            }, this.autoSaveDelay);
        }

        // Update status bar
        this.updateStatusBar(cm);

        // Live preview for HTML files
        if (this.currentFile.endsWith('.html')) {
            clearTimeout(this.previewUpdateTimer);
            this.previewUpdateTimer = setTimeout(() => {
                this.updatePreview();
            }, 500);
        }
    }

    // Theme Management
    updateEditorTheme(theme) {
        const themeMap = {
            'dark': 'monokai',
            'light': 'default',
            'high-contrast': 'monokai',
            'monokai': 'monokai',
            'solarized-dark': 'solarized',
            'dracula': 'dracula'
        };

        const cmTheme = themeMap[theme] || 'monokai';
        this.editor.setOption('theme', cmTheme);
    }

    // Syntax Highlighting
    updateSyntaxHighlighting(mode) {
        this.editor.setOption('mode', mode);
        
        // Update status bar language indicator
        const statusBar = document.querySelector('.status-left');
        if (statusBar) {
            const langIndicator = statusBar.children[1];
            if (langIndicator) {
                const langMap = {
                    'htmlmixed': 'HTML',
                    'css': 'CSS',
                    'javascript': 'JS',
                    'json': 'JSON',
                    'markdown': 'MD'
                };
                langIndicator.textContent = langMap[mode] || mode.toUpperCase();
            }
        }
    }

    getModeFromFilename(filename) {
        const ext = filename.split('.').pop().toLowerCase();
        const modeMap = {
            'html': 'htmlmixed',
            'htm': 'htmlmixed',
            'css': 'css',
            'js': 'javascript',
            'json': 'application/json',
            'md': 'markdown',
            'txt': 'text/plain'
        };
        return modeMap[ext] || 'text/plain';
    }

    // Status Bar Updates
    updateStatusBar(cm = null) {
        const editor = cm || this.editor;
        const cursor = editor.getCursor();
        const selection = editor.getSelection();
        
        // Update cursor position
        const statusLeft = document.querySelector('.status-left');
        if (statusLeft) {
            const posIndicator = statusLeft.children[0];
            if (posIndicator) {
                if (selection) {
                    const selectionLength = selection.length;
                    posIndicator.textContent = `Line ${cursor.line + 1}, Col ${cursor.ch + 1} (${selectionLength} selected)`;
                } else {
                    posIndicator.textContent = `Line ${cursor.line + 1}, Col ${cursor.ch + 1}`;
                }
            }
        }

        // Update file status
        const statusCenter = document.querySelector('.status-center');
        if (statusCenter) {
            const fileStatus = statusCenter.children[0];
            if (fileStatus) {
                const file = this.files.get(this.currentFile);
                const status = file?.modified ? 'Modified' : 'Saved';
                fileStatus.textContent = `${this.currentFile} - ${status}`;
            }
        }
    }

    // Code Execution
    runCode() {
        this.saveFile(); // Save before running
        
        // Trigger preview update
        this.updatePreview();
        
        // Switch to preview panel
        const previewTab = document.querySelector('[data-panel="preview"]');
        if (previewTab) {
            previewTab.click();
        }
        
        console.log('▶️ Running code...');
    }

    updatePreview() {
        const previewFrame = document.getElementById('preview-frame');
        if (!previewFrame) return;

        const htmlFile = this.files.get('index.html') || this.files.get(this.currentFile);
        if (!htmlFile) return;

        let content = htmlFile.content;
        
        // Inject CSS if available
        const cssFile = this.files.get('style.css');
        if (cssFile) {
            content = content.replace(
                '</head>',
                `<style>${cssFile.content}</style></head>`
            );
        }
        
        // Inject JavaScript if available
        const jsFile = this.files.get('script.js');
        if (jsFile) {
            content = content.replace(
                '</body>',
                `<script>${jsFile.content}</script></body>`
            );
        }

        // Create blob URL for the content
        const blob = new Blob([content], { type: 'text/html' });
        const url = URL.createObjectURL(blob);
        
        previewFrame.src = url;
        
        // Clean up previous blob URL
        if (this.previousPreviewUrl) {
            URL.revokeObjectURL(this.previousPreviewUrl);
        }
        this.previousPreviewUrl = url;
    }

    // Utility Methods
    hasUnsavedChanges() {
        return Array.from(this.files.values()).some(file => file.modified);
    }

    clearHistory() {
        this.editor.clearHistory();
    }

    openFileDialog() {
        // This would typically open a file picker dialog
        console.log('File dialog would open here');
    }

    // Default Content Templates
    getDefaultHtmlContent() {
        return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My App</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            text-align: center;
        }
        canvas {
            border: 2px solid white;
            border-radius: 10px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to GooseCode!</h1>
        <p>This is a live preview of your HTML/CSS/JavaScript code.</p>
        <canvas id="myCanvas" width="400" height="300"></canvas>
        <script>
            const canvas = document.getElementById('myCanvas');
            const ctx = canvas.getContext('2d');
            
            // Draw a simple animation
            let angle = 0;
            function draw() {
                ctx.clearRect(0, 0, canvas.width, canvas.height);
                ctx.save();
                ctx.translate(canvas.width/2, canvas.height/2);
                ctx.rotate(angle);
                ctx.fillStyle = '#FFD700';
                ctx.fillRect(-50, -50, 100, 100);
                ctx.restore();
                angle += 0.02;
                requestAnimationFrame(draw);
            }
            draw();
        </script>
    </div>
</body>
</html>`;
    }

    getDefaultCssContent() {
        return `/* GooseCode Default Styles */
body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    margin: 0;
    padding: 20px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    min-height: 100vh;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

h1 {
    text-align: center;
    font-size: 2.5em;
    margin-bottom: 30px;
    text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
}

.card {
    background: rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(10px);
    border-radius: 15px;
    padding: 30px;
    margin: 20px 0;
    box-shadow: 0 8px 32px rgba(0,0,0,0.1);
    border: 1px solid rgba(255, 255, 255, 0.2);
}

button {
    background: linear-gradient(45deg, #FF6B6B, #4ECDC4);
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 25px;
    cursor: pointer;
    font-size: 16px;
    transition: transform 0.2s ease;
}

button:hover {
    transform: translateY(-2px);
}`;
    }

    getDefaultJsContent() {
        return `// GooseCode Default JavaScript
console.log('🪿 GooseCode is running!');

// Simple interactive example
document.addEventListener('DOMContentLoaded', function() {
    // Add click handlers to buttons
    const buttons = document.querySelectorAll('button');
    buttons.forEach(button => {
        button.addEventListener('click', function() {
            this.style.transform = 'scale(0.95)';
            setTimeout(() => {
                this.style.transform = '';
            }, 150);
        });
    });

    // Simple animation example
    function createParticle() {
        const particle = document.createElement('div');
        particle.style.cssText = \`
            position: fixed;
            width: 6px;
            height: 6px;
            background: #FFD700;
            border-radius: 50%;
            pointer-events: none;
            z-index: 1000;
            left: \${Math.random() * window.innerWidth}px;
            top: -10px;
            opacity: 0.8;
        \`;
        
        document.body.appendChild(particle);
        
        const animation = particle.animate([
            { transform: 'translateY(0px)', opacity: 0.8 },
            { transform: \`translateY(\${window.innerHeight + 20}px)\`, opacity: 0 }
        ], {
            duration: 3000 + Math.random() * 2000,
            easing: 'linear'
        });
        
        animation.onfinish = () => particle.remove();
    }

    // Create particles occasionally
    setInterval(createParticle, 2000);
});`;
    }
}

// Initialize editor when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.gooseCodeEditor = new GooseCodeEditor();
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = GooseCodeEditor;
}
