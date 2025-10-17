import SwiftUI

struct WelcomeCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Sidebar binding
    @Binding var showingSidebar: Bool
    
    // Animation states
    @State private var displayedText = ""
    @State private var showLogo = false
    @State private var showProgressSection = false
    @State private var progressValue: CGFloat = 0.0
    @State private var showActionsSection = false
    
    // Token data - managed internally
    @State private var tokenCount: Int64 = 0
    private let maxTokens: Int64 = 1_000_000_000 // 1 billion
    
    // Callbacks for animation completion
    var onAnimationComplete: (() -> Void)?
    
    // Computed property for card background color
    private var cardBackgroundColor: Color {
        colorScheme == .dark ?
        Color(red: 0.15, green: 0.15, blue: 0.18) :
        Color(red: 0.98, green: 0.98, blue: 0.99)
    }
    
    // Progress bar colors with better contrast
    private var progressBackgroundColor: Color {
        colorScheme == .dark ?
        Color.white.opacity(0.15) :
        Color.black.opacity(0.1)
    }
    
    private var progressForegroundColor: Color {
        // Use blue for better visibility
        Color.blue
    }
    
    // Computed property for time-aware greeting
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 0..<12:
            return "Good morning!"
        case 12..<17:
            return "Good afternoon!"
        case 17..<21:
            return "Good evening!"
        default:
            return "Good night!"
        }
    }
    
    private var subheading: String {
        "What do you want to do?"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Sidebar toggle button
            HStack {
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
            
            // Greeting text with goose logo
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    // Main greeting - 32px
                    Text(displayedText.components(separatedBy: "\n").first ?? "")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Subheading - 16px with subtle color
                    if displayedText.contains("\n") {
                        Text(displayedText.components(separatedBy: "\n").dropFirst().joined(separator: "\n"))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                
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
            
            // Actions and Apps Section - Placeholder (60px)
            if showActionsSection {
                Color.clear
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
            
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
                    
                    // Progress bar with better visibility
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 6)
                                .fill(progressBackgroundColor)
                                .frame(width: geometry.size.width, height: 4)
                            
                            // Foreground (animated) - BLUE for testing
                            RoundedRectangle(cornerRadius: 6)
                                .fill(progressForegroundColor)
                                .frame(width: geometry.size.width * progressValue, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 48)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .background(
            // Background extension that goes upward
            VStack(spacing: 0) {
                cardBackgroundColor
                    .frame(height: 500)
                    .offset(y: -500)
                
                Spacer()
            }
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0
            )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.12),
            radius: 16,
            x: 0,
            y: 8
        )
        .onAppear {
            startTypewriterEffect()
            // Fetch token count
            Task {
                await fetchTokenCount()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshSessions"))) { _ in
            // Refresh token count when configuration changes
            print("🔄 WelcomeCard: RefreshSessions notification received, refetching insights")
            Task {
                await fetchTokenCount()
            }
        }
    }
    
    // Fetch token count from API - silent failure
    private func fetchTokenCount() async {
        let insights = await GooseAPIService.shared.fetchInsights()
        
        await MainActor.run {
            if let insights = insights {
                tokenCount = insights.totalTokens
                print("✅ WelcomeCard: Fetched token count: \(tokenCount)")
                
                // Update progress bar if it's already visible
                if showProgressSection {
                    let percentage = Double(tokenCount) / Double(maxTokens)
                    withAnimation(.easeOut(duration: 0.8)) {
                        progressValue = CGFloat(min(percentage, 1.0))
                    }
                }
            } else {
                // Silent failure - show 0
                print("⚠️ WelcomeCard: Failed to fetch token count - showing 0")
                tokenCount = 0
                if showProgressSection {
                    withAnimation(.easeOut(duration: 0.8)) {
                        progressValue = 0
                    }
                }
            }
        }
    }
    
    // Typewriter effect for greeting text
    private func startTypewriterEffect() {
        displayedText = ""
        let fullText = "\(greeting)\n\(subheading)"
        
        // Fast typewriter effect - 20ms per character
        for (index, character) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.02) {
                displayedText.append(character)
                
                // When text is complete, show logo
                if displayedText == fullText {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showLogo = true
                    }
                    
                    // Show actions section
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showActionsSection = true
                        }
                    }
                    
                    // Show progress section
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showProgressSection = true
                        }
                        
                        // Animate progress bar with current token count
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            let percentage = Double(tokenCount) / Double(maxTokens)
                            print("Animating progress bar: tokenCount=\(tokenCount), percentage=\(percentage)")
                            withAnimation(.easeOut(duration: 0.8)) {
                                progressValue = CGFloat(min(percentage, 1.0))
                            }
                            
                            // Notify parent that animation is complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                onAnimationComplete?()
                            }
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

#Preview {
    ZStack {
        Color(UIColor.systemBackground)
            .ignoresSafeArea()
        
        VStack(spacing: 0) {
            WelcomeCard(
                showingSidebar: .constant(false)
            )
            
            Spacer()
        }
    }
}
