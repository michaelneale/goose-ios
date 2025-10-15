import SwiftUI

struct WelcomeView: View {
    @Binding var showingSidebar: Bool
    @State private var inputText = ""
    @Environment(\.colorScheme) var colorScheme
    var onStartChat: (String) -> Void
    var onSessionSelect: (String) -> Void
    
    // Voice features - shared with ChatView
    @ObservedObject var voiceManager: EnhancedVoiceManager
    
    // States for welcome view
    @State private var recentSessions: [ChatSession] = []
    @State private var isLoadingSessions = true
    @State private var isSettingsPresented = false
    
    // Animation states
    @State private var displayedText = ""
    @State private var showSessionsTitle = false
    @State private var visibleSessionsCount = 0
    @State private var showLogo = false
    @State private var showProgressSection = false
    @State private var progressValue: CGFloat = 0.0
    @State private var tokenCount: Int64 = 0
    private let maxTokens: Int64 = 1_000_000_000 // 1 billion
    
    // Computed property for time-aware greeting
    private var fullText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        
        switch hour {
        case 0..<12:
            greeting = "Good morning!"
        case 12..<17:
            greeting = "Good afternoon!"
        case 17..<21:
            greeting = "Good evening!"
        default:
            greeting = "Good night!"
        }
        
        return "\(greeting)\nWhat do you want to do?"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSidebar.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                            .frame(width: 24, height: 22)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 66)
                .padding(.bottom, 8)
            }
            .background(Color(UIColor.systemBackground).opacity(0.95))
            .shadow(color: Color.black.opacity(0.05), radius: 0, y: 1)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Greeting text with goose logo
                    HStack(alignment: .top, spacing: 16) {
                        Text(displayedText)
                            .font(.system(size: 20, weight: .medium))
                            .lineSpacing(6)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if showLogo {
                            Image("GooseLogo")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.primary)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 32)
                    
                    // Progress Section
                    if showProgressSection {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("TOKENS USED")
                                    .font(.system(size: 12, weight: .semibold))
                                    .tracking(1.02)
                                    .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.66))
                                
                                Spacer()
                                
                                Text("\(formatTokenCount(tokenCount)) of 1B")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(colorScheme == .dark ? 
                                              Color(red: 0.10, green: 0.10, blue: 0.13) : 
                                              Color(red: 0.95, green: 0.95, blue: 0.95))
                                        .frame(height: 12)
                                    
                                    // Foreground (animated)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(colorScheme == .dark ? Color.white : Color.black)
                                        .frame(width: geometry.size.width * progressValue, height: 12)
                                }
                            }
                            .frame(height: 12)
                        }
                        .padding(.top, 16)
                        .transition(.opacity)
                    }
                    
                    // Recent Sessions Section
                    VStack(alignment: .leading, spacing: 16) {
                        if showSessionsTitle {
                            Text("RECENT SESSIONS")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.02)
                                .foregroundColor(.secondary)
                                .padding(.top, 16)
                        }
                        
                        if isLoadingSessions && showSessionsTitle {
                            // Loading state
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.secondary)
                                Spacer()
                            }
                            .frame(height: 100)
                        } else if recentSessions.isEmpty && showSessionsTitle {
                            // Empty state
                            Text("No recent sessions")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 32)
                        } else {
                            // Session list - show sessions one by one
                            VStack(spacing: 24) {
                                ForEach(Array(recentSessions.prefix(3).enumerated()), id: \.element.id) { index, session in
                                    if index < visibleSessionsCount {
                                        WelcomeSessionRowView(session: session)
                                            .transition(.opacity)
                                            .onTapGesture {
                                                // Load the session when tapped
                                                onSessionSelect(session.id)
                                            }
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 180) // Space for input box
                }
                .padding(.horizontal, 16)
            }
            
            // Bottom input area - using shared ChatInputView
            ChatInputView(
                text: $inputText,
                voiceManager: voiceManager,
                onSubmit: {
                    onStartChat(inputText)
                }
            )
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environmentObject(ConfigurationHandler.shared)
        }
        .onChange(of: voiceManager.transcribedText) { newText in
            // Update input text with transcribed text in real-time
            if !newText.isEmpty && voiceManager.voiceMode != .normal {
                inputText = newText
            }
        }
        .onAppear {
            // Set up voice manager callback for auto-sending messages
            voiceManager.onSubmitMessage = { message in
                inputText = message
                // Auto-send the message
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onStartChat(inputText)
                }
            }
            
            // Start typewriter animation
            startTypewriterEffect()
            
            // Load recent sessions
            Task {
                await loadRecentSessions()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshSessions"))) { _ in
            // Refresh sessions when settings are saved
            Task {
                await loadRecentSessions()
                // Update progress bar with new data
                await MainActor.run {
                    let percentage = Double(tokenCount) / Double(maxTokens)
                    withAnimation(.easeOut(duration: 0.5)) {
                        progressValue = CGFloat(min(percentage, 1.0))
                    }
                }
            }
        }
    }
    
    // Typewriter effect for greeting text
    private func startTypewriterEffect() {
        displayedText = ""
        
        // Fast typewriter effect - 20ms per character
        for (index, character) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.02) {
                displayedText.append(character)
                
                // When text is complete, show logo
                if displayedText == fullText {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showLogo = true
                    }
                    
                    // Show progress section
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showProgressSection = true
                        }
                        
                        // Animate progress bar
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            let percentage = Double(tokenCount) / Double(maxTokens)
                            withAnimation(.easeOut(duration: 0.8)) {
                                progressValue = CGFloat(min(percentage, 1.0))
                            }
                        }
                    }
                    
                    // Show sessions title
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showSessionsTitle = true
                        }
                        
                        // Show sessions one by one quickly (100ms between each)
                        for i in 0..<min(3, recentSessions.count) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.1) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    visibleSessionsCount = i + 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Load recent sessions from API
    private func loadRecentSessions() async {
        isLoadingSessions = true
        
        // Fetch insights and sessions in parallel
        async let insightsTask = GooseAPIService.shared.fetchInsights()
        async let sessionsTask = GooseAPIService.shared.fetchSessions()
        
        let (insights, sessions) = await (insightsTask, sessionsTask)
        
        await MainActor.run {
            // Update token count from insights
            if let insights = insights {
                tokenCount = insights.totalTokens
                
                // If progress bar is already visible, update it immediately
                if showProgressSection {
                    let percentage = Double(tokenCount) / Double(maxTokens)
                    withAnimation(.easeOut(duration: 0.5)) {
                        progressValue = CGFloat(min(percentage, 1.0))
                    }
                }
            }
            
            recentSessions = Array(sessions.prefix(3))
            isLoadingSessions = false
            
            // Update visible count if sessions loaded after animation
            if showSessionsTitle && visibleSessionsCount == 0 {
                for i in 0..<min(3, recentSessions.count) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            visibleSessionsCount = i + 1
                        }
                    }
                }
            }
        }
    }
    
    // Format token count for display (e.g., "450M")
    private func formatTokenCount(_ count: Int64) -> String {
        let million: Int64 = 1_000_000
        if count >= million {
            let millions = Double(count) / Double(million)
            return String(format: "%.0fM", millions)
        } else {
            let thousands = Double(count) / 1000.0
            return String(format: "%.0fK", thousands)
        }
    }
}

// MARK: - Welcome Session Row View
struct WelcomeSessionRowView: View {
    let session: ChatSession
    @Environment(\.colorScheme) var colorScheme
    
    var formattedTimestamp: String {
        // Parse the ISO8601 date string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let sessionDate = formatter.date(from: session.updatedAt) else {
            return session.updatedAt
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(sessionDate)
        
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if minutes < 60 {
            return "\(minutes) Minute\(minutes == 1 ? "" : "s") ago"
        } else if hours < 24 {
            return "\(hours) Hour\(hours == 1 ? "" : "s") ago"
        } else if days == 1 {
            return "Yesterday"
        } else {
            return "\(days) Days ago"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.description.isEmpty ? "Session \(session.id.prefix(8))" : session.description)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(formattedTimestamp)
                .font(.system(size: 12))
                .tracking(0.06)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    WelcomeView(
        showingSidebar: .constant(false),
        onStartChat: { text in
            print("Starting chat with: \(text)")
        },
        onSessionSelect: { sessionId in
            print("Selected session: \(sessionId)")
        },
        voiceManager: EnhancedVoiceManager()
    )
}
