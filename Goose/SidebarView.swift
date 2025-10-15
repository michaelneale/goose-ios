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
            HStack {
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

                    // Sessions list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Sessions header
                            HStack {
                                Text("Sessions")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)

                            ForEach(cachedSessions) { session in
                                SessionRowView(session: session)
                                    .onTapGesture {
                                        onSessionSelect(session.id)
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isShowing = false
                                        }
                                    }
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }

                    Spacer()

                    Divider()

                    // Bottom row: Settings button
                    Button(action: {
                        // Close sidebar immediately
                        isShowing = false
                        // Open settings immediately (sheet will present after sidebar closes)
                        isSettingsPresented = true
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
                .frame(width: 280)
                .background(Color(.systemBackground))
                .offset(x: isShowing ? 0 : -280)

                Spacer()
            }
        }
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: ChatSession
    @State private var status: SessionStatus = .idle
    @State private var isLoadingStatus = true
    
    private let detector = SessionActivityDetector()

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(session.lastMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if let date = session.updatedDate {
                    Text(formatDate(date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            if isLoadingStatus {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: status.icon)
                        .font(.system(size: 16))
                        .foregroundColor(statusColor)
                    
                    Text(status.displayText)
                        .font(.system(size: 9))
                        .foregroundColor(statusColor)
                }
                .frame(width: 60)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await loadStatus()
        }
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
    
    private func loadStatus() async {
        isLoadingStatus = true
        
        // Quick timestamp-based detection first (instant)
        let quickStatus = detector.detectStatusFromTimestamp(session)
        await MainActor.run {
            self.status = quickStatus
            self.isLoadingStatus = false
        }
        
        // Only refine idle sessions with SSE check in background
        if quickStatus == .idle {
            let refinedStatus = await detector.detectStatus(for: session, useSSE: true)
            await MainActor.run {
                self.status = refinedStatus
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
