// GooseCode Preview - Live HTML/CSS/JS Preview System
class GooseCodePreview {
    constructor() {
        this.previewFrame = null;
        this.isAutoRefresh = true;
        this.refreshDelay = 500;
        this.refreshTimer = null;
        this.consoleMessages = [];
        this.errorCount = 0;
        this.warningCount = 0;
        
        this.init();
    }

    init() {
        this.setupPreviewFrame();
        this.setupEventListeners();
        this.setupConsoleCapture();
        this.setupErrorHandling();
        
        console.log('🖼️ GooseCode Preview initialized');
    }

    setupPreviewFrame() {
        this.previewFrame = document.getElementById('preview-frame');
        if (!this.previewFrame) {
            console.error('Preview frame not found');
            return;
        }

        // Set up sandbox attributes for security
        this.previewFrame.setAttribute('sandbox', 
            'allow-scripts allow-same-origin allow-forms allow-popups allow-modals'
        );

        // Initial load
        this.refreshPreview();
    }

    setupEventListeners() {
        // Run button
        const runButton = document.getElementById('run-code');
        runButton?.addEventListener('click', () => {
            this.runCode();
        });

        // Refresh button
        const refreshButton = document.getElementById('refresh-preview');
        refreshButton?.addEventListener('click', () => {
            this.refreshPreview();
        });

        // Listen for editor changes
        document.addEventListener('goosecode:contentChanged', (e) => {
            if (this.isAutoRefresh) {
                this.scheduleRefresh();
            }
        });

        // Listen for file switches
        document.addEventListener('goosecode:tabSwitched', (e) => {
            if (e.detail.filename.endsWith('.html')) {
                this.scheduleRefresh();
            }
        });

        // Preview frame load event
        this.previewFrame?.addEventListener('load', () => {
            this.onPreviewLoad();
        });

        // Preview frame error event
        this.previewFrame?.addEventListener('error', (e) => {
            this.onPreviewError(e);
        });
    }

    setupConsoleCapture() {
        // This will capture console messages from the preview iframe
        // We'll inject a script to capture and forward console messages
    }

    setupErrorHandling() {
        // Global error handler for preview frame
        window.addEventListener('message', (event) => {
            if (event.source === this.previewFrame?.contentWindow) {
                this.handlePreviewMessage(event.data);
            }
        });
    }

    // Core Preview Methods
    runCode() {
        this.clearConsole();
        this.resetErrorCounts();
        this.refreshPreview();
        
        // Show loading state
        this.showLoadingState();
        
        // Update run button state
        const runButton = document.getElementById('run-code');
        if (runButton) {
            runButton.textContent = '⏳ Running...';
            runButton.disabled = true;
            
            setTimeout(() => {
                runButton.textContent = '▶ Run';
                runButton.disabled = false;
            }, 1000);
        }
    }

    refreshPreview() {
        if (!this.previewFrame || !window.gooseCodeEditor) return;

        try {
            const htmlContent = this.buildPreviewContent();
            this.loadPreviewContent(htmlContent);
        } catch (error) {
            this.handlePreviewError(error);
        }
    }

    scheduleRefresh() {
        if (this.refreshTimer) {
            clearTimeout(this.refreshTimer);
        }
        
        this.refreshTimer = setTimeout(() => {
            this.refreshPreview();
        }, this.refreshDelay);
    }

    buildPreviewContent() {
        const editor = window.gooseCodeEditor;
        if (!editor) return this.getDefaultPreviewContent();

        // Get current HTML content
        let htmlContent = '';
        const currentFile = editor.currentFile;
        
        if (currentFile.endsWith('.html')) {
            htmlContent = editor.editor.getValue();
        } else {
            // If not HTML file, try to get index.html
            const htmlFile = editor.files.get('index.html');
            htmlContent = htmlFile ? htmlFile.content : this.getDefaultPreviewContent();
        }

        // Inject CSS files
        const cssFiles = Array.from(editor.files.entries())
            .filter(([name, file]) => name.endsWith('.css'));
        
        let cssContent = '';
        cssFiles.forEach(([name, file]) => {
            cssContent += `\n/* ${name} */\n${file.content}\n`;
        });

        if (cssContent) {
            // Try to inject into existing <style> tags or <head>
            if (htmlContent.includes('<style>')) {
                htmlContent = htmlContent.replace('</style>', `${cssContent}</style>`);
            } else if (htmlContent.includes('</head>')) {
                htmlContent = htmlContent.replace('</head>', `<style>${cssContent}</style></head>`);
            } else {
                // Prepend to body if no head tag
                htmlContent = `<style>${cssContent}</style>\n${htmlContent}`;
            }
        }

        // Inject JavaScript files
        const jsFiles = Array.from(editor.files.entries())
            .filter(([name, file]) => name.endsWith('.js'));
        
        let jsContent = '';
        jsFiles.forEach(([name, file]) => {
            jsContent += `\n// ${name}\n${file.content}\n`;
        });

        if (jsContent) {
            // Wrap JS in error handling and console capture
            const wrappedJs = this.wrapJavaScript(jsContent);
            
            if (htmlContent.includes('</body>')) {
                htmlContent = htmlContent.replace('</body>', `<script>${wrappedJs}</script></body>`);
            } else {
                htmlContent += `<script>${wrappedJs}</script>`;
            }
        }

        // Inject console capture script
        const consoleScript = this.getConsoleScript();
        htmlContent = htmlContent.replace('</head>', `<script>${consoleScript}</script></head>`);

        return htmlContent;
    }

