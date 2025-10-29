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
    let onSessionSelect: (String) -> Void
    let onNewSession: () -> Void
    let onLoadMore: () async -> Void
    let isLoadingMore: Bool
    let hasMoreSessions: Bool
    
    // Grouping mode state
    @State private var groupByDirectory: Bool = false
    
    // Cached groupings to avoid recomputation on every render
    @State private var cachedGroupedByDate: [(String, [ChatSession])] = []
    @State private var cachedGroupedByDirectory: [(String, [ChatSession])] = []
    @State private var hasWorkingDirs: Bool = false
    
    // Agent management from main branch
    @StateObject private var agentStorage = AgentStorage.shared
    @State private var showingRenameDialog = false
    @State private var agentToRename: AgentConfiguration?
    @State private var newAgentName = ""
    
    // Static ISO8601 formatter to avoid recreating on each computation
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    // Dynamic sidebar width based on device
    private var sidebarWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        if UIDevice.current.userInterfaceIdiom == .pad {
            return screenWidth * 0.5 // 50% on iPad
        } else {
            return screenWidth // 100% on iPhone
        }
    }
    
    // Check if we're on iPad
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // Compute sessions grouped by date
    private func computeGroupedByDate() -> [(String, [ChatSession])] {
        let calendar = Calendar.current  // Use local timezone
        
        // Group sessions by date
        var groups: [Date: [ChatSession]] = [:]
        
        for session in cachedSessions {
            guard let sessionDate = Self.iso8601Formatter.date(from: session.updatedAt) else {
                continue
            }
            
            let startOfDay = calendar.startOfDay(for: sessionDate)
            
            if groups[startOfDay] == nil {
                groups[startOfDay] = []
            }
            groups[startOfDay]?.append(session)
        }
        
        // Sort groups by date (newest first) and format labels
        let sortedGroups = groups.sorted { $0.key > $1.key }
        
        return sortedGroups.map { date, sessions in
            let label = formatDateHeader(date)
            let sortedSessions = sessions.sorted { s1, s2 in
                guard let date1 = Self.iso8601Formatter.date(from: s1.updatedAt),
                      let date2 = Self.iso8601Formatter.date(from: s2.updatedAt) else {
                    return false
                }
                return date1 > date2
            }
            return (label, sortedSessions)
        }
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current  // Use local timezone
        
        if calendar.isDateInToday(date) {
            return "TODAY"
        } else if calendar.isDateInYesterday(date) {
            return "YESTERDAY"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date).uppercased()
        }
    }
    
    // Compute sessions grouped by working directory
    private func computeGroupedByDirectory() -> [(String, [ChatSession])] {
        // Group sessions by working directory
        var groups: [String: [ChatSession]] = [:]
        
        for session in cachedSessions {
            let path = session.groupingPath
            
            if groups[path] == nil {
                groups[path] = []
            }
            groups[path]?.append(session)
        }
        
        // Sort groups by most recent activity (newest first), but put "Unknown" last
        let sortedGroups = groups.sorted { group1, group2 in
            // Always put "Unknown" at the end
            if group1.key == "Unknown" { return false }
            if group2.key == "Unknown" { return true }
            
            // Find the most recent session in each group
            let mostRecent1 = group1.value.compactMap { Self.iso8601Formatter.date(from: $0.updatedAt) }.max()
            let mostRecent2 = group2.value.compactMap { Self.iso8601Formatter.date(from: $0.updatedAt) }.max()
            
            // Sort by most recent activity (newer groups first)
            if let date1 = mostRecent1, let date2 = mostRecent2 {
                return date1 > date2
            }
            // If one has no valid dates, put it after the one that does
            if mostRecent1 != nil { return true }
            if mostRecent2 != nil { return false }
            // Both have no dates, alphabetical fallback
            return group1.key < group2.key
        }
        
        // Return groups with formatted labels and sorted sessions
        return sortedGroups.map { path, sessions in
            // Use the full path for the label in folder mode
            let label = path.uppercased()
            
            // Sort sessions within each group by updated time (newest first)
            let sortedSessions = sessions.sorted { s1, s2 in
                guard let date1 = Self.iso8601Formatter.date(from: s1.updatedAt),
                      let date2 = Self.iso8601Formatter.date(from: s2.updatedAt) else {
                    return false
                }
                return date1 > date2
            }
            
            // Only take the most recent 3 sessions from each folder
            let limitedSessions = Array(sortedSessions.prefix(3))
            
            return (label, limitedSessions)
        }
    }
    
    // Update cached groupings when sessions change
    private func updateGroupings() {
        cachedGroupedByDate = computeGroupedByDate()
        cachedGroupedByDirectory = computeGroupedByDirectory()
        hasWorkingDirs = cachedSessions.contains(where: { $0.workingDir != nil && !$0.workingDir!.isEmpty })
    }
    
    // Get the appropriate grouping based on mode
    private var currentGrouping: [(String, [ChatSession])] {
        return groupByDirectory ? cachedGroupedByDirectory : cachedGroupedByDate
    }

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }

            // Sidebar panel
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with New Session button at top
                    HStack {
                        Button(action: {
                            onNewSession()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))

                    Divider()

                    // Sessions list with placeholders at top
                    GeometryReader { scrollGeometry in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                            // Agent section header
                            HStack(spacing: 12) {
                                Image("ServerIcon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 13, height: 13)
                                    .foregroundColor(.primary)
                                
                                Text("Agents")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            
                            // Agent list
                            if agentStorage.savedAgents.isEmpty {
                                // Empty state
                                VStack(spacing: 8) {
                                    Text("No saved agents")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Text("Configure an agent in Settings to save it")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .padding(.horizontal, 16)
                            } else {
                                ForEach(agentStorage.savedAgents) { agent in
                                    AgentRowView(
                                        agent: agent,
                                        isCurrent: agentStorage.currentAgentId == agent.id,
                                        onTap: {
                                            // Close sidebar first for smooth UX, then switch agent
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                isShowing = false
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                                                ConfigurationHandler.shared.switchToAgent(agent)
                                            }
                                        },
                                        onRename: {
                                            agentToRename = agent
                                            newAgentName = agent.name ?? ""
                                            showingRenameDialog = true
                                        },
                                        onDelete: {
                                            agentStorage.deleteAgent(agent)
                                        }
                                    )
                                    Divider()
                                        .background(Color.gray.opacity(0.2))
                                        .padding(.leading)
                                }
                            }
                            
                            // Spacer below agent list
                            Color.clear
                                .frame(height: 24)
                            
                            // Group by toggle - only show if there are sessions with non-empty working directories
                            if hasWorkingDirs {
                                HStack(spacing: 8) {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            groupByDirectory = false
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 12))
                                            Text("Date")
                                                .font(.system(size: 13, weight: groupByDirectory ? .regular : .semibold))
                                        }
                                        .foregroundColor(groupByDirectory ? .secondary : .primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(groupByDirectory ? Color.clear : Color(.systemGray5))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            groupByDirectory = true
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "folder")
                                                .font(.system(size: 12))
                                            Text("Folder")
                                                .font(.system(size: 13, weight: groupByDirectory ? .semibold : .regular))
                                        }
                                        .foregroundColor(groupByDirectory ? .primary : .secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(groupByDirectory ? Color(.systemGray5) : Color.clear)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            
                            // Spacer to push sessions further down
                            Color.clear
                                .frame(height: 24)
                            
                            // Push sessions to bottom if fewer than 5
                            if cachedSessions.count < 5 {
                                Color.clear
                                    .frame(height: scrollGeometry.size.height * 0.3)
                            }

                            // Grouped sessions with headers (date or directory)
                            ForEach(currentGrouping, id: \.0) { dateLabel, sessions in
                                // Date section header
                                DateSectionHeader(label: dateLabel)
                                
                                // Sessions for this date/directory
                                ForEach(sessions) { session in
                                    SessionRowView(session: session)
                                        .onTapGesture {
                                            onSessionSelect(session.id)
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                isShowing = false
                                            }
                                        }
                                    Divider()
                                        .background(Color.gray.opacity(0.2))
                                        .padding(.leading)
                                }
                            }
                            
                            // Load more indicator at the bottom
                            if hasMoreSessions {
                                Button(action: {
                                    Task {
                                        await onLoadMore()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        if isLoadingMore {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                                .scaleEffect(0.8)
                                            Text("Loading...")
                                                .font(.system(size: 14))
                                        } else {
                                            Image(systemName: "arrow.down.circle")
                                                .font(.system(size: 14))
                                            Text("Load More Sessions")
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .disabled(isLoadingMore)
                                .accessibilityLabel("Load more sessions")
                                .accessibilityHint("Loads the next batch of sessions")
                            }
                        }
                    }
                    }

                    Spacer()

                    Divider()

                    // Bottom row: Settings button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            // Close sidebar with animation
                            isShowing = false
                        }
                        // Open settings after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isSettingsPresented = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)

                            Text("Settings")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(.systemBackground))
                }
                .frame(width: sidebarWidth)
                .background(Color(.systemBackground))
                .offset(x: isShowing ? 0 : -sidebarWidth)
                .animation(.easeInOut(duration: 0.3), value: isShowing)

                // Only add spacer on iPad to show overlay on the right
                if isIPad {
                    Spacer()
                }
            }
        }
        .alert("Rename Agent", isPresented: $showingRenameDialog) {
            TextField("Agent Name", text: $newAgentName)
            Button("Cancel", role: .cancel) {
                agentToRename = nil
                newAgentName = ""
            }
            Button("Save") {
                if let agent = agentToRename {
                    var updated = agent
                    updated.name = newAgentName.isEmpty ? nil : newAgentName
                    agentStorage.saveAgent(updated)
                }
                agentToRename = nil
                newAgentName = ""
            }
        } message: {
            Text("Enter a name for this agent")
        }
        .onAppear {
            // Compute groupings on initial load
            updateGroupings()
        }
        .onChange(of: cachedSessions) { _ in
            // Recompute groupings when sessions change
            updateGroupings()
        }
    }
}

