import SwiftUI

struct SessionsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let session: ChatSession
    let onClose: () -> Void
    let onSessionSelect: (String) -> Void
    
    // Computed property for card background color
    private var cardBackgroundColor: Color {
        colorScheme == .dark ?
        Color(red: 0.15, green: 0.15, blue: 0.18) :
        Color(red: 0.98, green: 0.98, blue: 0.99)
    }
    
    // Format timestamp
    private var formattedTimestamp: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        guard let sessionDate = formatter.date(from: session.updatedAt) else {
            return session.updatedAt
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        
        return displayFormatter.string(from: sessionDate)
    }
    
    // Calculate time ago
    private var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        guard let sessionDate = formatter.date(from: session.updatedAt) else {
            return ""
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(sessionDate)
        
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if hours < 24 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if days == 1 {
            return "Yesterday"
        } else if days < 7 {
            return "\(days) days ago"
        } else {
            return formattedTimestamp
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with close button
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            // Session title and metadata
            VStack(alignment: .leading, spacing: 12) {
                // Session description/title
                Text(session.name.isEmpty ? "Untitled Session" : session.name)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Time ago
                Text(timeAgo)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // Message nodes visualization - based on message count
            if session.messageCount > 0 {
                SimulatedMessageNodesView(messageCount: session.messageCount)
                    .frame(height: 80)
            }
            
            // Session stats
            HStack(spacing: 24) {
                // Message count
                VStack(alignment: .leading, spacing: 4) {
                    Text("MESSAGES")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.92)
                        .foregroundColor(Color(red: 0.56, green: 0.56, blue: 0.66))
                    
                    Text("\(session.messageCount)")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            
            // Action button
            Button(action: {
                onSessionSelect(session.id)
            }) {
                HStack {
                    Text("Open Session")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
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
    }
}

// MARK: - Simulated Message Nodes View (based on message count)
struct SimulatedMessageNodesView: View {
    let messageCount: Int
    @Environment(\.colorScheme) var colorScheme
    
    // Limit the number of dots displayed for performance and visual clarity
    private var displayedDotCount: Int {
        if messageCount <= 20 {
            return messageCount
        } else if messageCount <= 50 {
            // Show every other message
            return messageCount / 2
        } else {
            // Cap at 25 dots maximum
            return min(25, messageCount / 3)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw connecting line
                if displayedDotCount > 1 {
                    Path { path in
                        let startX = geometry.size.width * 0.1
                        let endX = geometry.size.width * 0.9
                        let y = geometry.size.height / 2
                        
                        path.move(to: CGPoint(x: startX, y: y))
                        path.addLine(to: CGPoint(x: endX, y: y))
                    }
                    .stroke(
                        colorScheme == .dark ?
                        Color.white.opacity(0.15) :
                        Color.black.opacity(0.1),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                }
                
                // Draw simulated message nodes
                ForEach(0..<displayedDotCount, id: \.self) { index in
                    let position = nodePosition(for: index, total: displayedDotCount, in: geometry.size)
                    
                    Circle()
                        .fill(nodeColor(for: index))
                        .frame(width: 6, height: 6)
                        .position(position)
                }
            }
        }
    }
    
    // Calculate position for each message node
    private func nodePosition(for index: Int, total: Int, in size: CGSize) -> CGPoint {
        let startX = size.width * 0.1
        let endX = size.width * 0.9
        let availableWidth = endX - startX
        
        let progress = total > 1 ? CGFloat(index) / CGFloat(total - 1) : 0.5
        let x = startX + (availableWidth * progress)
        let y = size.height / 2
        
        return CGPoint(x: x, y: y)
    }
    
    // Simulate alternating user/assistant pattern with occasional system messages
    private func nodeColor(for index: Int) -> Color {
        // First message is typically user, then alternates with assistant
        // Occasionally add a system message (every 7th message)
        if index % 7 == 6 {
            return Color.gray.opacity(0.5) // System message
        } else if index % 2 == 0 {
            return Color.blue.opacity(colorScheme == .dark ? 0.6 : 0.5) // User message
        } else {
            return colorScheme == .dark ?
                Color.white.opacity(0.5) :
                Color.black.opacity(0.3) // Assistant message
        }
    }
}

#Preview {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    
    let calendar = Calendar.current
    let now = Date()
    let twoHoursAgo = calendar.date(byAdding: .hour, value: -2, to: now)!
    
    return ZStack {
        Color(UIColor.systemBackground)
            .ignoresSafeArea()
        
        VStack(spacing: 0) {
            SessionsCard(
                session: ChatSession(
                    id: "123",
                    name: "Building a SwiftUI app with node visualization",
                    messageCount: 42,
                    createdAt: formatter.string(from: twoHoursAgo),
                    updatedAt: formatter.string(from: twoHoursAgo)
                ),
                onClose: {
                    print("Close tapped")
                },
                onSessionSelect: { sessionId in
                    print("Open session: \(sessionId)")
                }
            )
            
            Spacer()
        }
    }
}
