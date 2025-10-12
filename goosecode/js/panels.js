// GooseCode Panels - Panel management system
class GooseCodePanels {
    constructor() {
        this.panels = {
            explorer: { visible: true, width: 250 },
            preview: { visible: true, width: 400 },
            terminal: { visible: false, height: 200 },
            aiChat: { visible: false, width: 400 }
        };
        
        this.activeRightPanel = 'preview';
        this.isResizing = false;
        this.resizeData = null;
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.setupResizeHandlers();
        this.restoreLayout();
        
        console.log('📱 GooseCode Panels initialized');
    }

    setupEventListeners() {
        // Panel toggle buttons
        document.querySelectorAll('.panel-toggle').forEach(button => {
            button.addEventListener('click', (e) => {
                const panel = e.target.dataset.panel;
                this.togglePanel(panel);
            });
        });

        // Right panel tabs
        document.querySelectorAll('.panel-tab').forEach(tab => {
            tab.addEventListener('click', (e) => {
                const panel = e.target.dataset.panel;
                this.switchRightPanel(panel);
            });
        });

        // Window resize
        window.addEventListener('resize', () => {
            this.handleWindowResize();
        });

        // Listen for global panel events
        document.addEventListener('goosecode:togglePanel', (e) => {
            this.togglePanel(e.detail.panel);
        });

        document.addEventListener('goosecode:switchPanel', (e) => {
            this.switchRightPanel(e.detail.panel);
        });
    }

    setupResizeHandlers() {
        // Add resize handles to panels
        this.addResizeHandle('side-panel', 'right');
        this.addResizeHandle('right-panel', 'left');
        
        // Global mouse events for resizing
        document.addEventListener('mousemove', (e) => {
            if (this.isResizing) {
                this.handleResize(e);
            }
        });

        document.addEventListener('mouseup', () => {
            if (this.isResizing) {
                this.stopResize();
            }
        });
    }

    addResizeHandle(panelId, direction) {
        const panel = document.getElementById(panelId);
        if (!panel) return;

        const handle = document.createElement('div');
        handle.className = `resize-handle resize-${direction}`;
        handle.style.cssText = `
            position: absolute;
            ${direction}: -2px;
            top: 0;
            bottom: 0;
            width: 4px;
            cursor: col-resize;
            background: transparent;
            z-index: 10;
            transition: background-color 0.2s ease;
        `;

        handle.addEventListener('mouseenter', () => {
            handle.style.backgroundColor = 'var(--accent-color)';
        });

        handle.addEventListener('mouseleave', () => {
            if (!this.isResizing) {
                handle.style.backgroundColor = 'transparent';
            }
        });

        handle.addEventListener('mousedown', (e) => {
            this.startResize(e, panelId, direction);
        });

        panel.style.position = 'relative';
        panel.appendChild(handle);
    }

    startResize(e, panelId, direction) {
        e.preventDefault();
        
        this.isResizing = true;
        this.resizeData = {
            panelId,
            direction,
            startX: e.clientX,
            startWidth: document.getElementById(panelId).offsetWidth
        };

        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        
        // Add visual feedback
        document.body.classList.add('resizing');
    }

    handleResize(e) {
        if (!this.resizeData) return;

        const { panelId, direction, startX, startWidth } = this.resizeData;
        const panel = document.getElementById(panelId);
        if (!panel) return;

        const deltaX = e.clientX - startX;
        const multiplier = direction === 'right' ? 1 : -1;
        const newWidth = startWidth + (deltaX * multiplier);

        // Set min/max constraints
        const minWidth = panelId === 'side-panel' ? 200 : 300;
        const maxWidth = panelId === 'side-panel' ? 400 : 600;
        const constrainedWidth = Math.max(minWidth, Math.min(maxWidth, newWidth));

        panel.style.width = constrainedWidth + 'px';
        
        // Update panel data
        const panelName = panelId.replace('-panel', '').replace('side', 'explorer').replace('right', this.activeRightPanel);
        if (this.panels[panelName]) {
            this.panels[panelName].width = constrainedWidth;
        }
    }

    stopResize() {
        this.isResizing = false;
        this.resizeData = null;
        
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
        document.body.classList.remove('resizing');
        
        // Save layout
        this.saveLayout();
    }

    // Panel Management
    togglePanel(panelName) {
        if (!this.panels[panelName]) return;

        this.panels[panelName].visible = !this.panels[panelName].visible;
        this.updatePanelVisibility();
        this.saveLayout();
        
        // Emit event
        this.emit('panelToggled', { panel: panelName, visible: this.panels[panelName].visible });
    }

