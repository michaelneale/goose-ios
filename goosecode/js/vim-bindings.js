// GooseCode VIM Bindings - Enhanced VIM functionality
class GooseCodeVim {
    constructor() {
        this.isEnabled = true;
        this.currentMode = 'normal';
        this.commandHistory = [];
        this.searchHistory = [];
        this.registers = new Map();
        
        this.init();
    }

    init() {
        this.setupVimCommands();
        this.setupVimMaps();
        this.setupEventListeners();
        
        console.log('🎯 VIM bindings initialized');
    }

    setupVimCommands() {
        if (!window.CodeMirror || !CodeMirror.Vim) return;

        // File operations
        CodeMirror.Vim.defineEx('w', 'write', (cm, params) => {
            if (params.args && params.args[0]) {
                // Save as
                window.gooseCodeEditor?.saveFile(params.args[0]);
            } else {
                // Save current file
                window.gooseCodeEditor?.saveFile();
            }
        });

        CodeMirror.Vim.defineEx('q', 'quit', (cm) => {
            window.gooseCodeEditor?.closeFile();
        });

        CodeMirror.Vim.defineEx('wq', 'wq', (cm) => {
            window.gooseCodeEditor?.saveFile();
            window.gooseCodeEditor?.closeFile();
        });

        CodeMirror.Vim.defineEx('qa', 'quitall', (cm) => {
            if (confirm('Close all files?')) {
                // Close all files
                const editor = window.gooseCodeEditor;
                if (editor) {
                    Array.from(editor.files.keys()).forEach(filename => {
                        editor.closeFile(filename);
                    });
                }
            }
        });

        // Navigation
        CodeMirror.Vim.defineEx('e', 'edit', (cm, params) => {
            if (params.args && params.args[0]) {
                window.gooseCodeEditor?.openFile(params.args[0]);
            } else {
                // Show file picker
                this.showFilePicker();
            }
        });

        CodeMirror.Vim.defineEx('n', 'new', (cm, params) => {
            const filename = params.args && params.args[0] ? params.args[0] : null;
            window.gooseCodeEditor?.newFile(filename);
        });

        // Theme and appearance
        CodeMirror.Vim.defineEx('theme', 'theme', (cm, params) => {
            if (params.args && params.args[0]) {
                window.gooseCode?.setTheme(params.args[0]);
            } else {
                this.showThemeList();
            }
        });

        CodeMirror.Vim.defineEx('colorscheme', 'colorscheme', (cm, params) => {
            if (params.args && params.args[0]) {
                window.gooseCode?.setTheme(params.args[0]);
            }
        });

        // Panel management
        CodeMirror.Vim.defineEx('split', 'split', (cm) => {
            window.gooseCode?.togglePanel('preview');
        });

        CodeMirror.Vim.defineEx('vsplit', 'vsplit', (cm) => {
            window.gooseCode?.togglePanel('explorer');
        });

        CodeMirror.Vim.defineEx('terminal', 'terminal', (cm) => {
            window.gooseCode?.togglePanel('terminal');
        });

        CodeMirror.Vim.defineEx('term', 'term', (cm) => {
            window.gooseCode?.togglePanel('terminal');
        });

        // Code execution
        CodeMirror.Vim.defineEx('run', 'run', (cm) => {
            window.gooseCodeEditor?.runCode();
        });

        CodeMirror.Vim.defineEx('preview', 'preview', (cm) => {
            window.gooseCodePreview?.refreshPreview();
        });

        // Search and replace
        CodeMirror.Vim.defineEx('grep', 'grep', (cm, params) => {
            if (params.args && params.args[0]) {
                this.searchInFiles(params.args[0]);
            }
        });

        // Settings
        CodeMirror.Vim.defineEx('set', 'set', (cm, params) => {
            if (params.args && params.args[0]) {
                this.handleSetCommand(params.args[0]);
            }
        });

        // Help
        CodeMirror.Vim.defineEx('help', 'help', (cm, params) => {
            this.showHelp(params.args ? params.args[0] : null);
        });

        // AI Chat
        CodeMirror.Vim.defineEx('ai', 'ai', (cm, params) => {
            window.gooseCode?.switchPanel('aiChat');
            if (params.args && params.args.length > 0) {
                const message = params.args.join(' ');
                window.gooseCodeAI?.sendMessage(message);
            }
        });
    }

