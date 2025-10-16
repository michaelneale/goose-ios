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
    @State private var showTrialInstructions = false
    
    // Animation states
    @State private var showSessionsTitle = false
    @State private var visibleSessionsCount = 0
    @State private var showTrialModeCard = false
    
    // Access API service for trial mode check
    @StateObject private var apiService = GooseAPIService.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Main content with ScrollView
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Spacer for the card (dynamic based on card height)
                            Color.clear
                                .frame(height: 300) // Approximate height, adjust if needed
                            
                            // Node Matrix Section - fills remaining space dynamically
                            if isLoadingSessions && showSessionsTitle {
                                // Loading state
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.secondary)
                                    Spacer()
                                }
                                .frame(height: calculateNodeMatrixHeight(for: geometry.size))
                            } else if recentSessions.isEmpty && showSessionsTitle {
                                // Empty state
                                VStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    
                                    Text("No sessions today")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: calculateNodeMatrixHeight(for: geometry.size))
                            } else if showSessionsTitle {
                                // Node Matrix - expanded to fill space dynamically
                                NodeMatrix(sessions: recentSessions)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: calculateNodeMatrixHeight(for: geometry.size))
                                    .transition(.opacity)
                            }
                            
                            Spacer(minLength: 80) // Reduced space for input box
                        }
                        .padding(.horizontal, 16)
                    }
                    .refreshable {
                        await loadRecentSessions()
                    }
                    
                    // Chat input with trial banner
                    ChatInputView(
                        text: $inputText,
                        voiceManager: voiceManager,
                        onSubmit: {
                            onStartChat(inputText)
                        },
                        showTrialBanner: apiService.isTrialMode && showTrialModeCard,
                        onTrialBannerTap: {
                            showTrialInstructions = true
                        }
                    )
                }
                
                // Welcome Card overlaid on top (full bleed)
                VStack {
                    WelcomeCard(
                        showingSidebar: $showingSidebar,
                        onAnimationComplete: {
                            // Show trial mode card if in trial mode
                            if apiService.isTrialMode {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    showTrialModeCard = true
                                }
                            }
                            
                            // Show sessions title
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showSessionsTitle = true
                                }
                            }
                        }
                    )
                    
                    Spacer()
                }
                .zIndex(1)
                .allowsHitTesting(true) // Allow interaction with the card
                
                // Safe area extension at the very top - covers the shadow
                SafeAreaExtension()
                    .zIndex(2) // Above WelcomeCard to cover its shadow
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environmentObject(ConfigurationHandler.shared)
        }
        .sheet(isPresented: $showTrialInstructions) {
            TrialModeInstructionsView()
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
            
            // Load recent sessions
            Task {
                await loadRecentSessions()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshSessions"))) { _ in
            // Refresh sessions when settings are saved
            Task {
                await loadRecentSessions()
            }
        }
    }
    
    // Calculate dynamic height for NodeMatrix based on viewport
    private func calculateNodeMatrixHeight(for size: CGSize) -> CGFloat {
        // Account for: welcome card (300), chat input (~100), padding, safe areas
        let reservedSpace: CGFloat = 500
        let availableHeight = size.height - reservedSpace
        
        // Set min and max bounds
        let minHeight: CGFloat = 250
        let maxHeight: CGFloat = 500
        
        return min(max(availableHeight, minHeight), maxHeight)
    }
    
    // Load recent sessions from API
    private func loadRecentSessions() async {
        isLoadingSessions = true
        
        // Fetch insights and sessions in parallel
        async let insightsTask = GooseAPIService.shared.fetchInsights()
        async let sessionsTask = GooseAPIService.shared.fetchSessions()
        
        let (insights, sessions) = await (insightsTask, sessionsTask)
        
        await MainActor.run {
            recentSessions = Array(sessions.prefix(30))
            isLoadingSessions = false
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