    showPanel(panelName) {
        if (!this.panels[panelName]) return;

        this.panels[panelName].visible = true;
        this.updatePanelVisibility();
        
        // If it's a right panel, switch to it
        if (['preview', 'terminal', 'aiChat'].includes(panelName)) {
            this.switchRightPanel(panelName);
        }
    }

    hidePanel(panelName) {
        if (!this.panels[panelName]) return;

        this.panels[panelName].visible = false;
        this.updatePanelVisibility();
    }

    switchRightPanel(panelName) {
        if (!['preview', 'terminal', 'aiChat'].includes(panelName)) return;

        // Deactivate all right panel tabs and content
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

        this.activeRightPanel = panelName;
        
        // Make sure the right panel is visible
        this.panels[panelName].visible = true;
        this.updatePanelVisibility();
        
        this.emit('panelSwitched', { panel: panelName });
    }

    updatePanelVisibility() {
        // Side panel (Explorer)
        const sidePanel = document.getElementById('side-panel');
        if (sidePanel) {
            if (this.panels.explorer.visible) {
                sidePanel.style.display = 'flex';
                sidePanel.style.width = this.panels.explorer.width + 'px';
            } else {
                sidePanel.style.display = 'none';
            }
        }

        // Right panel
        const rightPanel = document.getElementById('right-panel');
        if (rightPanel) {
            const hasVisiblePanel = this.panels.preview.visible || 
                                  this.panels.terminal.visible || 
                                  this.panels.aiChat.visible;
            
            if (hasVisiblePanel) {
                rightPanel.style.display = 'flex';
                rightPanel.style.width = this.panels[this.activeRightPanel].width + 'px';
            } else {
                rightPanel.style.display = 'none';
            }
        }

        // Update layout class
        this.updateLayoutClass();
    }

    updateLayoutClass() {
        const body = document.body;
        
        // Remove existing layout classes
        body.classList.remove('no-sidebar', 'no-rightpanel', 'panels-only');
        
        const hasLeftPanel = this.panels.explorer.visible;
        const hasRightPanel = this.panels.preview.visible || 
                             this.panels.terminal.visible || 
                             this.panels.aiChat.visible;
        
        if (!hasLeftPanel) body.classList.add('no-sidebar');
        if (!hasRightPanel) body.classList.add('no-rightpanel');
        if (!hasLeftPanel && !hasRightPanel) body.classList.add('panels-only');
    }

    // Layout Management
    handleWindowResize() {
        const width = window.innerWidth;
        
        // Mobile responsiveness
        if (width < 768) {
            this.enterMobileMode();
        } else if (width < 1024) {
            this.enterTabletMode();
        } else {
            this.enterDesktopMode();
        }
        
        this.updatePanelVisibility();
    }

    enterMobileMode() {
        document.body.classList.add('mobile-layout');
        document.body.classList.remove('tablet-layout', 'desktop-layout');
        
        // Hide panels by default on mobile
        this.panels.explorer.visible = false;
        this.panels.preview.visible = false;
        
        // Make panels overlay instead of inline
        const sidePanel = document.getElementById('side-panel');
        const rightPanel = document.getElementById('right-panel');
        
        if (sidePanel) {
            sidePanel.classList.add('overlay');
        }
        if (rightPanel) {
            rightPanel.classList.add('overlay');
        }
    }

    enterTabletMode() {
        document.body.classList.add('tablet-layout');
        document.body.classList.remove('mobile-layout', 'desktop-layout');
        
        // Reduce panel widths
        this.panels.explorer.width = Math.min(this.panels.explorer.width, 200);
        this.panels.preview.width = Math.min(this.panels.preview.width, 300);
    }

    enterDesktopMode() {
        document.body.classList.add('desktop-layout');
        document.body.classList.remove('mobile-layout', 'tablet-layout');
        
        // Remove overlay classes
        const sidePanel = document.getElementById('side-panel');
        const rightPanel = document.getElementById('right-panel');
        
        if (sidePanel) {
            sidePanel.classList.remove('overlay');
        }
        if (rightPanel) {
            rightPanel.classList.remove('overlay');
        }
    }