    loadPreviewContent(htmlContent) {
        if (!this.previewFrame) return;

        // Create a blob URL for the content
        const blob = new Blob([htmlContent], { type: 'text/html' });
        const url = URL.createObjectURL(blob);
        
        // Load the content
        this.previewFrame.src = url;
        
        // Clean up previous blob URL
        if (this.previousBlobUrl) {
            URL.revokeObjectURL(this.previousBlobUrl);
        }
        this.previousBlobUrl = url;
    }

    wrapJavaScript(jsContent) {
        return `
try {
    ${jsContent}
} catch (error) {
    window.parent.postMessage({
        type: 'error',
        message: error.message,
        stack: error.stack,
        line: error.line || 'unknown',
        column: error.column || 'unknown'
    }, '*');
    console.error('Runtime Error:', error);
}`;
    }

    getConsoleScript() {
        return `
// Console capture for GooseCode Preview
(function() {
    const originalConsole = {
        log: console.log,
        error: console.error,
        warn: console.warn,
        info: console.info
    };
    
    function sendToParent(type, args) {
        const message = {
            type: 'console',
            level: type,
            args: Array.from(args).map(arg => {
                if (typeof arg === 'object') {
                    try {
                        return JSON.stringify(arg, null, 2);
                    } catch (e) {
                        return String(arg);
                    }
                }
                return String(arg);
            }),
            timestamp: new Date().toISOString()
        };
        
        window.parent.postMessage(message, '*');
    }
    
    console.log = function(...args) {
        originalConsole.log.apply(console, args);
        sendToParent('log', args);
    };
    
    console.error = function(...args) {
        originalConsole.error.apply(console, args);
        sendToParent('error', args);
    };
    
    console.warn = function(...args) {
        originalConsole.warn.apply(console, args);
        sendToParent('warn', args);
    };
    
    console.info = function(...args) {
        originalConsole.info.apply(console, args);
        sendToParent('info', args);
    };
    
    // Capture unhandled errors
    window.addEventListener('error', function(event) {
        window.parent.postMessage({
            type: 'error',
            message: event.message,
            filename: event.filename,
            line: event.lineno,
            column: event.colno,
            stack: event.error ? event.error.stack : 'No stack trace available'
        }, '*');
    });
    
    // Capture unhandled promise rejections
    window.addEventListener('unhandledrejection', function(event) {
        window.parent.postMessage({
            type: 'error',
            message: 'Unhandled Promise Rejection: ' + event.reason,
            stack: event.reason && event.reason.stack ? event.reason.stack : 'No stack trace available'
        }, '*');
    });
})();`;
    }

    // Event Handlers
    onPreviewLoad() {
        this.hideLoadingState();
        console.log('🖼️ Preview loaded successfully');
    }

    onPreviewError(error) {
        this.hideLoadingState();
        this.showError('Preview Load Error', error.message || 'Failed to load preview');
        console.error('Preview error:', error);
    }

    handlePreviewMessage(data) {
        switch (data.type) {
            case 'console':
                this.addConsoleMessage(data);
                break;
            case 'error':
                this.handleRuntimeError(data);
                break;
            default:
                console.log('Unknown preview message:', data);
        }
    }

    handleRuntimeError(errorData) {
        this.errorCount++;
        this.updateErrorIndicators();
        
        const errorMessage = {
            level: 'error',
            args: [errorData.message],
            timestamp: new Date().toISOString(),
            stack: errorData.stack,
            line: errorData.line,
            column: errorData.column
        };
        
        this.addConsoleMessage(errorMessage);
        this.showError('Runtime Error', errorData.message);
    }

    // Console Management
    addConsoleMessage(messageData) {
        this.consoleMessages.push(messageData);
        
        // Update console in terminal panel if visible
        this.updateConsoleDisplay();
        
        // Update error/warning counts
        if (messageData.level === 'error') {
            this.errorCount++;
        } else if (messageData.level === 'warn') {
            this.warningCount++;
        }
        
        this.updateErrorIndicators();
    }

