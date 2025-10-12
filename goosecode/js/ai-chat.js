// GooseCode AI Chat - AI Assistant Integration
class GooseCodeAI {
    constructor() {
        this.messages = [];
        this.isConnected = false;
        this.isTyping = false;
        this.chatContainer = null;
        this.chatInput = null;
        this.sendButton = null;
        this.statusIndicator = null;
        
        // AI Configuration (placeholder for future GPT-5 integration)
        this.config = {
            model: 'gpt-5-code', // Placeholder
            temperature: 0.7,
            maxTokens: 2048,
            systemPrompt: this.getSystemPrompt()
        };
        
        this.init();
    }

    init() {
        this.setupElements();
        this.setupEventListeners();
        this.loadChatHistory();
        this.simulateConnection();
        
        console.log('🤖 GooseCode AI initialized');
    }

    setupElements() {
        this.chatContainer = document.getElementById('chat-messages');
        this.chatInput = document.getElementById('chat-input');
        this.sendButton = document.getElementById('send-chat');
        this.statusIndicator = document.querySelector('.status-indicator');
    }

    setupEventListeners() {
        // Send button
        this.sendButton?.addEventListener('click', () => {
            this.sendMessage();
        });

        // Enter key to send
        this.chatInput?.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.sendMessage();
            }
        });

        // Auto-resize textarea
        this.chatInput?.addEventListener('input', () => {
            this.autoResizeTextarea();
        });

        // Listen for code-related events
        document.addEventListener('goosecode:fileOpened', (e) => {
            this.onFileOpened(e.detail.filename);
        });

        document.addEventListener('goosecode:error', (e) => {
            this.onError(e.detail);
        });

        // Context menu for messages
        this.chatContainer?.addEventListener('contextmenu', (e) => {
            if (e.target.closest('.message')) {
                e.preventDefault();
                this.showMessageContextMenu(e, e.target.closest('.message'));
            }
        });
    }

    // Message Management
    sendMessage(text = null) {
        const messageText = text || this.chatInput?.value.trim();
        if (!messageText) return;

        // Clear input
        if (this.chatInput) {
            this.chatInput.value = '';
            this.autoResizeTextarea();
        }

        // Add user message
        this.addMessage('user', messageText);

        // Get context
        const context = this.gatherContext();

        // Simulate AI response (replace with actual API call)
        this.simulateAIResponse(messageText, context);
    }

    addMessage(role, content, metadata = {}) {
        const message = {
            id: Date.now() + Math.random(),
            role,
            content,
            timestamp: new Date(),
            metadata
        };

        this.messages.push(message);
        this.renderMessage(message);
        this.saveChatHistory();
        this.scrollToBottom();

        return message;
    }

    renderMessage(message) {
        if (!this.chatContainer) return;

        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${message.role}-message`;
        messageDiv.dataset.messageId = message.id;

        const timestamp = message.timestamp.toLocaleTimeString();
        
        messageDiv.innerHTML = `
            <div class="message-header">
                <span class="message-role">${message.role === 'user' ? '👤' : '🤖'}</span>
                <span class="message-time">${timestamp}</span>
            </div>
            <div class="message-content">${this.formatMessageContent(message.content)}</div>
            ${message.metadata.actions ? this.renderMessageActions(message.metadata.actions) : ''}
        `;

        this.chatContainer.appendChild(messageDiv);
    }

    formatMessageContent(content) {
        // Convert markdown-like formatting to HTML
        let formatted = content
            .replace(/```(\w+)?\n([\s\S]*?)```/g, '<pre><code class="language-$1">$2</code></pre>')
            .replace(/`([^`]+)`/g, '<code>$1</code>')
            .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
            .replace(/\*(.*?)\*/g, '<em>$1</em>')
            .replace(/\n/g, '<br>');

        return formatted;
    }

    renderMessageActions(actions) {
        const actionsDiv = document.createElement('div');
        actionsDiv.className = 'message-actions';
        
        actions.forEach(action => {
            const button = document.createElement('button');
            button.className = 'action-button';
            button.textContent = action.label;
            button.addEventListener('click', () => action.handler());
            actionsDiv.appendChild(button);
        });

        return actionsDiv.outerHTML;
    }

    // AI Response Simulation (replace with actual API integration)
    async simulateAIResponse(userMessage, context) {
        this.setTyping(true);

        // Simulate thinking time
        await this.delay(1000 + Math.random() * 2000);

        const response = this.generateSimulatedResponse(userMessage, context);
        
        this.setTyping(false);
        this.addMessage('assistant', response.content, response.metadata);
    }

    generateSimulatedResponse(userMessage, context) {
        const lowerMessage = userMessage.toLowerCase();
        
        // Code analysis responses
        if (lowerMessage.includes('error') || lowerMessage.includes('bug')) {
            return {
                content: `I can help you debug that issue! Based on your current code, here are some common things to check:

1. **Syntax Errors**: Make sure all brackets, parentheses, and quotes are properly closed
2. **Variable Names**: Check for typos in variable names
3. **Console Errors**: Look at the browser console for specific error messages

Would you like me to analyze your current file for potential issues?`,
                metadata: {
                    actions: [
                        {
                            label: 'Analyze Current File',
                            handler: () => this.analyzeCurrentFile()
                        },
                        {
                            label: 'Show Console',
                            handler: () => window.gooseCode?.switchPanel('terminal')
                        }
                    ]
                }
            };
        }

        if (lowerMessage.includes('html') || lowerMessage.includes('css') || lowerMessage.includes('javascript')) {
            return {
                content: `I'd be happy to help with your web development! Here are some suggestions:

**HTML**: Structure your content with semantic elements
**CSS**: Use flexbox or grid for layouts, and consider mobile-first design
**JavaScript**: Write clean, readable code with proper error handling

What specific aspect would you like help with?`,
                metadata: {
                    actions: [
                        {
                            label: 'Generate HTML Template',
                            handler: () => this.generateTemplate('html')
                        },
                        {
                            label: 'CSS Best Practices',
                            handler: () => this.showBestPractices('css')
                        }
                    ]
                }
            };
        }

        if (lowerMessage.includes('canvas') || lowerMessage.includes('animation')) {
            return {
                content: `Canvas animations are exciting! Here's a basic pattern you can use:

\`\`\`javascript
const canvas = document.getElementById('myCanvas');
const ctx = canvas.getContext('2d');

function animate() {
    // Clear the canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Draw your animation frame
    // ... your drawing code here ...
    
    // Request next frame
    requestAnimationFrame(animate);
}

animate(); // Start the animation
\`\`\`

Would you like me to create a specific animation example?`,
                metadata: {
                    actions: [
                        {
                            label: 'Create Animation Example',
                            handler: () => this.createAnimationExample()
                        }
                    ]
                }
            };
        }

        if (lowerMessage.includes('theme') || lowerMessage.includes('color')) {
            return {
                content: `I can help you with theming! GooseCode supports several built-in themes:

- **Dark**: Classic dark theme (default)
- **Light**: Clean light theme
- **Monokai**: Popular syntax highlighting
- **Dracula**: Vibrant purple theme
- **Solarized**: Easy on the eyes

You can switch themes using the theme button or the command \`:theme <name>\``,
                metadata: {
                    actions: [
                        {
                            label: 'Switch to Light Theme',
                            handler: () => window.gooseCode?.setTheme('light')
                        },
                        {
                            label: 'Switch to Monokai',
                            handler: () => window.gooseCode?.setTheme('monokai')
                        }
                    ]
                }
            };
        }

        // Default helpful response
        return {
            content: `I'm here to help you code! I can assist with:

• **Debugging**: Finding and fixing errors in your code
• **Code Review**: Suggesting improvements and best practices
• **Templates**: Generating boilerplate code for HTML/CSS/JS
• **Explanations**: Explaining how code works or concepts
• **Optimization**: Making your code faster and more efficient

What would you like to work on? Feel free to paste your code or describe what you're trying to build!`,
            metadata: {
                actions: [
                    {
                        label: 'Analyze Current Code',
                        handler: () => this.analyzeCurrentFile()
                    },
                    {
                        label: 'Generate Template',
                        handler: () => this.showTemplateOptions()
                    }
                ]
            }
        };
    }

    // Context Gathering
    gatherContext() {
        const editor = window.gooseCodeEditor;
        const context = {
            currentFile: null,
            openFiles: [],
            hasErrors: false,
            theme: window.gooseCode?.currentTheme || 'dark'
        };

        if (editor) {
            context.currentFile = {
                name: editor.currentFile,
                content: editor.editor?.getValue() || '',
                mode: editor.files.get(editor.currentFile)?.mode || 'text'
            };

            context.openFiles = Array.from(editor.files.keys());
            context.hasErrors = window.gooseCodePreview?.errorCount > 0;
        }

        return context;
    }

    // Action Handlers
    analyzeCurrentFile() {
        const editor = window.gooseCodeEditor;
        if (!editor) {
            this.addMessage('assistant', 'No file is currently open to analyze.');
            return;
        }

        const content = editor.editor.getValue();
        const filename = editor.currentFile;
        const mode = editor.files.get(filename)?.mode || 'text';

        let analysis = `**File Analysis: ${filename}**\n\n`;
        
        // Basic analysis
        const lines = content.split('\n').length;
        const chars = content.length;
        const words = content.split(/\s+/).filter(w => w.length > 0).length;
        
        analysis += `📊 **Statistics:**\n`;
        analysis += `- Lines: ${lines}\n`;
        analysis += `- Characters: ${chars}\n`;
        analysis += `- Words: ${words}\n\n`;

        // Mode-specific analysis
        if (mode === 'htmlmixed') {
            const hasDoctype = content.includes('<!DOCTYPE');
            const hasTitle = content.includes('<title>');
            const hasViewport = content.includes('viewport');
            
            analysis += `🌐 **HTML Analysis:**\n`;
            analysis += `- DOCTYPE declared: ${hasDoctype ? '✅' : '❌'}\n`;
            analysis += `- Title tag present: ${hasTitle ? '✅' : '❌'}\n`;
            analysis += `- Viewport meta tag: ${hasViewport ? '✅' : '❌'}\n`;
        } else if (mode === 'css') {
            const hasMediaQueries = content.includes('@media');
            const hasFlexbox = content.includes('flex');
            const hasGrid = content.includes('grid');
            
            analysis += `🎨 **CSS Analysis:**\n`;
            analysis += `- Media queries: ${hasMediaQueries ? '✅' : '❌'}\n`;
            analysis += `- Uses Flexbox: ${hasFlexbox ? '✅' : '❌'}\n`;
            analysis += `- Uses Grid: ${hasGrid ? '✅' : '❌'}\n`;
        } else if (mode === 'javascript') {
            const hasEventListeners = content.includes('addEventListener');
            const hasArrowFunctions = content.includes('=>');
            const hasConsoleLog = content.includes('console.log');
            
            analysis += `⚡ **JavaScript Analysis:**\n`;
            analysis += `- Event listeners: ${hasEventListeners ? '✅' : '❌'}\n`;
            analysis += `- Arrow functions: ${hasArrowFunctions ? '✅' : '❌'}\n`;
            analysis += `- Console logging: ${hasConsoleLog ? '✅' : '❌'}\n`;
        }

        this.addMessage('assistant', analysis);
    }

    generateTemplate(type) {
        const templates = {
            html: `<!DOCTYPE html>
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
            background: #f0f0f0;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hello, World!</h1>
        <p>Start building your amazing app here!</p>
    </div>
</body>
</html>`,
            css: `/* Reset and base styles */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    line-height: 1.6;
    color: #333;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px;
}

/* Responsive design */
@media (max-width: 768px) {
    .container {
        padding: 0 15px;
    }
}`,
            javascript: `// Modern JavaScript template
document.addEventListener('DOMContentLoaded', function() {
    console.log('Page loaded successfully!');
    
    // Your code here
    initializeApp();
});

function initializeApp() {
    // Initialize your application
    setupEventListeners();
    loadData();
}

function setupEventListeners() {
    // Add event listeners here
}

async function loadData() {
    try {
        // Load any necessary data
        console.log('Data loaded');
    } catch (error) {
        console.error('Error loading data:', error);
    }
}`
        };

        const template = templates[type];
        if (template) {
            // Create new file with template
            const filename = `template.${type === 'javascript' ? 'js' : type}`;
            window.gooseCodeEditor?.newFile(filename);
            
            // Set content
            setTimeout(() => {
                window.gooseCodeEditor?.editor.setValue(template);
            }, 100);

            this.addMessage('assistant', `Created a new ${type.toUpperCase()} template file: **${filename}**`);
        }
    }

    createAnimationExample() {
        const animationCode = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Canvas Animation</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            background: #1a1a1a;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
        }
        canvas {
            border: 2px solid #333;
            border-radius: 10px;
        }
    </style>
</head>
<body>
    <canvas id="animationCanvas" width="600" height="400"></canvas>
    
    <script>
        const canvas = document.getElementById('animationCanvas');
        const ctx = canvas.getContext('2d');
        
        // Animation variables
        let time = 0;
        const particles = [];
        
        // Create particles
        for (let i = 0; i < 50; i++) {
            particles.push({
                x: Math.random() * canvas.width,
                y: Math.random() * canvas.height,
                vx: (Math.random() - 0.5) * 2,
                vy: (Math.random() - 0.5) * 2,
                radius: Math.random() * 3 + 1,
                color: \`hsl(\${Math.random() * 360}, 70%, 60%)\`
            });
        }
        
        function animate() {
            // Clear canvas
            ctx.fillStyle = 'rgba(0, 0, 0, 0.1)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            // Update and draw particles
            particles.forEach(particle => {
                // Update position
                particle.x += particle.vx;
                particle.y += particle.vy;
                
                // Bounce off edges
                if (particle.x < 0 || particle.x > canvas.width) particle.vx *= -1;
                if (particle.y < 0 || particle.y > canvas.height) particle.vy *= -1;
                
                // Draw particle
                ctx.beginPath();
                ctx.arc(particle.x, particle.y, particle.radius, 0, Math.PI * 2);
                ctx.fillStyle = particle.color;
                ctx.fill();
            });
            
            time += 0.01;
            requestAnimationFrame(animate);
        }
        
        animate();
    </script>
</body>
</html>`;

        // Create new file with animation
        const filename = 'animation-example.html';
        window.gooseCodeEditor?.newFile(filename);
        
        setTimeout(() => {
            window.gooseCodeEditor?.editor.setValue(animationCode);
        }, 100);

        this.addMessage('assistant', 'Created a **particle animation example**! The code includes:\n\n• Canvas setup\n• Particle system\n• Animation loop\n• Collision detection\n\nRun it to see colorful particles bouncing around! 🎨');
    }

    showTemplateOptions() {
        this.addMessage('assistant', 'Here are some templates I can generate for you:', {
            actions: [
                {
                    label: 'HTML Template',
                    handler: () => this.generateTemplate('html')
                },
                {
                    label: 'CSS Template',
                    handler: () => this.generateTemplate('css')
                },
                {
                    label: 'JavaScript Template',
                    handler: () => this.generateTemplate('javascript')
                }
            ]
        });
    }

    // UI Management
    setTyping(isTyping) {
        this.isTyping = isTyping;
        
        if (isTyping) {
            this.showTypingIndicator();
        } else {
            this.hideTypingIndicator();
        }
    }

    showTypingIndicator() {
        if (!this.chatContainer) return;

        const typingDiv = document.createElement('div');
        typingDiv.className = 'message ai-message typing-indicator';
        typingDiv.innerHTML = `
            <div class="message-header">
                <span class="message-role">🤖</span>
                <span class="message-time">typing...</span>
            </div>
            <div class="message-content">
                <div class="typing-dots">
                    <span></span>
                    <span></span>
                    <span></span>
                </div>
            </div>
        `;

        this.chatContainer.appendChild(typingDiv);
        this.scrollToBottom();
    }

    hideTypingIndicator() {
        const typingIndicator = this.chatContainer?.querySelector('.typing-indicator');
        if (typingIndicator) {
            typingIndicator.remove();
        }
    }

    autoResizeTextarea() {
        if (!this.chatInput) return;

        this.chatInput.style.height = 'auto';
        this.chatInput.style.height = Math.min(this.chatInput.scrollHeight, 120) + 'px';
    }

    scrollToBottom() {
        if (this.chatContainer) {
            this.chatContainer.scrollTop = this.chatContainer.scrollHeight;
        }
    }

    // Connection Management
    simulateConnection() {
        // Simulate connecting to AI service
        setTimeout(() => {
            this.isConnected = true;
            this.updateStatus('Ready');
        }, 1000);
    }

    updateStatus(status) {
        if (this.statusIndicator) {
            this.statusIndicator.textContent = `● ${status}`;
            this.statusIndicator.className = 'status-indicator ' + 
                (status === 'Ready' ? 'status-ready' : 
                 status === 'Connecting' ? 'status-connecting' : 'status-error');
        }
    }

    // Event Handlers
    onFileOpened(filename) {
        // Could suggest relevant help based on file type
        const ext = filename.split('.').pop();
        if (ext === 'html' && this.messages.length === 1) { // Only initial message
            setTimeout(() => {
                this.addMessage('assistant', `I see you opened **${filename}**! I can help you with HTML structure, semantic elements, accessibility, and more. Just ask! 🌐`);
            }, 1000);
        }
    }

    onError(error) {
        if (this.messages.length > 1) { // Don't spam on initial load
            this.addMessage('assistant', `I noticed an error in your code: **${error.message}**\n\nWould you like me to help debug this?`, {
                actions: [
                    {
                        label: 'Help Debug',
                        handler: () => this.sendMessage(`Help me debug this error: ${error.message}`)
                    }
                ]
            });
        }
    }

    // Persistence
    saveChatHistory() {
        try {
            const history = {
                messages: this.messages.slice(-50), // Keep last 50 messages
                timestamp: Date.now()
            };
            localStorage.setItem('goosecode-chat-history', JSON.stringify(history));
        } catch (error) {
            console.warn('Failed to save chat history:', error);
        }
    }

    loadChatHistory() {
        try {
            const saved = localStorage.getItem('goosecode-chat-history');
            if (saved) {
                const history = JSON.parse(saved);
                
                // Only load recent history (last 24 hours)
                const dayAgo = Date.now() - (24 * 60 * 60 * 1000);
                if (history.timestamp > dayAgo) {
                    this.messages = history.messages || [];
                    this.messages.forEach(message => this.renderMessage(message));
                }
            }
        } catch (error) {
            console.warn('Failed to load chat history:', error);
        }
    }

    clearHistory() {
        this.messages = [];
        if (this.chatContainer) {
            this.chatContainer.innerHTML = '';
        }
        localStorage.removeItem('goosecode-chat-history');
        
        // Add welcome message
        this.addMessage('assistant', 'Hello! I\'m your AI coding assistant. I can help you write, debug, and improve your code. What would you like to work on?');
    }

    // System Prompt for AI
    getSystemPrompt() {
        return `You are an AI coding assistant integrated into GooseCode, a VIM/EMACS style web-based code editor. 

Your role is to help users with:
- Writing HTML, CSS, and JavaScript code
- Debugging errors and issues
- Code review and optimization suggestions
- Explaining programming concepts
- Generating code templates and examples
- Canvas graphics and animations
- Web development best practices

You have access to the user's current code files and can see what they're working on. Be helpful, concise, and provide actionable advice. When appropriate, offer to generate code examples or templates.

The editor supports live preview of HTML/CSS/JavaScript with Canvas graphics. Users can switch between different themes and layouts. VIM keybindings are available.

Be encouraging and supportive, especially for beginners. Provide clear explanations and practical examples.`;
    }

    // Utility Methods
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// Initialize AI chat when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.gooseCodeAI = new GooseCodeAI();
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = GooseCodeAI;
}