    setupVimMaps() {
        if (!window.CodeMirror || !CodeMirror.Vim) return;

        // Custom key mappings
        CodeMirror.Vim.map('<C-s>', ':w<CR>', 'normal');
        CodeMirror.Vim.map('<C-s>', '<Esc>:w<CR>', 'insert');
        
        CodeMirror.Vim.map('<leader>w', ':w<CR>', 'normal');
        CodeMirror.Vim.map('<leader>q', ':q<CR>', 'normal');
        CodeMirror.Vim.map('<leader>x', ':wq<CR>', 'normal');
        
        CodeMirror.Vim.map('<leader>n', ':new<CR>', 'normal');
        CodeMirror.Vim.map('<leader>e', ':e<CR>', 'normal');
        
        CodeMirror.Vim.map('<leader>r', ':run<CR>', 'normal');
        CodeMirror.Vim.map('<F5>', ':run<CR>', 'normal');
        
        CodeMirror.Vim.map('<leader>t', ':terminal<CR>', 'normal');
        CodeMirror.Vim.map('<leader>p', ':split<CR>', 'normal');
        CodeMirror.Vim.map('<leader>v', ':vsplit<CR>', 'normal');
        
        CodeMirror.Vim.map('<leader>ai', ':ai<CR>', 'normal');
        
        // Window navigation
        CodeMirror.Vim.map('<C-h>', '<C-w>h', 'normal');
        CodeMirror.Vim.map('<C-j>', '<C-w>j', 'normal');
        CodeMirror.Vim.map('<C-k>', '<C-w>k', 'normal');
        CodeMirror.Vim.map('<C-l>', '<C-w>l', 'normal');
        
        // Tab navigation
        CodeMirror.Vim.map('gt', ':tabnext<CR>', 'normal');
        CodeMirror.Vim.map('gT', ':tabprev<CR>', 'normal');
        CodeMirror.Vim.map('<leader>1', ':tab1<CR>', 'normal');
        CodeMirror.Vim.map('<leader>2', ':tab2<CR>', 'normal');
        CodeMirror.Vim.map('<leader>3', ':tab3<CR>', 'normal');
        
        // Quick actions
        CodeMirror.Vim.map('<leader>/', ':grep ', 'normal');
        CodeMirror.Vim.map('<leader>h', ':help<CR>', 'normal');
        CodeMirror.Vim.map('<leader>th', ':theme ', 'normal');
    }

    setupEventListeners() {
        // Listen for VIM mode changes
        document.addEventListener('goosecode:modeChanged', (e) => {
            this.currentMode = e.detail.mode;
            this.updateModeIndicator();
        });

        // Custom key handlers for special functionality
        document.addEventListener('keydown', (e) => {
            if (this.isEnabled && this.handleCustomKeys(e)) {
                e.preventDefault();
            }
        });
    }

    handleCustomKeys(e) {
        // Handle special key combinations that aren't covered by VIM mappings
        if (e.ctrlKey || e.metaKey) {
            switch (e.key) {
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                case '7':
                case '8':
                case '9':
                    this.switchToTab(parseInt(e.key) - 1);
                    return true;
                case '0':
                    this.switchToLastTab();
                    return true;
            }
        }
        
        return false;
    }

    // Command handlers
    handleSetCommand(option) {
        const [key, value] = option.split('=');
        
        switch (key) {
            case 'number':
            case 'nu':
                this.toggleLineNumbers(value !== '0' && value !== 'false');
                break;
            case 'wrap':
                this.toggleLineWrap(value !== '0' && value !== 'false');
                break;
            case 'theme':
                if (value) window.gooseCode?.setTheme(value);
                break;
            case 'autoindent':
            case 'ai':
                this.toggleAutoIndent(value !== '0' && value !== 'false');
                break;
            case 'tabstop':
            case 'ts':
                this.setTabSize(parseInt(value) || 4);
                break;
            case 'expandtab':
            case 'et':
                this.setExpandTab(value !== '0' && value !== 'false');
                break;
            default:
                console.log(`Unknown option: ${option}`);
        }
    }

    // File operations
    showFilePicker() {
        const editor = window.gooseCodeEditor;
        if (!editor) return;

        const files = Array.from(editor.files.keys());
        if (files.length === 0) return;

        // Create a simple file picker modal
        const modal = this.createModal('Select File', files.map(file => ({
            label: file,
            action: () => editor.openFile(file)
        })));
        
        document.body.appendChild(modal);
    }

