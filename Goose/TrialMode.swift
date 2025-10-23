import Foundation

/// Handles all trial mode logic including session management and demo content
class TrialMode {
    static let shared = TrialMode()
    
    private let trialSessionKey = "trial_session_id"
    
    private init() {}
    
    // MARK: - Demo Session Data Structure
    
    struct DemoSessionData {
        let id: String
        let description: String
        let messages: [Message]
        let createdAt: String
        let updatedAt: String
        let displayMessageCount: Int?  // Optional override for graph visualization
        
        // Default init with displayMessageCount = nil
        init(id: String, description: String, messages: [Message], createdAt: String, updatedAt: String, displayMessageCount: Int? = nil) {
            self.id = id
            self.description = description
            self.messages = messages
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.displayMessageCount = displayMessageCount
        }
        
        var messageCount: Int { displayMessageCount ?? messages.count }
        
        var session: ChatSession {
            ChatSession(
                id: id,
                description: description,
                messageCount: messageCount,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }
    
    // MARK: - Demo Sessions Configuration
    // All session data in one place - easy to edit!
    
    private lazy var demoSessionsData: [DemoSessionData] = {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        
        return [
            // TODAY - Many sessions for interesting graph visualization
            
            DemoSessionData(
                id: "trial-demo-1",
                description: "Example: Planning weekend trip (read-only)",
                messages: [
                    Message(role: .user, text: "Can you help me work out why my script can't reach google.com"),
                    Message(role: .assistant, text: "I'd be happy to help you debug this... (this is just an example)")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 1)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 0.5)),
                displayMessageCount: 8
            ),
            
            DemoSessionData(
                id: "trial-demo-2",
                description: "Example: Deploy home server (read-only)",
                messages: [
                    Message(role: .user, text: "I need you to deploy and turn on my home automation server"),
                    Message(role: .assistant, text: "I'll deploy the latest server for you, it was to fly.io last time so I will try that and report back to you ...")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 2)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 1.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-3",
                description: "Example: Recipe for dinner party (read-only)",
                messages: [
                    Message(role: .user, text: "Can you find the latest podcast, and transcripe it for me, picking out the important themes with time stamps"),
                    Message(role: .assistant, text: "No problem, I can see from your notes what podcast it is, I will install whisper and transcribe it, do you want me to email it when done?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 3)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 2.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-16",
                description: "Example: Morning workout routine (read-only)",
                messages: [
                    Message(role: .user, text: "Create a 30-minute morning workout routine"),
                    Message(role: .assistant, text: "Here's an effective 30-minute morning routine:\n\n5 min warm-up\n20 min circuit training\n5 min cooldown\n\nLet me break down each section...")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 4)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 3.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-17",
                description: "Example: Book recommendations (read-only)",
                messages: [
                    Message(role: .user, text: "Can you recommend some sci-fi books similar to Foundation?"),
                    Message(role: .assistant, text: "If you enjoyed Foundation, you'll love:\n\n1. The Expanse series\n2. Dune by Frank Herbert\n3. Hyperion by Dan Simmons\n\nEach explores grand themes of civilization and human nature...")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 5)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 4.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-20",
                description: "Example: Budget analysis (read-only)",
                messages: [
                    Message(role: .user, text: "Help me analyze my monthly spending"),
                    Message(role: .assistant, text: "I'll help you break down your expenses. Can you share your main spending categories?"),
                    Message(role: .user, text: "Rent $2000, groceries $500, transport $300, dining $400"),
                    Message(role: .assistant, text: "Your dining ($400) seems high compared to groceries ($500). Consider meal prepping to save $150-200/month...")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 6)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 5.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-21",
                description: "Example: Write blog post (read-only)",
                messages: [
                    Message(role: .user, text: "Help me write a blog post about microservices"),
                    Message(role: .assistant, text: "Great topic! Let's structure it:\n\n1. Introduction: What are microservices?\n2. Benefits and challenges\n3. When to use them\n4. Best practices\n\nShall I draft the introduction?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 7)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 6.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-22",
                description: "Example: Code review help (read-only)",
                messages: [
                    Message(role: .user, text: "Can you review this API endpoint for security issues?"),
                    Message(role: .assistant, text: "I'll review for common security vulnerabilities:\n\n1. Input validation\n2. Authentication/Authorization\n3. SQL injection risks\n4. Rate limiting\n\nPlease share the code...")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 8)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 7.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-23",
                description: "Example: Meeting prep notes (read-only)",
                messages: [
                    Message(role: .user, text: "Help me prepare for quarterly planning meeting"),
                    Message(role: .assistant, text: "Let's prepare:\n\n1. Review last quarter's goals\n2. Identify wins and misses\n3. Set SMART goals for next quarter\n4. Anticipate questions\n\nWhat were your main objectives last quarter?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 9)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 8.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-24",
                description: "Example: Research competitors (read-only)",
                messages: [
                    Message(role: .user, text: "Analyze our top 3 competitors in the SaaS space"),
                    Message(role: .assistant, text: "I'll help you create a competitive analysis. What's your product category and who are you considering?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 10)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 9.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-25",
                description: "Example: Draft presentation (read-only)",
                messages: [
                    Message(role: .user, text: "Create outline for product launch presentation"),
                    Message(role: .assistant, text: "Here's a compelling structure:\n\n1. The Problem (2 min)\n2. Our Solution (3 min)\n3. Demo (5 min)\n4. Market Opportunity (2 min)\n5. Call to Action (1 min)\n\nShall I expand each section?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 11)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 10.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-26",
                description: "Example: SQL query optimization (read-only)",
                messages: [
                    Message(role: .user, text: "This query is taking 30 seconds, help optimize it"),
                    Message(role: .assistant, text: "Let's diagnose the issue:\n\n1. Check for missing indexes\n2. Analyze query plan\n3. Look for N+1 problems\n4. Consider query refactoring\n\nCan you share the query and table schema?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 12)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 11.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-27",
                description: "Example: Garden planning (read-only)",
                messages: [
                    Message(role: .user, text: "Help me plan a vegetable garden for beginners"),
                    Message(role: .assistant, text: "Great! Let's start with easy-to-grow vegetables:\n\n1. Tomatoes\n2. Lettuce\n3. Peppers\n4. Herbs (basil, cilantro)\n\nWhat's your climate zone and available space?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 13)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 12.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-28",
                description: "Example: Car maintenance checklist (read-only)",
                messages: [
                    Message(role: .user, text: "Create a car maintenance schedule for 2020 Honda"),
                    Message(role: .assistant, text: "Here's a comprehensive schedule:\n\n**Every 5,000 miles:**\n- Oil change\n- Tire rotation\n\n**Every 30,000 miles:**\n- Air filter\n- Cabin filter\n- Brake inspection\n\nYour current mileage?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 14)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 13.5))
            ),
            
            DemoSessionData(
                id: "trial-demo-29",
                description: "Example: Meal prep for week (read-only)",
                messages: [
                    Message(role: .user, text: "Plan 5 healthy lunches I can prep on Sunday"),
                    Message(role: .assistant, text: "Here are 5 easy meal-prep lunches:\n\n1. Chicken & quinoa bowls\n2. Turkey chili\n3. Greek salad with grilled chicken\n4. Veggie stir-fry with rice\n5. Lentil soup\n\nShall I provide recipes and shopping list?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 15)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 14.5))
            ),
            
            // YESTERDAY
            
            DemoSessionData(
                id: "trial-demo-18",
                description: "Example: Tax deduction questions (read-only)",
                messages: [
                    Message(role: .user, text: "What home office expenses can I deduct?"),
                    Message(role: .assistant, text: "For home office deductions, you can typically claim:\n\n1. Square footage percentage\n2. Internet/phone (business use)\n3. Office supplies\n4. Equipment depreciation\n\nNote: Consult a tax professional for your specific situation.")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 30)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 26))
            ),
            
            DemoSessionData(
                id: "trial-demo-19",
                description: "Example: Birthday party ideas (read-only)",
                messages: [
                    Message(role: .user, text: "Plan a 5-year-old birthday party with 15 kids"),
                    Message(role: .assistant, text: "Fun theme ideas:\n\n1. Superhero Academy\n2. Dinosaur Adventure\n3. Princess/Knight Castle\n\nEach includes games, decorations, and food suggestions. Which theme interests you?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 36)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 32))
            ),
            
            // WEEK AGO (5-10 days)
            
            DemoSessionData(
                id: "trial-demo-4",
                description: "Example: Research new laptop (read-only)",
                messages: [
                    Message(role: .user, text: "My JavaScript app is throwing undefined errors, can you help debug?"),
                    Message(role: .assistant, text: "I'll help you debug those undefined errors. These are among the most common JavaScript issues. Let me guide you through a systematic debugging approach:\n\n1. **Check Variable Declarations**\n2. **Verify Object Properties**\n3. **Examine Async Operations**\n\nCan you share the specific error message and the relevant code?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 5)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 4))
            ),
            
            DemoSessionData(
                id: "trial-demo-5",
                description: "Example: Gift ideas for anniversary (read-only)",
                messages: [
                    Message(role: .user, text: "I want to build a reusable React component for a data table"),
                    Message(role: .assistant, text: "Great! I'll help you build a reusable and flexible React data table component. We'll create something that's:\n\n- **Sortable** - Click column headers to sort\n- **Filterable** - Search across all columns\n- **Paginated** - Handle large datasets efficiently\n- **Customizable** - Easy to style and extend\n\nLet me show you a complete implementation...")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 7)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 6))
            ),
            
            DemoSessionData(
                id: "trial-demo-6",
                description: "Example: Summarize meeting notes (read-only)",
                messages: [
                    Message(role: .user, text: "Summarize these meeting notes into action items"),
                    Message(role: .assistant, text: "I'll extract action items with owners and deadlines. Please share the notes.")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 9)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 8))
            ),
            
            // TWO WEEKS AGO (12-20 days)
            
            DemoSessionData(
                id: "trial-demo-7",
                description: "Example: Draft email to client (read-only)",
                messages: [
                    Message(role: .user, text: "Help me write a professional follow-up email"),
                    Message(role: .assistant, text: "I'll help craft a professional follow-up. What's the context and what action do you want from them?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 14)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 13))
            ),
            
            DemoSessionData(
                id: "trial-demo-8",
                description: "Example: Compare insurance options (read-only)",
                messages: [
                    Message(role: .user, text: "Compare these 3 health insurance plans"),
                    Message(role: .assistant, text: "I'll create a comparison table. Please share the plans' details: premium, deductible, out-of-pocket max, and coverage highlights.")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 16)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 15))
            ),
            
            DemoSessionData(
                id: "trial-demo-9",
                description: "Example: Plan home renovation (read-only)",
                messages: [
                    Message(role: .user, text: "Planning a kitchen renovation, where do I start?"),
                    Message(role: .assistant, text: "Let's break down the kitchen renovation process:\n\n1. Set budget\n2. Choose layout\n3. Select appliances\n4. Pick materials\n5. Hire contractors\n\nWhat's your budget range?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 18)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 17))
            ),
            
            // THREE WEEKS AGO (21-30 days)
            
            DemoSessionData(
                id: "trial-demo-10",
                description: "Example: Review contract terms (read-only)",
                messages: [
                    Message(role: .user, text: "Explain these contract terms in plain English"),
                    Message(role: .assistant, text: "I'll help clarify contract language. Please share the specific sections you need explained. Note: This is informational, not legal advice.")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 22)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 21))
            ),
            
            DemoSessionData(
                id: "trial-demo-11",
                description: "Example: Brainstorm business ideas (read-only)",
                messages: [
                    Message(role: .user, text: "Help me brainstorm SaaS business ideas"),
                    Message(role: .assistant, text: "Let's explore opportunities. What are your skills and interests? What problems frustrate you in your daily work?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 25)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 24))
            ),
            
            DemoSessionData(
                id: "trial-demo-12",
                description: "Example: Organize family photos (read-only)",
                messages: [
                    Message(role: .user, text: "Best way to organize 10 years of family photos?"),
                    Message(role: .assistant, text: "Here's a systematic approach:\n\n1. Choose platform (Google Photos, iCloud, local)\n2. Create folder structure (Year > Event)\n3. Delete duplicates\n4. Tag important people\n5. Back up to 2 locations\n\nPreferred platform?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 28)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 27))
            ),
            
            // MONTH+ AGO (35-50 days)
            
            DemoSessionData(
                id: "trial-demo-13",
                description: "Example: Learn about investing (read-only)",
                messages: [
                    Message(role: .user, text: "Explain index funds vs individual stocks"),
                    Message(role: .assistant, text: "**Index Funds:**\n- Diversified\n- Lower risk\n- Lower fees\n- Passive\n\n**Individual Stocks:**\n- Concentrated\n- Higher risk/reward\n- Active management\n\nFor beginners, index funds are generally recommended. Not financial advice.")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 35)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 34))
            ),
            
            DemoSessionData(
                id: "trial-demo-14",
                description: "Example: Write cover letter (read-only)",
                messages: [
                    Message(role: .user, text: "Help me write a cover letter for software engineer position"),
                    Message(role: .assistant, text: "I'll help craft a compelling cover letter. Tell me:\n\n1. Company name and role\n2. Your relevant experience\n3. Why you're interested\n4. Key achievements\n\nLet's create something that stands out!")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 40)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 39))
            ),
            
            DemoSessionData(
                id: "trial-demo-15",
                description: "Example: Health and fitness routine (read-only)",
                messages: [
                    Message(role: .user, text: "Create a beginner workout and meal plan"),
                    Message(role: .assistant, text: "Great decision to start! Let's create a sustainable plan:\n\n**Workouts:** 3x/week, 30 minutes\n**Nutrition:** Focus on whole foods, adequate protein\n\nWhat's your current activity level and dietary preferences?")
                ],
                createdAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 45)),
                updatedAt: formatter.string(from: now.addingTimeInterval(-3600 * 24 * 44))
            ),
        ]
    }()
    
    // MARK: - Session Management
    
    /// Get the existing trial session ID, or create a new one if needed
    func getOrCreateTrialSession() async throws -> (sessionId: String, messages: [Message]) {
        // Check if we have an existing trial session
        if let existingSessionId = getSavedTrialSessionId() {
            print("📱 Found existing trial session: \(existingSessionId)")
            
            // Try to resume it
            do {
                let (sessionId, messages) = try await GooseAPIService.shared.resumeAgent(sessionId: existingSessionId)
                print("✅ Successfully resumed trial session")
                return (sessionId, messages)
            } catch {
                print("⚠️ Failed to resume trial session, creating new one: \(error)")
                // If resume fails, clear the saved ID and create new
                clearTrialSession()
            }
        }
        
        // Create new trial session
        print("📱 Creating new trial session")
        let (sessionId, messages) = try await GooseAPIService.shared.startAgent()
        saveTrialSessionId(sessionId)
        print("✅ Created and saved new trial session: \(sessionId)")
        return (sessionId, messages)
    }
    
    /// Check if a session ID is a demo session (not the real trial session)
    func isDemoSession(_ sessionId: String) -> Bool {
        return sessionId.hasPrefix("trial-demo-")
    }
    
    // MARK: - Mock Data
    
    /// Get all mock sessions including the real trial session at the top
    func getMockSessions() -> [ChatSession] {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        
        var sessions: [ChatSession] = []
        
        // Add the real trial session at the top if it exists
        if let trialSessionId = getSavedTrialSessionId() {
            sessions.append(ChatSession(
                id: trialSessionId,
                description: "Current Session",
                messageCount: 0, // Will be updated when loaded
                createdAt: formatter.string(from: now),
                updatedAt: formatter.string(from: now)
            ))
        }
        
        // Add all demo sessions
        sessions.append(contentsOf: demoSessionsData.map { $0.session })
        
        return sessions
    }
    
    /// Get mock messages for a demo session
    func getMockMessages(for sessionId: String) -> [Message] {
        // Find the demo session data
        if let demoData = demoSessionsData.first(where: { $0.id == sessionId }) {
            return demoData.messages
        }
        
        // Default fallback
        return [
            Message(
                role: .assistant,
                text: "This is a demo session. Connect to your own Goose agent to access your persistent sessions and full functionality."
            )
        ]
    }
    
    // MARK: - Storage
    
    private func getSavedTrialSessionId() -> String? {
        let sessionId = UserDefaults.standard.string(forKey: trialSessionKey)
        return sessionId?.isEmpty == false ? sessionId : nil
    }
    
    func saveTrialSessionId(_ sessionId: String) {
        UserDefaults.standard.set(sessionId, forKey: trialSessionKey)
    }
    
    private func clearTrialSession() {
        UserDefaults.standard.removeObject(forKey: trialSessionKey)
    }
}
