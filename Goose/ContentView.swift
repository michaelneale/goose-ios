import SwiftUI

struct ContentView: View {
    @State private var isSettingsPresented = false
    @State private var showingSidebar = false
    @State private var showingChat = false
    @State private var initialMessage: String?
    @State private var selectedSessionId: String?
    @State private var sessionName: String = "New Session"
    @State private var cachedSessions: [ChatSession] = [] // Preloaded sessions
    @State private var showSplash = true // Show splash screen on launch
    @EnvironmentObject var configurationHandler: ConfigurationHandler
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            if showSplash {
                SplashScreenView(isActive: $showSplash)
                    .environmentObject(themeManager)
                    .onChange(of: showSplash) { newValue in
                        print("🔄 showSplash changed to: \(newValue)")
                    }
            } else {
        ZStack(alignment: .leading) {
            // Main content - full height edge to edge
            GeometryReader { geometry in
                ZStack {
                    Group {
                        if showingChat {
                            NavigationView {
                                ChatView(showingSidebar: $showingSidebar, initialMessage: initialMessage, sessionIdToLoad: selectedSessionId, sessionName: sessionName)
                                    .id(selectedSessionId ?? initialMessage ?? UUID().uuidString) // Force recreate when session changes
                                    .navigationBarHidden(true)
                            }
                            .navigationViewStyle(.stack) // Ensure proper slide transitions
                        } else {
                            WelcomeView(showingSidebar: $showingSidebar) { text in
                                initialMessage = text
                                selectedSessionId = nil // Starting new chat from welcome screen
                                withAnimation {
                                    showingChat = true
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $isSettingsPresented) {
                        SettingsView()
                            .environmentObject(configurationHandler)
                            .environmentObject(themeManager)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(themeManager.backgroundColor)
                .offset(x: showingSidebar ? 360 : 0)
                .animation(.easeInOut(duration: 0.3), value: showingSidebar)
            }
            .edgesIgnoringSafeArea(.all)
            
            // Sidebar overlay
            if showingSidebar {
                SidebarView(
                    isShowing: $showingSidebar,
                    isSettingsPresented: $isSettingsPresented,
                    cachedSessions: $cachedSessions,
                    onSessionSelect: { sessionId, description in
                        selectedSessionId = sessionId
                        sessionName = description.isEmpty ? "Untitled Session" : description
                        initialMessage = nil
                        withAnimation {
                            showingSidebar = false
                            showingChat = true
                        }
                    }, 
                    onNewSession: {
                        selectedSessionId = nil
                        sessionName = "New Session"
                        initialMessage = nil
                        withAnimation {
                            showingSidebar = false
                            showingChat = true
                        }
                        Task {
                            await preloadSessions()
                        }
                    },
                    onOverview: {
                        withAnimation {
                            showingSidebar = false
                            showingChat = false
                        }
                    }
                )
                .transition(.move(edge: .leading))
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
        .onAppear {
            // Preload sessions on app launch
            Task {
                await preloadSessions()
            }
        }
        } // End of else block
        } // End of outer ZStack
    }
    
    // Preload sessions in background
    private func preloadSessions() async {
        print("📥 Attempting to preload sessions...")
        let fetchedSessions = await GooseAPIService.shared.fetchSessions()
        await MainActor.run {
            // Limit to first 10 sessions for performance
            self.cachedSessions = Array(fetchedSessions.prefix(10))
            print("✅ Preloaded \(self.cachedSessions.count) sessions")
            if self.cachedSessions.isEmpty {
                print("⚠️ No sessions preloaded - server may not be connected or no sessions exist")
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

#Preview {
    ContentView()
        .environmentObject(ConfigurationHandler.shared)
        .environmentObject(ThemeManager.shared)
}