    // Preset Layouts
    setLayout(layoutName) {
        switch (layoutName) {
            case 'default':
                this.panels.explorer.visible = true;
                this.panels.preview.visible = true;
                this.panels.terminal.visible = false;
                this.panels.aiChat.visible = false;
                this.switchRightPanel('preview');
                break;
                
            case 'coding':
                this.panels.explorer.visible = true;
                this.panels.preview.visible = false;
                this.panels.terminal.visible = true;
                this.panels.aiChat.visible = false;
                this.switchRightPanel('terminal');
                break;
                
            case 'preview':
                this.panels.explorer.visible = false;
                this.panels.preview.visible = true;
                this.panels.terminal.visible = false;
                this.panels.aiChat.visible = false;
                this.switchRightPanel('preview');
                break;
                
            case 'minimal':
                this.panels.explorer.visible = false;
                this.panels.preview.visible = false;
                this.panels.terminal.visible = false;
                this.panels.aiChat.visible = false;
                break;
                
            case 'ai-assist':
                this.panels.explorer.visible = true;
                this.panels.preview.visible = false;
                this.panels.terminal.visible = false;
                this.panels.aiChat.visible = true;
                this.switchRightPanel('aiChat');
                break;
        }
        
        this.updatePanelVisibility();
        this.saveLayout();
        
        this.emit('layoutChanged', { layout: layoutName });
    }

    // Persistence
    saveLayout() {
        const layout = {
            panels: this.panels,
            activeRightPanel: this.activeRightPanel,
            timestamp: Date.now()
        };
        
        localStorage.setItem('goosecode-layout', JSON.stringify(layout));
    }

    restoreLayout() {
        try {
            const saved = localStorage.getItem('goosecode-layout');
            if (saved) {
                const layout = JSON.parse(saved);
                
                // Restore panel states
                Object.assign(this.panels, layout.panels);
                this.activeRightPanel = layout.activeRightPanel || 'preview';
                
                // Apply the layout
                this.updatePanelVisibility();
                this.switchRightPanel(this.activeRightPanel);
                
                console.log('📱 Layout restored from localStorage');
            }
        } catch (error) {
            console.warn('Failed to restore layout:', error);
        }
    }

    // Keyboard Shortcuts
    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey || e.metaKey) {
                switch (e.key) {
                    case 'b':
                        e.preventDefault();
                        this.togglePanel('explorer');
                        break;
                    case 'j':
                        e.preventDefault();
                        this.togglePanel('preview');
                        break;
                    case '`':
                        e.preventDefault();
                        this.togglePanel('terminal');
                        break;
                    case 'k':
                        e.preventDefault();
                        this.togglePanel('aiChat');
                        break;
                }
            }
            
            // Layout shortcuts
            if (e.altKey && e.shiftKey) {
                switch (e.key) {
                    case '1':
                        e.preventDefault();
                        this.setLayout('default');
                        break;
                    case '2':
                        e.preventDefault();
                        this.setLayout('coding');
                        break;
                    case '3':
                        e.preventDefault();
                        this.setLayout('preview');
                        break;
                    case '4':
                        e.preventDefault();
                        this.setLayout('minimal');
                        break;
                    case '5':
                        e.preventDefault();
                        this.setLayout('ai-assist');
                        break;
                }
            }
        });
    }

    // Panel Content Management
    refreshPanel(panelName) {
        switch (panelName) {
            case 'preview':
                window.gooseCodePreview?.refreshPreview();
                break;
            case 'terminal':
                window.gooseCodeTerminal?.clear();
                break;
            case 'explorer':
                this.refreshFileTree();
                break;
        }
    }

    refreshFileTree() {
        // Update file tree based on current files
        const editor = window.gooseCodeEditor;
        if (!editor) return;

        const fileTree = document.getElementById('file-tree');
        if (!fileTree) return;

        // Clear existing files
        const projectFolder = fileTree.querySelector('.file-children');
        if (projectFolder) {
            projectFolder.innerHTML = '';
            
            // Add current files
            editor.files.forEach((file, filename) => {
                const fileItem = document.createElement('div');
                fileItem.className = 'file-item';
                
                const icon = this.getFileIcon(filename);
                fileItem.innerHTML = `
                    <span class="file-icon">${icon}</span>
                    <span class="file-name">${filename}</span>
                `;
                
                fileItem.addEventListener('click', (e) => {
                    e.stopPropagation();
                    editor.openFile(filename);
                });
                
                projectFolder.appendChild(fileItem);
            });
        }
    }

    getFileIcon(filename) {
        const ext = filename.split('.').pop().toLowerCase();
        const icons = {
            'html': '📄',
            'css': '🎨',
            'js': '⚡',
            'json': '📋',
            'md': '📝',
            'txt': '📄'
        };
        return icons[ext] || '📄';
    }

    // Utility Methods
    emit(eventName, data = {}) {
        const event = new CustomEvent(`goosecode:${eventName}`, { detail: data });
        document.dispatchEvent(event);
    }

    getPanelState(panelName) {
        return this.panels[panelName] || null;
    }

    getAllPanelStates() {
        return { ...this.panels };
    }
}

// Initialize panels when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.gooseCodePanels = new GooseCodePanels();
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = GooseCodePanels;
}