    showThemeList() {
        const themes = [
            'dark', 'light', 'high-contrast', 
            'monokai', 'solarized-dark', 'dracula'
        ];
        
        const modal = this.createModal('Select Theme', themes.map(theme => ({
            label: theme,
            action: () => window.gooseCode?.setTheme(theme)
        })));
        
        document.body.appendChild(modal);
    }

    searchInFiles(pattern) {
        const editor = window.gooseCodeEditor;
        if (!editor) return;

        const results = [];
        editor.files.forEach((file, filename) => {
            const lines = file.content.split('\n');
            lines.forEach((line, lineNum) => {
                if (line.includes(pattern)) {
                    results.push({
                        file: filename,
                        line: lineNum + 1,
                        content: line.trim()
                    });
                }
            });
        });

        this.showSearchResults(pattern, results);
    }

    showSearchResults(pattern, results) {
        const modal = this.createModal(`Search Results for "${pattern}"`, 
            results.map(result => ({
                label: `${result.file}:${result.line} - ${result.content}`,
                action: () => {
                    window.gooseCodeEditor?.openFile(result.file);
                    // TODO: Jump to line
                }
            }))
        );
        
        document.body.appendChild(modal);
    }

    // Tab management
    switchToTab(index) {
        const tabs = document.querySelectorAll('.tab');
        if (tabs[index]) {
            const filename = tabs[index].dataset.file;
            window.gooseCodeEditor?.switchToFile(filename);
        }
    }

    switchToLastTab() {
        const tabs = document.querySelectorAll('.tab');
        if (tabs.length > 0) {
            const lastTab = tabs[tabs.length - 1];
            const filename = lastTab.dataset.file;
            window.gooseCodeEditor?.switchToFile(filename);
        }
    }

    // Editor settings
    toggleLineNumbers(show) {
        const editor = window.gooseCodeEditor?.editor;
        if (editor) {
            editor.setOption('lineNumbers', show);
        }
    }

    toggleLineWrap(wrap) {
        const editor = window.gooseCodeEditor?.editor;
        if (editor) {
            editor.setOption('lineWrapping', wrap);
        }
    }

    toggleAutoIndent(enable) {
        const editor = window.gooseCodeEditor?.editor;
        if (editor) {
            editor.setOption('smartIndent', enable);
        }
    }

    setTabSize(size) {
        const editor = window.gooseCodeEditor?.editor;
        if (editor) {
            editor.setOption('indentUnit', size);
            editor.setOption('tabSize', size);
        }
    }

    setExpandTab(expand) {
        const editor = window.gooseCodeEditor?.editor;
        if (editor) {
            editor.setOption('indentWithTabs', !expand);
        }
    }

    // UI helpers
    updateModeIndicator() {
        const modeDisplay = document.getElementById('mode-display');
        if (modeDisplay) {
            modeDisplay.textContent = this.currentMode.toUpperCase();
        }
    }

