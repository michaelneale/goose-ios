import SwiftUI

struct ContentView: View {
    @State private var isSettingsPresented = false
    @State private var showingSidebar = false
    @State private var showingSplash = true
    @State private var hasActiveChat = false
    @State private var initialMessage = ""
    @State private var shouldSendInitialMessage = false
    @State private var selectedSessionId: String?
    @EnvironmentObject var configurationHandler: ConfigurationHandler

    var body: some View {
        if showingSplash {
            // Splash Screen
            SplashScreenView(isActive: $showingSplash)
                .onAppear {
                    // Warm up the demo server if in trial mode (non-blocking)
                    warmUpServer()
                }
        } else {
            NavigationStack {
                if !hasActiveChat {
                    // Welcome View when no active chat
                    WelcomeView(showingSidebar: $showingSidebar, onStartChat: { message in
                        // Start new chat with the message
                        initialMessage = message
                        shouldSendInitialMessage = !message.isEmpty
                        selectedSessionId = nil // Clear session ID for new chat
                        withAnimation {
                            hasActiveChat = true
                        }
                    }, onSessionSelect: { sessionId in
                        // Load existing session
                        selectedSessionId = sessionId
                        withAnimation {
                            hasActiveChat = true
                        }
                    })
                    .navigationBarHidden(true)
                } else {
                    // Chat View when there's an active chat
                    ChatViewWithInitialMessage(
                        showingSidebar: $showingSidebar,
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
                    .sheet(isPresented: $isSettingsPresented) {
                        SettingsView()
                            .environmentObject(configurationHandler)
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
    let initialMessage: String
    let shouldSendMessage: Bool
    let selectedSessionId: String?
    let onMessageSent: () -> Void
    let onBackToWelcome: () -> Void
    
    var body: some View {
        ChatView(showingSidebar: $showingSidebar, onBackToWelcome: onBackToWelcome)
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
}
