// AI Configuration for GooseCode
// Ready for GPT-5 Code integration

class AICodeAgent {
    constructor(config = {}) {
        this.config = {
            apiEndpoint: config.apiEndpoint || 'https://api.openai.com/v1/chat/completions',
            model: config.model || 'gpt-4-code', // Will be 'gpt-5-code' when available
            apiKey: config.apiKey || null,
            maxTokens: config.maxTokens || 2000,
            temperature: config.temperature || 0.1,
            ...config
        };
        
        this.conversationHistory = [];
        this.codeContext = '';
        this.projectMetadata = {};
    }

    // Main method to send code-related queries
    async askCodeQuestion(question, codeContext = '') {
        try {
            const messages = this.buildMessages(question, codeContext);
            const response = await this.callAI(messages);
            
            this.conversationHistory.push({
                role: 'user',
                content: question,
                timestamp: Date.now()
            });
            
            this.conversationHistory.push({
                role: 'assistant',
                content: response,
                timestamp: Date.now()
            });
            
            return response;
        } catch (error) {
            console.error('AI request failed:', error);
            return this.getFallbackResponse(question);
        }
    }

    // Build context-aware messages for the AI
    buildMessages(question, codeContext) {
        const systemPrompt = `You are GPT-5 Code, an expert coding assistant integrated into GooseCode, a VIM/EMACS style web development environment.

CONTEXT:
- User is working in a web development environment with HTML/CSS/JavaScript/Canvas support
- Current code context: ${codeContext || 'No code provided'}
- Project type: Web application with Canvas support
- Editor: VIM/EMACS style interface

CAPABILITIES:
- Write, debug, and optimize HTML, CSS, JavaScript code
- Create Canvas animations and interactive graphics
- Provide code suggestions and improvements
- Explain code concepts and best practices
- Generate templates and boilerplate code

RESPONSE STYLE:
- Be concise but thorough
- Provide working code examples when relevant
- Use modern JavaScript (ES6+) and best practices
- Include comments for complex code
- Suggest improvements and optimizations

Current conversation context: ${this.getRecentContext()}`;

        const messages = [
            { role: 'system', content: systemPrompt },
            ...this.getRecentHistory(5), // Last 5 exchanges
            { role: 'user', content: question }
        ];

        return messages;
    }

    // Make API call to GPT-5 Code (or current model)
    async callAI(messages) {
        if (!this.config.apiKey) {
            return this.getFallbackResponse(messages[messages.length - 1].content);
        }

        const response = await fetch(this.config.apiEndpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.config.apiKey}`
            },
            body: JSON.stringify({
                model: this.config.model,
                messages: messages,
                max_tokens: this.config.maxTokens,
                temperature: this.config.temperature,
                stream: false
            })
        });

        if (!response.ok) {
            throw new Error(`API request failed: ${response.status}`);
        }

        const data = await response.json();
        return data.choices[0].message.content;
    }

    // Enhanced fallback responses for when API is not available
    getFallbackResponse(question) {
        const lowerQuestion = question.toLowerCase();
        
        const responses = {
            canvas: `I'd love to help with Canvas! Here's a starter template:

\`\`\`javascript
const canvas = document.getElementById('myCanvas');
const ctx = canvas.getContext('2d');

function animate() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Your animation code here
    
    requestAnimationFrame(animate);
}
animate();
\`\`\`

What type of Canvas project are you building? I can help with:
• Animations and effects
• Interactive graphics
• Games (2D platformers, puzzles)
• Data visualizations
• Drawing applications`,

            debug: `I can help debug your code! Common issues I look for:

**JavaScript:**
• Syntax errors (missing semicolons, brackets)
• Undefined variables
• Async/await issues
• Event listener problems

**HTML/CSS:**
• Unclosed tags
• CSS selector specificity
• Responsive design issues
• Accessibility concerns

Could you share the specific error or unexpected behavior you're seeing?`,

            optimize: `Great question about optimization! Here are key areas:

**Performance:**
• Minimize DOM manipulations
• Use requestAnimationFrame for animations
• Optimize Canvas rendering
• Lazy load resources

**Code Quality:**
• Use modern JavaScript (const/let, arrow functions)
• Implement proper error handling
• Add meaningful comments
• Follow consistent naming conventions

What specific aspect would you like to optimize?`,

            html: `I can help with HTML structure! Best practices:

\`\`\`html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Your App</title>
</head>
<body>
    <main>
        <!-- Your content here -->
    </main>
</body>
</html>
\`\`\`

Key points:
• Semantic HTML elements
• Proper meta tags
• Accessibility attributes
• Valid structure`,

            css: `CSS help coming up! Modern approaches:

\`\`\`css
/* CSS Grid for layouts */
.container {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 1rem;
}

/* Flexbox for components */
.component {
    display: flex;
    align-items: center;
    justify-content: space-between;
}

/* CSS Variables for theming */
:root {
    --primary-color: #4CAF50;
    --text-color: #333;
}
\`\`\`

What CSS challenge are you working on?`,

            javascript: `JavaScript assistance ready! Modern patterns:

\`\`\`javascript
// Modern async/await
async function fetchData(url) {
    try {
        const response = await fetch(url);
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Fetch error:', error);
    }
}

// ES6+ features
const processData = (items) => {
    return items
        .filter(item => item.active)
        .map(item => ({ ...item, processed: true }));
};
\`\`\`

What JavaScript functionality are you implementing?`
        };

