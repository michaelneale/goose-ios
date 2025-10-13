//
//  WelcomeView.swift
//  Goose
//
//  Created by Thomas Petersen on 10/9/25.
//

import SwiftUI

struct WelcomeView: View {
    @Binding var showingSidebar: Bool
    @State private var inputText = ""
    @EnvironmentObject var themeManager: ThemeManager
    var onStartChat: (String) -> Void
    
    // Voice features
    @StateObject private var voiceManager = EnhancedVoiceManager()
    
    // New states for enhanced welcome view
    @State private var recentSessions: [ChatSession] = []
    @State private var isLoadingSessions = true
    @State private var tokenProgress: CGFloat = 0.0 // Animate from 0 to actual value
    private let totalTokens: Double = 100000 // Fake total tokens
    private let usedTokens: Double = 45000 // Fake used tokens (45%)
    
    // Animation states
    @State private var displayedText = ""
    @State private var showTokensSection = false
    @State private var showSessionsTitle = false
    @State private var visibleSessionsCount = 0
    @State private var showLogo = false
    private let fullText = "Morning Spence!\nWhat do you want to do?"
    
    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar with background
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSidebar.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 22))
                            .foregroundColor(themeManager.primaryTextColor)
                            .frame(width: 24, height: 22)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 66)
                .padding(.bottom, 8)
            }
            .background(themeManager.backgroundColor.opacity(0.95))
            .shadow(color: Color.black.opacity(0.05), radius: 0, y: 1)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Greeting text with goose logo
                    HStack(alignment: .top, spacing: 16) {
                        Text(displayedText)
                            .font(.system(size: 20, weight: .medium))
                            .lineSpacing(6)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Spacer()
                        
                        if showLogo {
                            Image("GooseLogo")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(themeManager.primaryTextColor)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 32)
                    
                    // Tokens Used Section
                    if showTokensSection {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TOKENS USED")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.02)
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.66))
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background - light gray for both themes
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(themeManager.isDarkMode ? Color(red: 0.10, green: 0.10, blue: 0.13) : Color(red: 0.95, green: 0.95, blue: 0.95))
                                        .frame(height: 12)
                                    
                                    // Foreground (animated) - white in dark mode, black in light mode
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(themeManager.isDarkMode ? Color.white : Color.black)
                                        .frame(width: geometry.size.width * tokenProgress, height: 12)
                                }
                            }
                            .frame(height: 12)
                        }
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Recent Sessions Section
                    VStack(alignment: .leading, spacing: 16) {
                        if showSessionsTitle {
                            Text("RECENT SESSIONS")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.02)
                                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.66))
                                .padding(.top, 16)
                        }
                        
                        if isLoadingSessions && showSessionsTitle {
                            // Loading state
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(themeManager.secondaryTextColor)
                                Spacer()
                            }
                            .frame(height: 100)
                        } else if recentSessions.isEmpty && showSessionsTitle {
                            // Empty state
                            Text("No recent sessions")
                                .font(.system(size: 14))
                                .foregroundColor(themeManager.secondaryTextColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 32)
                        } else {
                            // Session list - show sessions one by one
                            VStack(spacing: 24) {
                                ForEach(Array(recentSessions.prefix(3).enumerated()), id: \.element.id) { index, session in
                                    if index < visibleSessionsCount {
                                        WelcomeSessionRowView(session: session)
                                            .environmentObject(themeManager)
                                            .transition(.opacity)
                                            .onTapGesture {
                                                // Load the session when tapped
                                                print("Selected session: \(session.id)")
                                                onStartChat("") // This will trigger navigation to chat
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
            
            // Bottom input area
            VStack(spacing: 0) {
                // Show transcribed text while in voice mode
                if voiceManager.voiceMode != .normal && !voiceManager.transcribedText.isEmpty {
                    HStack {
                        Text("Transcribing: \"\(voiceManager.transcribedText)\"")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .background(themeManager.backgroundColor.opacity(0.95))
                }
                
            VStack(alignment: .leading, spacing: 12) {
                // Text field on top
                TextField("I want to...", text: $inputText, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.chatInputTextColor)
                    .lineLimit(1...4)
                    .padding(.vertical, 8)
                    .disabled(voiceManager.voiceMode != .normal)
                    .onSubmit {
                        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onStartChat(inputText)
                        }
                    }
                
                // Buttons row at bottom
                HStack(spacing: 10) {
                    // Plus button - file attachment
                    Button(action: {
                        print("File attachment tapped")
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.chatInputIconColor)
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .inset(by: 0.5)
                                    .stroke(themeManager.chatInputButtonBorderColor, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        // Puzzle icon - extensions
                        Button(action: {
                            print("Extensions tapped")
                        }) {
                            Image(systemName: "puzzlepiece.extension")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeManager.chatInputIconColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .inset(by: 0.5)
                                        .stroke(themeManager.chatInputButtonBorderColor, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        // Auto selector - LLM dropdown
                        Button(action: {
                            print("LLM selector tapped")
                        }) {
                            HStack(spacing: 5) {
                                Text("Auto")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(themeManager.chatInputIconColor)
                                
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(themeManager.chatInputIconColor)
                            }
                            .padding(.horizontal, 10)
                            .frame(width: 84, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .inset(by: 0.5)
                                    .stroke(themeManager.chatInputButtonBorderColor, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Voice mode indicator text
                        if voiceManager.voiceMode != .normal {
                            Text(voiceManager.voiceMode == .audio ? "Transcribe" : "Full Audio")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.isDarkMode ? .blue : .blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                        
                        // Wave - audio/voice button
                        Button(action: {
                            // Cycle through voice modes
                            voiceManager.cycleVoiceMode()
                        }) {
                            Image(systemName: voiceManager.voiceMode == .normal ? "waveform" : "waveform.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(voiceManager.voiceMode == .normal ? themeManager.chatInputIconColor : .blue)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .inset(by: 0.5)
                                        .stroke(themeManager.chatInputButtonBorderColor, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        // Send button - always solid with inverted arrow
                        Button(action: {
                            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onStartChat(inputText)
                            }
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(themeManager.isDarkMode ? .black : .white)
                                .frame(width: 32, height: 32)
                                .background(themeManager.isDarkMode ? Color.white : Color.black)
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        .allowsHitTesting(!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 21)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 21)
                            .fill(themeManager.chatInputBackgroundColor.opacity(0.85))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 21)
                    .inset(by: 0.5)
                    .stroke(themeManager.chatInputBorderColor, lineWidth: 0.5)
            )
            } // End of transcription VStack
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .onChange(of: voiceManager.transcribedText) { newText in
            // Update input text with transcribed text
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
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onStartChat(inputText)
                    }
                }
            }
        }
        .onAppear {
            // Start typewriter animation
            startTypewriterEffect()
            
            // Load recent sessions
            Task {
                await loadRecentSessions()
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
                    
                    // Show tokens section after logo
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showTokensSection = true
                        }
                        
                        // Animate progress bar
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeOut(duration: 0.8)) {
                                tokenProgress = CGFloat(usedTokens / totalTokens)
                            }
                        }
                        
                        // Show sessions title
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showSessionsTitle = true
                            }
                            
                            // Show sessions one by one quickly (100ms between each)
                            for i in 0..<3 {
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
    }
    
    // Load recent sessions from API
    private func loadRecentSessions() async {
        isLoadingSessions = true
        
        // Simulate delay for loading animation
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let sessions = await GooseAPIService.shared.fetchSessions()
        
        await MainActor.run {
            recentSessions = Array(sessions.prefix(3))
            isLoadingSessions = false
        }
    }
}

// MARK: - Welcome Session Row View
struct WelcomeSessionRowView: View {
    let session: ChatSession
    @EnvironmentObject var themeManager: ThemeManager
    
    var formattedTimestamp: String {
        let now = Date()
        let sessionDate = session.timestamp
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
            Text(session.title)
                .font(.system(size: 16))
                .foregroundColor(themeManager.primaryTextColor)
            
            Text(formattedTimestamp)
                .font(.system(size: 12))
                .tracking(0.06)
                .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    WelcomeView(showingSidebar: .constant(false)) { text in
        print("Starting chat with: \(text)")
    }
    .environmentObject(ThemeManager.shared)
}

