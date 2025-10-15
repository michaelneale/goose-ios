import SwiftUI

/// Example view showing how to display session status
struct SessionStatusView: View {
    let session: ChatSession
    let status: SessionStatus
    
    var body: some View {
        HStack(spacing: 6) {
            // Status icon with color
            Image(systemName: status.icon)
                .font(.system(size: 10))
                .foregroundColor(statusColor)
            
            // Status text
            Text(status.displayText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .active:
            return .green
        case .idle:
            return .orange
        case .finished:
            return .gray
        }
    }
}

/// Session row with status indicator
struct SessionRowWithStatus: View {
    let session: ChatSession
    @State private var status: SessionStatus = .idle
    @State private var isLoadingStatus = true
    
    private let detector = SessionActivityDetector()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                
                Text(session.lastMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(session.workingDir)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isLoadingStatus {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                SessionStatusView(session: session, status: status)
            }
        }
        .padding(.vertical, 8)
        .task {
            await loadStatus()
        }
    }
    
    private func loadStatus() async {
        isLoadingStatus = true
        
        // First show quick timestamp-based status
        let quickStatus = detector.detectStatusFromTimestamp(session)
        await MainActor.run {
            self.status = quickStatus
            self.isLoadingStatus = false
        }
        
        // Then refine with SSE check if needed (only for uncertain cases)
        if quickStatus == .idle {
            let refinedStatus = await detector.detectStatus(for: session, useSSE: true)
            await MainActor.run {
                self.status = refinedStatus
            }
        }
    }
}

/// Example list view showing sessions with status
struct SessionListWithStatusView: View {
    @State private var sessions: [ChatSession] = []
    @State private var sessionsWithStatus: [SessionWithStatus] = []
    @State private var isLoading = false
    
    private let apiService = GooseAPIService.shared
    private let detector = SessionActivityDetector()
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading sessions...")
                } else if sessionsWithStatus.isEmpty {
                    Text("No sessions found")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(sessionsWithStatus) { sessionWithStatus in
                            NavigationLink(destination: Text("Session Details")) {
                                SessionRow(sessionWithStatus: sessionWithStatus)
                            }
                        }
                    }
                    .refreshable {
                        await loadSessions()
                    }
                }
            }
            .navigationTitle("Sessions")
            .task {
                await loadSessions()
            }
        }
    }
    
    private func loadSessions() async {
        isLoading = true
        
        // Load sessions from API
        let loadedSessions = await apiService.fetchSessions()
        
        // Detect status for each session
        var withStatus: [SessionWithStatus] = []
        
        for session in loadedSessions {
            // Use fast timestamp-based detection first
            let status = detector.detectStatusFromTimestamp(session)
            withStatus.append(SessionWithStatus(session: session, status: status))
        }
        
        await MainActor.run {
            self.sessionsWithStatus = withStatus
            self.isLoading = false
        }
        
        // Optionally refine idle sessions with SSE check in background
        Task {
            await refineIdleSessions()
        }
    }
    
    private func refineIdleSessions() async {
        let idleSessions = sessionsWithStatus.filter { $0.status == .idle }
        
        for sessionWithStatus in idleSessions {
            let refinedStatus = await detector.detectStatus(for: sessionWithStatus.session, useSSE: true)
            
            await MainActor.run {
                if let index = sessionsWithStatus.firstIndex(where: { $0.id == sessionWithStatus.id }) {
                    sessionsWithStatus[index].status = refinedStatus
                }
            }
        }
    }
}

/// Simpler session row component
struct SessionRow: View {
    let sessionWithStatus: SessionWithStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sessionWithStatus.session.title)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(sessionWithStatus.session.messageCount)", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(sessionWithStatus.session.lastMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            SessionStatusView(session: sessionWithStatus.session, status: sessionWithStatus.status)
        }
        .padding(.vertical, 4)
    }
}

#Preview("Session Status Badge") {
    VStack(spacing: 20) {
        SessionStatusView(
            session: ChatSession(
                id: "1",
                description: "Test",
                messageCount: 5,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                workingDir: "/tmp",
                totalTokens: nil,
                inputTokens: nil,
                outputTokens: nil,
                accumulatedTotalTokens: nil,
                accumulatedInputTokens: nil,
                accumulatedOutputTokens: nil,
                scheduleId: nil
            ),
            status: .active
        )
        
        SessionStatusView(
            session: ChatSession(
                id: "1",
                description: "Test",
                messageCount: 5,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                workingDir: "/tmp",
                totalTokens: nil,
                inputTokens: nil,
                outputTokens: nil,
                accumulatedTotalTokens: nil,
                accumulatedInputTokens: nil,
                accumulatedOutputTokens: nil,
                scheduleId: nil
            ),
            status: .idle
        )
        
        SessionStatusView(
            session: ChatSession(
                id: "1",
                description: "Test",
                messageCount: 5,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                workingDir: "/tmp",
                totalTokens: nil,
                inputTokens: nil,
                outputTokens: nil,
                accumulatedTotalTokens: nil,
                accumulatedInputTokens: nil,
                accumulatedOutputTokens: nil,
                scheduleId: nil
            ),
            status: .finished
        )
    }
    .padding()
}
