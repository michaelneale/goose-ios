import SwiftUI

struct ContentView: View {
    @State private var isSettingsPresented = false
    @State private var showingSidebar = false
    @State private var showingSplash = true
    @State private var hasActiveChat = false
    @State private var initialMessage = ""
    @State private var shouldSendInitialMessage = false
    @State private var selectedSessionId: String?
    @State private var sessionName: String = "New Session"
    @State private var cachedSessions: [ChatSession] = [] // Preloaded sessions
    @EnvironmentObject var configurationHandler: ConfigurationHandler
    @EnvironmentObject var themeManager: ThemeManager
    
    // Shared voice manager across WelcomeView and ChatView
    @StateObject private var sharedVoiceManager = EnhancedVoiceManager()
    
    // Keep sidebar width consistent across offsets/overlays
    private let sidebarWidth: CGFloat = 360

    var body: some View {
        if showingSplash {
            // Splash Screen
            SplashScreenView(isActive: $showingSplash)
                .onAppear {
                    // Warm up the demo server if in trial mode (non-blocking)
                    warmUpServer()
                    // Preload sessions on app launch
                    Task {
                        await preloadSessions()
                    }
                }
        } else {
            // Main content with sidebar (following PR pattern)
            ZStack(alignment: .leading) {
                // Main content - full height
                GeometryReader { geometry in
                    NavigationStack {
                        if !hasActiveChat {
                            // Welcome View when no active chat
                            WelcomeView(
                                showingSidebar: $showingSidebar,
                                onStartChat: { message in
                                // Start new chat with the message
                                initialMessage = message
                                shouldSendInitialMessage = !message.isEmpty
                                selectedSessionId = nil // Clear session ID for new chat
                                withAnimation {
                                    hasActiveChat = true
                                }
                            }, onSessionSelect: { sessionId, sessionName in
                                // Load existing session
                                selectedSessionId = sessionId
                                withAnimation {
                                    hasActiveChat = true
                                }
                            },
                                voiceManager: sharedVoiceManager
                            )
                            .navigationBarHidden(true)
                        } else {
                            // Chat View when there's an active chat
                            ChatViewWithInitialMessage(
                                showingSidebar: $showingSidebar,
                                voiceManager: sharedVoiceManager,
                                initialMessage: initialMessage,
                                shouldSendMessage: shouldSendInitialMessage,
                                selectedSessionId: selectedSessionId,
                                onMessageSent: {
                                    // Clear the initial message after sending
                                    initialMessage = ""
                                    shouldSendInitialMessage = false
                                    selectedSessionId = nil
                                },
                                onBackToWelcome: {
                                    // Return to welcome screen
                                    withAnimation {
                                        hasActiveChat = false
                                    }
                                }
                            )
                            .navigationBarHidden(true)
                        }
                    }
                    .sheet(isPresented: $isSettingsPresented) {
                        SettingsView()
                            .environmentObject(configurationHandler)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(
                        ZStack {
                            // Base background color
                            themeManager.backgroundColor
                            
                            // Lightening layer for dark mode - UNDER the content, not over it
                            if themeManager.colorScheme == .dark {
                                Color(white: 0.25)  // Lighter gray to create visible divide
                                    .opacity(showingSidebar ? 1.0 : 0.0)
                                    .ignoresSafeArea()
                                    .animation(.easeInOut(duration: 0.3), value: showingSidebar)
                            }
                        }
                    )
                    .offset(x: showingSidebar ? sidebarWidth : 0) // Offset content when sidebar shows
                    .animation(.easeInOut(duration: 0.3), value: showingSidebar)
                }
                .edgesIgnoringSafeArea(.all)
                
                // Dimming overlay + interactive cover. We render the visual dim below,
                // then a full-screen transparent tap target (to close on tap), and finally
                // a visible sidebar button clone on top so it's always accessible.
                ZStack(alignment: .topLeading) {
                    // Full-screen dim (design-explorations-main style)
                    Color.black
                        .opacity(showingSidebar ? 0.5 : 0.0)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.3), value: showingSidebar)

                    // Tap anywhere to close (except the nav button region)
                    Color.clear
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .allowsHitTesting(showingSidebar)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSidebar = false
                            }
                        }

                    // Nav button passthrough region (top-left)
                    Color.clear
                        .frame(width: 80, height: 100)
                        .allowsHitTesting(false)
                        .offset(x: 0, y: 56)
                }
                .zIndex(0) // below the sidebar sheet so the menu stays visible
                