    createModal(title, options) {
        const modal = document.createElement('div');
        modal.className = 'vim-modal';
        modal.innerHTML = `
            <div class="vim-modal-content">
                <div class="vim-modal-header">
                    <h3>${title}</h3>
                    <button class="vim-modal-close">×</button>
                </div>
                <div class="vim-modal-body">
                    ${options.map((option, index) => 
                        `<div class="vim-modal-option" data-index="${index}">${option.label}</div>`
                    ).join('')}
                </div>
            </div>
        `;

        // Add event listeners
        modal.querySelector('.vim-modal-close').addEventListener('click', () => {
            modal.remove();
        });

        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.remove();
            }
        });

        modal.querySelectorAll('.vim-modal-option').forEach((option, index) => {
            option.addEventListener('click', () => {
                options[index].action();
                modal.remove();
            });
        });

        // Keyboard navigation
        let selectedIndex = 0;
        const updateSelection = () => {
            modal.querySelectorAll('.vim-modal-option').forEach((option, index) => {
                option.classList.toggle('selected', index === selectedIndex);
            });
        };

        modal.addEventListener('keydown', (e) => {
            switch (e.key) {
                case 'ArrowDown':
                case 'j':
                    selectedIndex = Math.min(selectedIndex + 1, options.length - 1);
                    updateSelection();
                    e.preventDefault();
                    break;
                case 'ArrowUp':
                case 'k':
                    selectedIndex = Math.max(selectedIndex - 1, 0);
                    updateSelection();
                    e.preventDefault();
                    break;
                case 'Enter':
                    options[selectedIndex].action();
                    modal.remove();
                    e.preventDefault();
                    break;
                case 'Escape':
                    modal.remove();
                    e.preventDefault();
                    break;
            }
        });

        updateSelection();
        modal.tabIndex = -1;
        setTimeout(() => modal.focus(), 0);

        return modal;
    }

    showHelp(topic = null) {
        const helpContent = this.getHelpContent(topic);
        const modal = document.createElement('div');
        modal.className = 'vim-help-modal';
        modal.innerHTML = `
            <div class="vim-help-content">
                <div class="vim-help-header">
                    <h3>GooseCode VIM Help${topic ? ` - ${topic}` : ''}</h3>
                    <button class="vim-help-close">×</button>
                </div>
                <div class="vim-help-body">
                    ${helpContent}
                </div>
            </div>
        `;

        modal.querySelector('.vim-help-close').addEventListener('click', () => {
            modal.remove();
        });

        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.remove();
            }
        });

        document.body.appendChild(modal);
    }

    getHelpContent(topic) {
        const help = {
            commands: `
                <h4>File Commands</h4>
                <ul>
                    <li><code>:w</code> - Save current file</li>
                    <li><code>:q</code> - Close current file</li>
                    <li><code>:wq</code> - Save and close</li>
                    <li><code>:e filename</code> - Open file</li>
                    <li><code>:n filename</code> - Create new file</li>
                </ul>
                <h4>Code Commands</h4>
                <ul>
                    <li><code>:run</code> - Execute code</li>
                    <li><code>:preview</code> - Refresh preview</li>
                </ul>
                <h4>Panel Commands</h4>
                <ul>
                    <li><code>:split</code> - Toggle preview panel</li>
                    <li><code>:vsplit</code> - Toggle explorer panel</li>
                    <li><code>:terminal</code> - Toggle terminal</li>
                    <li><code>:ai</code> - Open AI chat</li>
                </ul>
            `,
            mappings: `
                <h4>Leader Key Mappings (Space)</h4>
                <ul>
                    <li><code>&lt;leader&gt;w</code> - Save file</li>
                    <li><code>&lt;leader&gt;q</code> - Close file</li>
                    <li><code>&lt;leader&gt;r</code> - Run code</li>
                    <li><code>&lt;leader&gt;t</code> - Toggle terminal</li>
                    <li><code>&lt;leader&gt;p</code> - Toggle preview</li>
                    <li><code>&lt;leader&gt;ai</code> - AI chat</li>
                </ul>
                <h4>Tab Navigation</h4>
                <ul>
                    <li><code>gt</code> - Next tab</li>
                    <li><code>gT</code> - Previous tab</li>
                    <li><code>Ctrl+1-9</code> - Switch to tab by number</li>
                </ul>
            `
        };

        if (topic && help[topic]) {
            return help[topic];
        }

        return `
            <div class="help-overview">
                <p>Welcome to GooseCode VIM mode! Here are the available help topics:</p>
                <ul>
                    <li><a href="#" onclick="window.gooseCodeVim.showHelp('commands')">:help commands</a> - File and code commands</li>
                    <li><a href="#" onclick="window.gooseCodeVim.showHelp('mappings')">:help mappings</a> - Key mappings</li>
                </ul>
                <p>Use <code>:help &lt;topic&gt;</code> for specific help.</p>
            </div>
            ${help.commands}
            ${help.mappings}
        `;
    }

    // Enable/disable VIM mode
    enable() {
        this.isEnabled = true;
        const editor = window.gooseCodeEditor?.editor;
        if (editor) {
            editor.setOption('keyMap', 'vim');
        }
        console.log('🎯 VIM mode enabled');
    }

    disable() {
        this.isEnabled = false;
        const editor = window.gooseCodeEditor?.editor;
        if (editor) {
            editor.setOption('keyMap', 'default');
        }
        console.log('📝 VIM mode disabled');
    }
}

// Initialize VIM bindings when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Wait for CodeMirror to be available
    const initVim = () => {
        if (window.CodeMirror && CodeMirror.Vim) {
            window.gooseCodeVim = new GooseCodeVim();
        } else {
            setTimeout(initVim, 100);
        }
    };
    
    setTimeout(initVim, 500); // Give CodeMirror time to load
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = GooseCodeVim;
}
