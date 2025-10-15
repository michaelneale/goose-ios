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
    let onOverview: () -> Void
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
                
                // Close drawer button (right side)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8) // slight top spacing to align visually with search and safe area
            .padding(.bottom, 20)
            
            // Scrollable content: Categories + Sessions
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Categories section
                    VStack(alignment: .leading, spacing: 16) {
                        CategoryButton(icon: "square.grid.2x2", title: "Overview") {
                            onOverview()
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
                                        onSessionSelect(session.id, session.description)
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isShowing = false
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            
            // Bottom row: Settings and Theme icons
            HStack(spacing: 24) {
                // Settings button
                Button(action: {
                    print("⚙️ Settings button tapped")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                    // Small delay to let sidebar close before showing sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isSettingsPresented = true
                        print("⚙️ isSettingsPresented set to: \(isSettingsPresented)")
                    }
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 20))
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                
                // Theme toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        themeManager.isDarkMode.toggle()
                    }
                }) {
                    Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 20))
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(themeManager.backgroundColor)
        }
        .frame(width: 360)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(themeManager.backgroundColor)
        .onChange(of: isShowing) { newValue in
            if newValue {
                // Refresh sessions in background when drawer opens
                Task {
                    await refreshSessions()
                }
            }
        }
    }
    
    // Refresh sessions in background when drawer opens
    private func refreshSessions() async {
        print("🔄 Attempting to refresh sessions...")
        let fetchedSessions = await GooseAPIService.shared.fetchSessions()
        await MainActor.run {
            // Update cached sessions with latest data (limit to 10)
            cachedSessions = Array(fetchedSessions.prefix(10))
            print("🔄 Refreshed \(cachedSessions.count) sessions from API")
            if cachedSessions.isEmpty {
                print("⚠️ No sessions found - make sure server is connected and has sessions")
            }
        }
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 18))
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
    
    var body: some View {
        Text(session.description.isEmpty ? "Session \(session.id.prefix(8))" : session.description)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(themeManager.primaryTextColor)
            .lineLimit(1)
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