                // Sidebar overlay
                if showingSidebar {
                    SidebarView(
                        isShowing: $showingSidebar,
                        isSettingsPresented: $isSettingsPresented,
                        cachedSessions: $cachedSessions,
                        onSessionSelect: { sessionId, sessionName in
                            navigateToSession(sessionId: sessionId, sessionName: sessionName)
                        },
                        onNewSession: {
                            navigateToSession(sessionId: nil)
                            Task {
                                await preloadSessions()
                            }
                        },
                        onOverview: {
                            withAnimation {
                                showingSidebar = false
                                hasActiveChat = false
                            }
                        }
                    )
                    .transition(.move(edge: .leading))
                    .onAppear {
                        // Refresh sessions when sidebar opens
                        Task {
                            await preloadSessions()
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if configurationHandler.isConfiguring {
                    ConfigurationStatusView(message: "Configuring...", isLoading: true)
                } else if configurationHandler.configurationSuccess {
                    ConfigurationStatusView(message: "✅ Configuration successful!", isSuccess: true)
                } else if let error = configurationHandler.configurationError {
                    ConfigurationStatusView(message: "❌ \(error)", isError: true)
                        .onTapGesture {
                            configurationHandler.clearError()
                        }
                }
            }
            // No explicit close button overlay; placed inside SidebarView for precise alignment
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshSessions"))) { _ in
                // Refresh sessions when settings are saved
                Task {
                    await preloadSessions()
                }
            }
        }
    }
    
    // MARK: - Navigation Helpers
    
    /// Navigate to a session (existing or new)
    private func navigateToSession(sessionId: String?, sessionName: String = "New Session") {
        self.selectedSessionId = sessionId
        self.sessionName = sessionName
        self.initialMessage = ""
        self.shouldSendInitialMessage = false
        withAnimation {
            self.showingSidebar = false
            self.hasActiveChat = true
        }
    }
    
    // Preload sessions in background
    private func preloadSessions() async {
        print("📥 Attempting to preload sessions...")
        let fetchedSessions = await GooseAPIService.shared.fetchSessions()
        await MainActor.run {
            // Deduplicate sessions by ID (in case backend returns duplicates)
            var seenIds = Set<String>()
            let uniqueSessions = fetchedSessions.filter { session in
                if seenIds.contains(session.id) {
                    print("⚠️ Skipping duplicate session ID: \(session.id)")
                    return false
                }
                seenIds.insert(session.id)
                return true
            }
            
            // Sort by timestamp descending (most recent first) and limit to first 10
            let sorted = uniqueSessions.sorted { $0.timestamp > $1.timestamp }
            self.cachedSessions = Array(sorted.prefix(10))
            
            print("✅ Preloaded \(self.cachedSessions.count) unique sessions (from \(fetchedSessions.count) fetched)")
            if self.cachedSessions.isEmpty {
                print("⚠️ No sessions preloaded - server may not be connected or no sessions exist")
            } else {
                print("📋 Most recent session: '\(self.cachedSessions.first?.title ?? "Unknown")'")
            }
        }
    }
    
    /// Warm up the server on first launch (non-blocking)
    private func warmUpServer() {
        // Check if we're using the demo server
        let baseURL = UserDefaults.standard.string(forKey: "goose_base_url") ?? "https://demo-goosed.fly.dev"
        
        // Only warm up if it's the demo server
        if baseURL.contains("demo-goosed.fly.dev") {
            Task {
                // Fire-and-forget warm-up request
                // We don't care about the response, just want to wake up the server
                if let url = URL(string: baseURL) {
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.timeoutInterval = 10
                    
                    do {
                        // Perform the request but don't wait or care about response
                        let _ = try await URLSession.shared.data(for: request)
                        print("🔥 Demo server warmed up")
                    } catch {
                        // Silently ignore any errors - this is just a warm-up
                        print("🔥 Demo server warm-up attempted")
                    }
                }
            }
        }
    }
}

struct ConfigurationStatusView: View {
    let message: String
    var isLoading = false
    var isSuccess = false
    var isError = false
    
    var backgroundColor: Color {
        if isSuccess { return .green }
        if isError { return .red }
        return .blue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            if isError {
                Text("Tap to dismiss")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(8)
        .shadow(radius: 4)
        .padding(.top, 50) // Account for nav bar
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: isLoading)
        .animation(.spring(), value: isSuccess)
        .animation(.spring(), value: isError)
    }
}

// Wrapper to handle initial message and session loading
struct ChatViewWithInitialMessage: View {
    @Binding var showingSidebar: Bool
    @ObservedObject var voiceManager: EnhancedVoiceManager
    let initialMessage: String
    let shouldSendMessage: Bool
    let selectedSessionId: String?
    let onMessageSent: () -> Void
    let onBackToWelcome: () -> Void
    
    var body: some View {
        ChatView(showingSidebar: $showingSidebar, onBackToWelcome: onBackToWelcome, voiceManager: voiceManager)
            .onAppear {
                // Load session if one was selected
                if let sessionId = selectedSessionId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(
                            name: Notification.Name("LoadSession"),
                            object: nil,
                            userInfo: ["sessionId": sessionId]
                        )
                        onMessageSent()
                    }
                } else if shouldSendMessage && !initialMessage.isEmpty {
                    // Send the initial message after a brief delay to ensure view is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(
                            name: Notification.Name("SendInitialMessage"),
                            object: nil,
                            userInfo: ["message": initialMessage]
                        )
                        onMessageSent()
                    }
                }
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(ConfigurationHandler.shared)
        .environmentObject(ThemeManager.shared)
}
