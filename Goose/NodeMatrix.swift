import SwiftUI

struct NodeMatrix: View {
    let sessions: [ChatSession]
    @Environment(\.colorScheme) var colorScheme
    @State private var daysOffset: Int = 0 // 0 = today, 1 = yesterday, etc.
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging: Bool = false
    
    // Get the date for the current offset
    private var targetDate: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -daysOffset, to: Date()) ?? Date()
    }
    
    // Filter sessions for the target day
    private var daySessions: [ChatSession] {
        let calendar = Calendar.current
        
        let filtered = sessions.filter { session in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            
            guard let sessionDate = formatter.date(from: session.updatedAt) else {
                return false
            }
            
            return calendar.isDate(sessionDate, inSameDayAs: targetDate)
        }
        
        return filtered.sorted { session1, session2 in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            guard let date1 = formatter.date(from: session1.updatedAt),
                  let date2 = formatter.date(from: session2.updatedAt) else {
                return false
            }
            return date1 < date2
        }
    }
    
    // Format the date label
    private var dateLabel: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(targetDate) {
            return "Today"
        } else if calendar.isDateInYesterday(targetDate) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: targetDate)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.clear
                
                // Main content
                VStack(spacing: 0) {
                    // Date label header - left aligned
                    HStack {
                        HStack(spacing: 8) {
                            Text(dateLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            // Right indicator (for going to past)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            // Left indicator (only show if not on today)
                            if daysOffset > 0 {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // Node content area - centered
                    GeometryReader { nodeGeometry in
                        ZStack {
                            // Empty state
                            if daySessions.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    
                                    Text("No sessions on \(dateLabel.lowercased())")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            
                            // Draw connections (lines between nodes)
                            if daySessions.count > 1 {
                                Path { path in
                                    for i in 0..<(daySessions.count - 1) {
                                        let startPoint = nodePosition(for: i, session: daySessions[i], in: nodeGeometry.size, allSessions: daySessions)
                                        let endPoint = nodePosition(for: i + 1, session: daySessions[i + 1], in: nodeGeometry.size, allSessions: daySessions)
                                        
                                        path.move(to: startPoint)
                                        path.addLine(to: endPoint)
                                    }
                                }
                                .stroke(
                                    colorScheme == .dark ?
                                    Color.white.opacity(0.15) :
                                    Color.black.opacity(0.1),
                                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                                )
                            }
                            
                            // Draw nodes
                            ForEach(Array(daySessions.enumerated()), id: \.element.id) { index, session in
                                let position = nodePosition(for: index, session: session, in: nodeGeometry.size, allSessions: daySessions)
                                
                                Circle()
                                    .fill(
                                        colorScheme == .dark ?
                                        Color.white.opacity(0.3) :
                                        Color.black.opacity(0.2)
                                    )
                                    .frame(width: 8, height: 8)
                                    .position(position)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .id(daysOffset)
                    .transition(.asymmetric(
                        insertion: .move(edge: dragOffset > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: dragOffset > 0 ? .leading : .trailing).combined(with: .opacity)
                    ))
                    .offset(x: dragOffset)
                    
                    Spacer()
                    
                    // Session count indicator - positioned at bottom
                    if !daySessions.isEmpty {
                        HStack {
                            Text("\(daySessions.count) session\(daySessions.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.6))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    } else {
                        HStack {
                            Text("Swipe left or right")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 30)
                    .updating($isDragging) { value, state, transaction in
                        state = true
                    }
                    .onChanged { value in
                        let horizontalAmount = value.translation.width
                        let verticalAmount = abs(value.translation.height)
                        
                        if abs(horizontalAmount) > verticalAmount {
                            dragOffset = horizontalAmount
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        let horizontalAmount = value.translation.width
                        let verticalAmount = abs(value.translation.height)
                        
                        if abs(horizontalAmount) > verticalAmount {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if abs(horizontalAmount) > threshold {
                                    if horizontalAmount > 0 {
                                        daysOffset += 1
                                    } else if daysOffset > 0 {
                                        daysOffset -= 1
                                    }
                                }
                                
                                dragOffset = 0
                            }
                        } else {
                            dragOffset = 0
                        }
                    }
            )
        }
    }
    
    // Calculate position for each node - centered and better distributed
    private func nodePosition(for index: Int, session: ChatSession, in size: CGSize, allSessions: [ChatSession]) -> CGPoint {
        guard !allSessions.isEmpty else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        
        // Use more conservative padding to keep nodes centered
        let paddingX: CGFloat = size.width * 0.15
        let paddingY: CGFloat = size.height * 0.25
        let availableWidth = size.width - (paddingX * 2)
        let availableHeight = size.height - (paddingY * 2)
        
        if allSessions.count == 1 {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        
        // Parse session times
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        guard let sessionDate = formatter.date(from: session.updatedAt) else {
            return randomPosition(seed: session.id.hashValue, in: size, paddingX: paddingX, paddingY: paddingY)
        }
        
        // Get time range for the day's sessions
        let dates = allSessions.compactMap { formatter.date(from: $0.updatedAt) }
        guard let minDate = dates.min(), let maxDate = dates.max() else {
            return randomPosition(seed: session.id.hashValue, in: size, paddingX: paddingX, paddingY: paddingY)
        }
        
        let timeRange = maxDate.timeIntervalSince(minDate)
        let timeProgress: CGFloat
        
        if timeRange > 0 {
            timeProgress = CGFloat(sessionDate.timeIntervalSince(minDate) / timeRange)
        } else {
            timeProgress = CGFloat(index) / CGFloat(allSessions.count - 1)
        }
        
        // Use session ID for consistent pseudo-random values
        let seed = abs(session.id.hashValue)
        let random1 = sin(Double(seed))
        let random2 = cos(Double(seed) * 1.5)
        let random3 = sin(Double(seed) * 2.3)
        
        // Create time-based clusters with centered distribution
        let clusterCount: CGFloat = 4
        let clusterIndex = floor(timeProgress * clusterCount)
        
        // Base position on cluster center - keep more centered vertically
        let clusterCenterX = (clusterIndex + 0.5) / clusterCount
        let clusterCenterY: CGFloat = 0.5 // Keep at vertical center
        
        // Reduce spread to keep nodes more centered
        let clusterSpreadX: CGFloat = 0.15
        let clusterSpreadY: CGFloat = 0.2
        
        let offsetX = (random1 * 0.5 + 0.5) * clusterSpreadX - (clusterSpreadX / 2)
        let offsetY = (random2 * 0.5 + 0.5) * clusterSpreadY - (clusterSpreadY / 2)
        
        // Add micro-variation
        let microOffsetX = (random3 * 0.5 + 0.5) * 0.03 - 0.015
        let microOffsetY = (sin(random3 * 3) * 0.5 + 0.5) * 0.03 - 0.015
        
        // Calculate final position
        let xProgress = clusterCenterX + offsetX + microOffsetX
        let yProgress = clusterCenterY + offsetY + microOffsetY
        
        // Clamp to bounds
        let x = paddingX + (availableWidth * min(max(xProgress, 0), 1))
        let y = paddingY + (availableHeight * min(max(yProgress, 0), 1))
        
        return CGPoint(x: x, y: y)
    }
    
    // Fallback random position
    private func randomPosition(seed: Int, in size: CGSize, paddingX: CGFloat, paddingY: CGFloat) -> CGPoint {
        let random1 = sin(Double(seed)) * 0.5 + 0.5
        let random2 = cos(Double(seed) * 1.5) * 0.5 + 0.5
        
        let x = paddingX + (size.width - paddingX * 2) * CGFloat(random1)
        let y = paddingY + (size.height - paddingY * 2) * CGFloat(random2)
        
        return CGPoint(x: x, y: y)
    }
}

#Preview {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    
    let calendar = Calendar.current
    let now = Date()
    
    func dateString(daysAgo: Int, hoursAgo: Int, minutesOffset: Int = 0) -> String {
        var date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        date = calendar.date(byAdding: .hour, value: -hoursAgo, to: date)!
        date = calendar.date(byAdding: .minute, value: minutesOffset, to: date)!
        return formatter.string(from: date)
    }
    
    return ZStack {
        Color(UIColor.systemBackground)
            .ignoresSafeArea()
        
        NodeMatrix(sessions: [
            // Today
            ChatSession(id: "1", description: "Early Morning", messageCount: 5, createdAt: dateString(daysAgo: 0, hoursAgo: 8), updatedAt: dateString(daysAgo: 0, hoursAgo: 8)),
            ChatSession(id: "2", description: "Morning", messageCount: 12, createdAt: dateString(daysAgo: 0, hoursAgo: 7, minutesOffset: 30), updatedAt: dateString(daysAgo: 0, hoursAgo: 7, minutesOffset: 30)),
            ChatSession(id: "3", description: "Late Morning", messageCount: 8, createdAt: dateString(daysAgo: 0, hoursAgo: 7), updatedAt: dateString(daysAgo: 0, hoursAgo: 7)),
            ChatSession(id: "4", description: "Noon", messageCount: 3, createdAt: dateString(daysAgo: 0, hoursAgo: 5), updatedAt: dateString(daysAgo: 0, hoursAgo: 5)),
            ChatSession(id: "5", description: "Afternoon", messageCount: 15, createdAt: dateString(daysAgo: 0, hoursAgo: 4), updatedAt: dateString(daysAgo: 0, hoursAgo: 4)),
            ChatSession(id: "6", description: "Evening", messageCount: 7, createdAt: dateString(daysAgo: 0, hoursAgo: 2), updatedAt: dateString(daysAgo: 0, hoursAgo: 2)),
            ChatSession(id: "7", description: "Now", messageCount: 2, createdAt: dateString(daysAgo: 0, hoursAgo: 0), updatedAt: dateString(daysAgo: 0, hoursAgo: 0)),
            
            // Yesterday
            ChatSession(id: "8", description: "Yesterday Morning", messageCount: 10, createdAt: dateString(daysAgo: 1, hoursAgo: 8), updatedAt: dateString(daysAgo: 1, hoursAgo: 8)),
            ChatSession(id: "9", description: "Yesterday Noon", messageCount: 6, createdAt: dateString(daysAgo: 1, hoursAgo: 5), updatedAt: dateString(daysAgo: 1, hoursAgo: 5)),
            ChatSession(id: "10", description: "Yesterday Evening", messageCount: 8, createdAt: dateString(daysAgo: 1, hoursAgo: 2), updatedAt: dateString(daysAgo: 1, hoursAgo: 2)),
            
            // 2 days ago
            ChatSession(id: "11", description: "Two Days Ago", messageCount: 5, createdAt: dateString(daysAgo: 2, hoursAgo: 6), updatedAt: dateString(daysAgo: 2, hoursAgo: 6)),
            ChatSession(id: "12", description: "Two Days Ago PM", messageCount: 4, createdAt: dateString(daysAgo: 2, hoursAgo: 3), updatedAt: dateString(daysAgo: 2, hoursAgo: 3)),
            
            // 3 days ago
            ChatSession(id: "13", description: "Three Days Ago", messageCount: 12, createdAt: dateString(daysAgo: 3, hoursAgo: 7), updatedAt: dateString(daysAgo: 3, hoursAgo: 7)),
            ChatSession(id: "14", description: "Three Days Ago PM", messageCount: 9, createdAt: dateString(daysAgo: 3, hoursAgo: 4), updatedAt: dateString(daysAgo: 3, hoursAgo: 4))
        ])
        .frame(height: 400)
    }
}