        // Find matching response
        for (const [key, response] of Object.entries(responses)) {
            if (lowerQuestion.includes(key)) {
                return response;
            }
        }

        return `I'm here to help with your web development! I can assist with:

• **HTML/CSS**: Structure, styling, responsive design
• **JavaScript**: Logic, DOM manipulation, async operations  
• **Canvas**: Animations, games, interactive graphics
• **Debugging**: Finding and fixing issues
• **Optimization**: Performance and code quality

What would you like to work on? Feel free to share your code and I'll provide specific suggestions!`;
    }

    // Get recent conversation context
    getRecentContext() {
        const recent = this.conversationHistory.slice(-3);
        return recent.map(msg => `${msg.role}: ${msg.content.substring(0, 100)}...`).join('\n');
    }

    // Get recent conversation history
    getRecentHistory(count = 5) {
        return this.conversationHistory.slice(-count * 2);
    }

    // Update code context
    updateCodeContext(code) {
        this.codeContext = code;
        this.analyzeCode(code);
    }

    // Analyze code to provide better context
    analyzeCode(code) {
        this.projectMetadata = {
            hasHTML: code.includes('<html') || code.includes('<!DOCTYPE'),
            hasCSS: code.includes('<style>') || code.includes('css'),
            hasJavaScript: code.includes('<script>') || code.includes('function'),
            hasCanvas: code.includes('canvas') || code.includes('getContext'),
            hasAsync: code.includes('async') || code.includes('await'),
            hasEventListeners: code.includes('addEventListener'),
            lineCount: code.split('\n').length,
            complexity: this.calculateComplexity(code)
        };
    }

    // Simple complexity calculation
    calculateComplexity(code) {
        const complexityIndicators = [
            'function', 'if', 'for', 'while', 'switch', 'try', 'catch'
        ];
        
        let complexity = 0;
        complexityIndicators.forEach(indicator => {
            const matches = code.match(new RegExp(indicator, 'g'));
            complexity += matches ? matches.length : 0;
        });
        
        return complexity;
    }

    // Specialized methods for different types of assistance
    async generateCode(prompt, type = 'general') {
        const typePrompts = {
            canvas: `Generate Canvas code for: ${prompt}. Include proper setup and animation loop.`,
            component: `Create a reusable web component for: ${prompt}. Include HTML, CSS, and JavaScript.`,
            function: `Write a JavaScript function that: ${prompt}. Use modern ES6+ syntax.`,
            style: `Create CSS styles for: ${prompt}. Use modern CSS features like Grid/Flexbox.`,
            general: prompt
        };

        return await this.askCodeQuestion(typePrompts[type] || prompt, this.codeContext);
    }

    async debugCode(errorDescription) {
        const debugPrompt = `Help debug this issue: ${errorDescription}
        
Current code context:
\`\`\`
${this.codeContext}
\`\`\`

Please identify the problem and provide a solution.`;

        return await this.askCodeQuestion(debugPrompt, this.codeContext);
    }

    async improveCode(improvementType = 'general') {
        const improvements = {
            performance: 'Analyze and suggest performance improvements for this code',
            accessibility: 'Suggest accessibility improvements for this code',
            security: 'Review this code for security issues and suggest fixes',
            structure: 'Suggest structural improvements and refactoring for this code',
            general: 'Review this code and suggest general improvements'
        };

        return await this.askCodeQuestion(improvements[improvementType], this.codeContext);
    }

    // Clear conversation history
    clearHistory() {
        this.conversationHistory = [];
    }

    // Export conversation for analysis
    exportConversation() {
        return {
            history: this.conversationHistory,
            metadata: this.projectMetadata,
            timestamp: Date.now()
        };
    }
}

// Configuration presets
const AI_PRESETS = {
    development: {
        temperature: 0.1,
        maxTokens: 2000,
        model: 'gpt-4-code'
    },
    creative: {
        temperature: 0.7,
        maxTokens: 1500,
        model: 'gpt-4-code'
    },
    debugging: {
        temperature: 0.0,
        maxTokens: 1000,
        model: 'gpt-4-code'
    }
};

// Export for use in GooseCode
if (typeof window !== 'undefined') {
    window.AICodeAgent = AICodeAgent;
    window.AI_PRESETS = AI_PRESETS;
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { AICodeAgent, AI_PRESETS };
}