    updateConsoleDisplay() {
        const terminalOutput = document.getElementById('terminal-output');
        if (!terminalOutput) return;

        // Add recent console messages to terminal
        const recentMessages = this.consoleMessages.slice(-10); // Show last 10 messages
        
        recentMessages.forEach(msg => {
            if (!msg.displayed) {
                const line = document.createElement('div');
                line.className = `terminal-line console-${msg.level}`;
                
                const timestamp = new Date(msg.timestamp).toLocaleTimeString();
                const content = msg.args.join(' ');
                
                line.innerHTML = `<span class="timestamp">[${timestamp}]</span> <span class="level">${msg.level.toUpperCase()}:</span> ${content}`;
                
                terminalOutput.appendChild(line);
                msg.displayed = true;
                
                // Auto-scroll to bottom
                terminalOutput.scrollTop = terminalOutput.scrollHeight;
            }
        });
    }

    clearConsole() {
        this.consoleMessages = [];
        
        // Clear terminal console messages
        const terminalOutput = document.getElementById('terminal-output');
        if (terminalOutput) {
            const consoleLines = terminalOutput.querySelectorAll('.terminal-line[class*="console-"]');
            consoleLines.forEach(line => line.remove());
        }
    }

    // Error Handling and Display
    showError(title, message) {
        // Create error notification
        const errorDiv = document.createElement('div');
        errorDiv.className = 'preview-error';
        errorDiv.innerHTML = `
            <div class="error-header">
                <span class="error-icon">⚠️</span>
                <span class="error-title">${title}</span>
                <button class="error-close" onclick="this.parentElement.parentElement.remove()">×</button>
            </div>
            <div class="error-message">${message}</div>
        `;
        
        // Add to preview controls
        const previewControls = document.querySelector('.preview-controls');
        if (previewControls) {
            previewControls.appendChild(errorDiv);
            
            // Auto-remove after 5 seconds
            setTimeout(() => {
                if (errorDiv.parentElement) {
                    errorDiv.remove();
                }
            }, 5000);
        }
    }

    updateErrorIndicators() {
        // Update status bar with error/warning counts
        const statusRight = document.querySelector('.status-right');
        if (statusRight) {
            let statusIndicator = statusRight.querySelector('.error-indicator');
            if (!statusIndicator) {
                statusIndicator = document.createElement('span');
                statusIndicator.className = 'status-item error-indicator';
                statusRight.insertBefore(statusIndicator, statusRight.lastElementChild);
            }
            
            if (this.errorCount > 0 || this.warningCount > 0) {
                const errorText = this.errorCount > 0 ? `${this.errorCount} errors` : '';
                const warningText = this.warningCount > 0 ? `${this.warningCount} warnings` : '';
                const separator = errorText && warningText ? ', ' : '';
                
                statusIndicator.textContent = `${errorText}${separator}${warningText}`;
                statusIndicator.style.color = this.errorCount > 0 ? 'var(--error-color)' : 'var(--warning-color)';
            } else {
                statusIndicator.textContent = '✅ No issues';
                statusIndicator.style.color = 'var(--success-color)';
            }
        }
    }

    resetErrorCounts() {
        this.errorCount = 0;
        this.warningCount = 0;
        this.updateErrorIndicators();
    }

    // UI State Management
    showLoadingState() {
        const previewFrame = this.previewFrame;
        if (previewFrame) {
            previewFrame.style.opacity = '0.5';
        }
        
        // Show loading overlay
        let loadingOverlay = document.querySelector('.preview-loading');
        if (!loadingOverlay) {
            loadingOverlay = document.createElement('div');
            loadingOverlay.className = 'preview-loading';
            loadingOverlay.innerHTML = `
                <div class="loading-spinner"></div>
                <div class="loading-text">Running code...</div>
            `;
            
            const previewPanel = document.getElementById('preview-panel');
            if (previewPanel) {
                previewPanel.appendChild(loadingOverlay);
            }
        }
        
        loadingOverlay.style.display = 'flex';
    }

    hideLoadingState() {
        const previewFrame = this.previewFrame;
        if (previewFrame) {
            previewFrame.style.opacity = '1';
        }
        
        const loadingOverlay = document.querySelector('.preview-loading');
        if (loadingOverlay) {
            loadingOverlay.style.display = 'none';
        }
    }

    // Settings and Configuration
    setAutoRefresh(enabled) {
        this.isAutoRefresh = enabled;
        console.log(`Auto-refresh ${enabled ? 'enabled' : 'disabled'}`);
    }

    setRefreshDelay(delay) {
        this.refreshDelay = Math.max(100, delay); // Minimum 100ms
        console.log(`Refresh delay set to ${this.refreshDelay}ms`);
    }

    // Utility Methods
    getDefaultPreviewContent() {
        return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GooseCode Preview</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 40px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            max-width: 600px;
        }
        h1 {
            font-size: 3em;
            margin-bottom: 20px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        p {
            font-size: 1.2em;
            opacity: 0.9;
            line-height: 1.6;
        }
        .logo {
            font-size: 4em;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🪿</div>
        <h1>GooseCode Preview</h1>
        <p>Start coding to see your live preview here!</p>
        <p>Your HTML, CSS, and JavaScript will be rendered in real-time.</p>
    </div>
</body>
</html>`;
    }
}

// Initialize preview when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.gooseCodePreview = new GooseCodePreview();
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = GooseCodePreview;
}