// MARK: - Date Section Header
struct DateSectionHeader: View {
    let label: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: ChatSession
    var showFolder: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Session name with folder inline
                HStack(spacing: 4) {
                    Text(session.title)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    // Show folder name inline if available and enabled
                    if showFolder, let workingDir = session.workingDir, !workingDir.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "folder")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(session.directoryName)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // Time ago
                Text(formatTime(session.updatedAt))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                // Message count with icon
                HStack(spacing: 4) {
                    Image("MessageIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                        .foregroundColor(.secondary)
                    
                    Text("\(session.messageCount)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatTime(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        guard let date = formatter.date(from: isoDate) else {
            return "Unknown"
        }
        
        // Just show time for same-day sessions
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        return timeFormatter.string(from: date)
    }
}

// MARK: - Agent Row View
struct AgentRowView: View {
    let agent: AgentConfiguration
    let isCurrent: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    @State private var showingOptions = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Current indicator
                Circle()
                    .fill(isCurrent ? Color.green : Color.clear)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.displayName)
                        .font(.system(size: 15, weight: isCurrent ? .semibold : .medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    if let subtitle = agent.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Options button
                Button(action: {
                    showingOptions = true
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Agent Options", isPresented: $showingOptions, titleVisibility: .visible) {
            Button("Rename") {
                onRename()
            }
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
