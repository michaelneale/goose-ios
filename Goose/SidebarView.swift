//
//  SidebarView.swift
//  Goose
//
//  Extracted from ChatView for reuse between WelcomeView and ChatView
//

import SwiftUI

// MARK: - Sidebar View
struct SidebarView: View {
    @Binding var isShowing: Bool
    @Binding var isSettingsPresented: Bool
    @Binding var cachedSessions: [ChatSession]
    let onSessionSelect: (String, String) -> Void
    let onNewSession: () -> Void
    let onOverview: (() -> Void)?
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section: Search + New Session button
            HStack(spacing: 8) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    TextField("Search", text: .constant(""))
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(themeManager.chatInputBackgroundColor.opacity(0.85))
                .cornerRadius(8)
                
                // New session button (+ icon)
                Button(action: {
                    print("🔘 Plus button tapped in sidebar")
                    onNewSession()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(themeManager.primaryTextColor, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 20)
            
            // Scrollable content: Categories + Sessions
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Categories section
                    VStack(alignment: .leading, spacing: 16) {
                        if let onOverview = onOverview {
                            CategoryButton(icon: "square.grid.2x2", title: "Overview") {
                                onOverview()
                            }
                        }
                        CategoryButton(icon: "puzzlepiece.extension", title: "Extensions")
                        CategoryButton(icon: "book.closed", title: "Recipes")
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 16)
                    .padding(.top, 32)
                    .padding(.bottom, 32)
                    
                    // Sessions list
                    LazyVStack(spacing: 0) {
                        if cachedSessions.isEmpty {
                            // Show empty state
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 32))
                                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
                                
                                Text("No sessions yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(themeManager.secondaryTextColor)
                                
                                Text("Start a new conversation")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.vertical, 32)
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(cachedSessions) { session in
                                SessionRowView(session: session)
                                    .environmentObject(themeManager)
                                    .onTapGesture {
                                        onSessionSelect(session.id, session.title)
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isShowing = false
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Bottom section: Theme toggle + Settings
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 16) {
                    // Theme toggle
                    Button(action: {
                        themeManager.isDarkMode.toggle()
                    }) {
                        Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 18))
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Settings button
                    Button(action: {
                        isShowing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isSettingsPresented = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18))
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            Text("Settings")
                                .font(.system(size: 16))
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(themeManager.backgroundColor)
        }
        .frame(width: 360)
        .background(themeManager.backgroundColor)
    }
}

// MARK: - Category Button
struct CategoryButton: View {
    let icon: String
    let title: String
    var action: (() -> Void)? = nil
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: ChatSession
    @EnvironmentObject var themeManager: ThemeManager
    
    var formattedTimestamp: String {
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
        VStack(alignment: .leading, spacing: 8) {
            Text(session.title)
                .font(.system(size: 16))
                .foregroundColor(themeManager.primaryTextColor)
                .lineLimit(2)
            
            Text(formattedTimestamp)
                .font(.system(size: 12))
                .tracking(0.06)
                .foregroundColor(themeManager.primaryTextColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
