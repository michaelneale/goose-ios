// GooseCode - Main Application Controller
class GooseCode {
    constructor() {
        this.currentTheme = 'dark';
        this.currentMode = 'normal';
        this.isVimMode = true;
        this.panels = {
            explorer: true,
            preview: true,
            terminal: false,
            aiChat: false
        };
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.setupKeyboardShortcuts();
        this.setupThemeSystem();
        this.setupLayout();
        this.loadSettings();
        
        console.log('🪿 GooseCode initialized successfully!');
    }

    setupEventListeners() {
        // Theme toggle
        const themeToggle = document.getElementById('theme-toggle');
        themeToggle?.addEventListener('click', () => this.toggleTheme());

        // Layout toggle
        const layoutToggle = document.getElementById('layout-toggle');
        layoutToggle?.addEventListener('click', () => this.toggleLayout());

        // Panel tabs
        document.querySelectorAll('.panel-tab').forEach(tab => {
            tab.addEventListener('click', (e) => {
                const panel = e.target.dataset.panel;
                this.switchPanel(panel);
            });
        });

        // File tree items
        document.querySelectorAll('.file-item').forEach(item => {
            item.addEventListener('click', (e) => {
                e.stopPropagation();
                if (item.classList.contains('folder')) {
                    this.toggleFolder(item);
                } else {
                    this.openFile(item.querySelector('.file-name').textContent);
                }
            });
        });

        // Tab management
        document.querySelectorAll('.tab').forEach(tab => {
            tab.addEventListener('click', (e) => {
                if (!e.target.classList.contains('tab-close')) {
                    this.switchTab(tab.dataset.file);
                }
            });
        });

        document.querySelectorAll('.tab-close').forEach(closeBtn => {
            closeBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                const tab = e.target.closest('.tab');
                this.closeTab(tab.dataset.file);
            });
        });

        // New tab button
        const newTabBtn = document.querySelector('.new-tab');
        newTabBtn?.addEventListener('click', () => this.createNewTab());

        // Command palette
        const commandInput = document.getElementById('command-input');
        commandInput?.addEventListener('keydown', (e) => this.handleCommand(e));
        commandInput?.addEventListener('focus', () => this.showCommandPalette());
        commandInput?.addEventListener('blur', () => this.hideCommandPalette());

        // Window resize
        window.addEventListener('resize', () => this.handleResize());

        // Prevent context menu on right-click (for VIM-like experience)
        document.addEventListener('contextmenu', (e) => {
            if (this.isVimMode) {
                e.preventDefault();
            }
        });
    }

    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Global shortcuts
            if (e.ctrlKey || e.metaKey) {
                switch (e.key) {
                    case '`':
                        e.preventDefault();
                        this.togglePanel('terminal');
                        break;
                    case 'b':
                        e.preventDefault();
                        this.togglePanel('explorer');
                        break;
                    case 'j':
                        e.preventDefault();
                        this.togglePanel('preview');
                        break;
                    case 'k':
                        e.preventDefault();
                        this.togglePanel('aiChat');
                        break;
                    case 'p':
                        if (e.shiftKey) {
                            e.preventDefault();
                            this.showCommandPalette();
                        }
                        break;
                    case 't':
                        e.preventDefault();
                        this.createNewTab();
                        break;
                    case 'w':
                        e.preventDefault();
                        this.closeCurrentTab();
                        break;
                    case ',':
                        e.preventDefault();
                        this.showSettings();
                        break;
                }
            }

            // VIM-style shortcuts
            if (this.isVimMode && !e.ctrlKey && !e.metaKey) {
                switch (e.key) {
                    case 'Escape':
                        this.setMode('normal');
                        break;
                }
            }

            // Function keys
            switch (e.key) {
                case 'F1':
                    e.preventDefault();
                    this.showHelp();
                    break;
                case 'F5':
                    e.preventDefault();
                    this.runCode();
                    break;
                case 'F11':
                    e.preventDefault();
                    this.toggleFullscreen();
                    break;
            }
        });
    }

    setupThemeSystem() {
        const themes = ['dark', 'light', 'high-contrast', 'monokai', 'solarized-dark', 'dracula'];
        this.availableThemes = themes;
        
        // Load saved theme
        const savedTheme = localStorage.getItem('goosecode-theme') || 'dark';
        this.setTheme(savedTheme);
    }

    setupLayout() {
        // Initialize panel states
        this.updatePanelVisibility();
        
        // Setup resizable panels
        this.setupResizablePanels();
        
        // Initialize responsive behavior
        this.handleResize();
    }

    setupResizablePanels() {
        // Add resize handles between panels
        const sidePanel = document.getElementById('side-panel');
        const rightPanel = document.getElementById('right-panel');
        
        if (sidePanel) {
            this.makeResizable(sidePanel, 'right', 200, 400);
        }
        
        if (rightPanel) {
            this.makeResizable(rightPanel, 'left', 300, 600);
        }
    }

    makeResizable(element, direction, minWidth, maxWidth) {
        const resizer = document.createElement('div');
        resizer.className = `resizer resizer-${direction}`;
        resizer.style.cssText = `
            position: absolute;
            ${direction}: -2px;
            top: 0;
            bottom: 0;
            width: 4px;
            cursor: col-resize;
            background: transparent;
            z-index: 10;
        `;
        
        element.style.position = 'relative';
        element.appendChild(resizer);
        
        let isResizing = false;
        let startX = 0;
        let startWidth = 0;
        
        resizer.addEventListener('mousedown', (e) => {
            isResizing = true;
            startX = e.clientX;
            startWidth = element.offsetWidth;
            document.body.style.cursor = 'col-resize';
            document.body.style.userSelect = 'none';
        });
        
        document.addEventListener('mousemove', (e) => {
            if (!isResizing) return;
            
            const diff = direction === 'right' ? e.clientX - startX : startX - e.clientX;
            const newWidth = Math.max(minWidth, Math.min(maxWidth, startWidth + diff));
            element.style.width = newWidth + 'px';
        });
        
        document.addEventListener('mouseup', () => {
            if (isResizing) {
                isResizing = false;
                document.body.style.cursor = '';
                document.body.style.userSelect = '';
            }
        });
    }

    // Theme Management
    toggleTheme() {
        const currentIndex = this.availableThemes.indexOf(this.currentTheme);
        const nextIndex = (currentIndex + 1) % this.availableThemes.length;
        this.setTheme(this.availableThemes[nextIndex]);
    }

    setTheme(theme) {
        if (!this.availableThemes.includes(theme)) return;
        
        document.body.className = document.body.className.replace(/theme-\w+/g, '');
        document.body.classList.add(`theme-${theme}`);
        
        this.currentTheme = theme;
        localStorage.setItem('goosecode-theme', theme);
        
        // Update theme toggle icon
        const themeToggle = document.getElementById('theme-toggle');
        if (themeToggle) {
            const icons = {
                'dark': '🌙',
                'light': '☀️',
                'high-contrast': '🔆',
                'monokai': '🎨',
                'solarized-dark': '🌅',
                'dracula': '🧛'
            };
            themeToggle.textContent = icons[theme] || '🌙';
        }
        
        this.emit('themeChanged', { theme });
    }

    // Mode Management
    setMode(mode) {
        const validModes = ['normal', 'insert', 'visual', 'command'];
        if (!validModes.includes(mode)) return;
        
        document.body.className = document.body.className.replace(/\w+-mode/g, '');
        document.body.classList.add(`${mode}-mode`);
        
        this.currentMode = mode;
        
        const modeDisplay = document.getElementById('mode-display');
        if (modeDisplay) {
            modeDisplay.textContent = mode.toUpperCase();
        }
        
        this.emit('modeChanged', { mode });
    }

    // Panel Management
    togglePanel(panelName) {
        this.panels[panelName] = !this.panels[panelName];
        this.updatePanelVisibility();
        this.saveSettings();
    }

    switchPanel(panelName) {
        // Deactivate all panels in the right panel
        document.querySelectorAll('.panel-tab').forEach(tab => {
            tab.classList.remove('active');
        });
        document.querySelectorAll('.panel-content').forEach(content => {
            content.classList.remove('active');
        });
        
        // Activate selected panel
        const tab = document.querySelector(`[data-panel="${panelName}"]`);
        const content = document.getElementById(`${panelName}-panel`);
        
        if (tab) tab.classList.add('active');
        if (content) content.classList.add('active');
        
        this.emit('panelSwitched', { panel: panelName });
    }

    updatePanelVisibility() {
        const sidePanel = document.getElementById('side-panel');
        const rightPanel = document.getElementById('right-panel');
        
        if (sidePanel) {
            sidePanel.style.display = this.panels.explorer ? 'flex' : 'none';
        }
        
        if (rightPanel) {
            const hasActivePanel = this.panels.preview || this.panels.terminal || this.panels.aiChat;
            rightPanel.style.display = hasActivePanel ? 'flex' : 'none';
        }
    }

    // Layout Management
    toggleLayout() {
        document.body.classList.toggle('compact-layout');
        this.handleResize();
    }

    handleResize() {
        const width = window.innerWidth;
        
        // Mobile responsiveness
        if (width < 768) {
            document.body.classList.add('mobile-layout');
            this.panels.explorer = false;
            this.panels.preview = false;
        } else {
            document.body.classList.remove('mobile-layout');
        }
        
        this.updatePanelVisibility();
        this.emit('resize', { width, height: window.innerHeight });
    }

    // File Management
    openFile(filename) {
        // Remove selection from all file items
        document.querySelectorAll('.file-item').forEach(item => {
            item.classList.remove('selected');
        });
        
        // Select clicked file
        const fileItem = Array.from(document.querySelectorAll('.file-item'))
            .find(item => item.querySelector('.file-name')?.textContent === filename);
        
        if (fileItem) {
            fileItem.classList.add('selected');
        }
        
        // Switch to or create tab
        this.switchTab(filename);
        
        this.emit('fileOpened', { filename });
    }

    toggleFolder(folderElement) {
        folderElement.classList.toggle('expanded');
    }

    // Tab Management
    switchTab(filename) {
        // Deactivate all tabs
        document.querySelectorAll('.tab').forEach(tab => {
            tab.classList.remove('active');
        });
        
        // Activate selected tab
        const tab = document.querySelector(`[data-file="${filename}"]`);
        if (tab) {
            tab.classList.add('active');
            
            // Update status bar
            const fileStatus = document.getElementById('file-status');
            if (fileStatus) {
                fileStatus.textContent = `${filename} - Ready`;
            }
        }
        
        this.emit('tabSwitched', { filename });
    }

    closeTab(filename) {
        const tab = document.querySelector(`[data-file="${filename}"]`);
        if (tab) {
            // If this was the active tab, switch to another one
            if (tab.classList.contains('active')) {
                const nextTab = tab.nextElementSibling || tab.previousElementSibling;
                if (nextTab && nextTab.classList.contains('tab')) {
                    this.switchTab(nextTab.dataset.file);
                }
            }
            
            tab.remove();
        }
        
        this.emit('tabClosed', { filename });
    }

    closeCurrentTab() {
        const activeTab = document.querySelector('.tab.active');
        if (activeTab) {
            this.closeTab(activeTab.dataset.file);
        }
    }

    createNewTab() {
        const tabBar = document.getElementById('tab-bar');
        const newTabBtn = tabBar.querySelector('.new-tab');
        
        const filename = `untitled-${Date.now()}.html`;
        
        const tab = document.createElement('div');
        tab.className = 'tab';
        tab.dataset.file = filename;
        tab.innerHTML = `
            <span class="tab-name">${filename}</span>
            <button class="tab-close">×</button>
        `;
        
        // Insert before the new tab button
        tabBar.insertBefore(tab, newTabBtn);
        
        // Add event listeners
        tab.addEventListener('click', (e) => {
            if (!e.target.classList.contains('tab-close')) {
                this.switchTab(filename);
            }
        });
        
        tab.querySelector('.tab-close').addEventListener('click', (e) => {
            e.stopPropagation();
            this.closeTab(filename);
        });
        
        // Switch to new tab
        this.switchTab(filename);
        
        this.emit('tabCreated', { filename });
    }

    // Command Palette
    showCommandPalette() {
        const commandPalette = document.getElementById('command-palette');
        const commandInput = document.getElementById('command-input');
        
        if (commandPalette) {
            commandPalette.classList.add('active');
        }
        
        if (commandInput) {
            commandInput.focus();
            commandInput.select();
        }
    }

    hideCommandPalette() {
        const commandPalette = document.getElementById('command-palette');
        if (commandPalette) {
            commandPalette.classList.remove('active');
        }
    }

    handleCommand(e) {
        if (e.key === 'Enter') {
            const command = e.target.value.trim();
            this.executeCommand(command);
            e.target.value = '';
            this.hideCommandPalette();
        } else if (e.key === 'Escape') {
            this.hideCommandPalette();
        }
    }

    executeCommand(command) {
        const [cmd, ...args] = command.split(' ');
        
        switch (cmd) {
            case ':q':
            case ':quit':
                this.closeCurrentTab();
                break;
            case ':w':
            case ':write':
                this.saveCurrentFile();
                break;
            case ':wq':
                this.saveCurrentFile();
                this.closeCurrentTab();
                break;
            case ':theme':
                if (args[0]) this.setTheme(args[0]);
                break;
            case ':new':
                this.createNewTab();
                break;
            case ':run':
                this.runCode();
                break;
            case ':help':
                this.showHelp();
                break;
            default:
                console.log(`Unknown command: ${command}`);
        }
        
        this.emit('commandExecuted', { command, args });
    }

    // Code Execution
    runCode() {
        const runButton = document.getElementById('run-code');
        if (runButton) {
            runButton.click();
        }
    }

    saveCurrentFile() {
        // This would typically save to a backend or local storage
        const fileStatus = document.getElementById('file-status');
        if (fileStatus) {
            fileStatus.textContent = fileStatus.textContent.replace('Modified', 'Saved');
        }
        
        this.emit('fileSaved');
    }

    // Settings Management
    loadSettings() {
        const settings = localStorage.getItem('goosecode-settings');
        if (settings) {
            const parsed = JSON.parse(settings);
            Object.assign(this.panels, parsed.panels || {});
            this.isVimMode = parsed.isVimMode !== false;
        }
        
        this.updatePanelVisibility();
    }

    saveSettings() {
        const settings = {
            panels: this.panels,
            isVimMode: this.isVimMode,
            theme: this.currentTheme
        };
        
        localStorage.setItem('goosecode-settings', JSON.stringify(settings));
    }

    showSettings() {
        // This would open a settings modal
        console.log('Settings modal would open here');
    }

    showHelp() {
        // This would open a help modal or panel
        console.log('Help modal would open here');
    }

    toggleFullscreen() {
        if (document.fullscreenElement) {
            document.exitFullscreen();
        } else {
            document.documentElement.requestFullscreen();
        }
    }

    // Event System
    emit(eventName, data = {}) {
        const event = new CustomEvent(`goosecode:${eventName}`, { detail: data });
        document.dispatchEvent(event);
    }

    on(eventName, callback) {
        document.addEventListener(`goosecode:${eventName}`, callback);
    }
}

// Initialize GooseCode when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.gooseCode = new GooseCode();
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = GooseCode;
}
