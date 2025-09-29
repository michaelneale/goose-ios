import SwiftUI

struct ChatView: View {
    @Binding var showingSidebar: Bool
    @StateObject private var apiService = GooseAPIService.shared
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var currentStreamTask: URLSessionDataTask?
    @State private var showingErrorDetails = false
    @State private var activeToolCalls: [String: ToolCallWithTiming] = [:]
    @State private var completedToolCalls: [String: CompletedToolCall] = [:]
    @State private var toolCallMessageMap: [String: String] = [:]
    @State private var currentSessionId: String?

    var body: some View {
        ZStack {
            // Main chat view
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                                
                                // Show tool calls that belong to this message
                                ForEach(getToolCallsForMessage(message.id), id: \.self) { toolCallId in
                                    HStack {
                                        Spacer()
                                        if let activeCall = activeToolCalls[toolCallId] {
                                            ToolCallProgressView(toolCall: activeCall.toolCall)
                                        } else if let completedCall = completedToolCalls[toolCallId] {
                                            CompletedToolCallView(completedCall: completedCall)
                                        }
                                        Spacer()
                                    }
                                    .id("tool-\(toolCallId)")
                                }
                            }

                            // Only show "thinking" indicator if no active tool calls
                            if isLoading && activeToolCalls.isEmpty {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("goose is thinking...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                            
                            // Add bottom padding to account for floating input
                            Spacer()
                                .frame(height: 80)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .onChange(of: messages.count) { _ in scrollToBottom(proxy) }
                    .onChange(of: activeToolCalls.count) { _ in scrollToBottom(proxy) }
                    .onChange(of: completedToolCalls.count) { _ in scrollToBottom(proxy) }
                }
            }
            
            // Floating Input Area
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    
                    // File upload button
                    Button(action: {
                        // TODO: Implement file upload
                        print("File upload tapped")
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    
                    TextField("build, solve, create...", text: $inputText, axis: .vertical)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .lineLimit(1...4)
                        .onSubmit {
                            sendMessage()
                        }

                    Button(action: {
                        if isLoading {
                            stopStreaming()
                        } else {
                            sendMessage()
                        }
                    }) {
                        Image(systemName: isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(
                                isLoading
                                    ? .red
                                    : (inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? .gray : .blue))
                    }
                    .disabled(
                        !isLoading && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Sidebar
            if showingSidebar {
                SidebarView(isShowing: $showingSidebar, onSessionSelect: { sessionId in
                    loadSession(sessionId)
                }, onNewSession: {
                    createNewSession()
                })
            }
        }
        .onAppear {
            Task {
                await apiService.testConnection()
            }
        }
    }
    private func scrollToBottom(_ proxy: Any) {
        var lastId: String?
        
        if let lastMessage = messages.last {
            let toolCallsForLastMessage = getToolCallsForMessage(lastMessage.id)
            if !toolCallsForLastMessage.isEmpty {
                lastId = "tool-\(toolCallsForLastMessage.last!)"
            } else {
                lastId = lastMessage.id
            }
        }
        
        if let scrollId = lastId {
            withAnimation(.easeOut(duration: 0.3)) {
                // TODO: Implement scrolling
            }
        }
    }

    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty && !isLoading else { return }

        let userMessage = Message(role: .user, text: trimmedText)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        startChatStream()
    }

    private func startChatStream() {
        Task {
            do {
                // Create session if we don't have one
                if currentSessionId == nil {
                    let (sessionId, initialMessages) = try await apiService.startAgent(workingDir: "/tmp")
                    print("✅ SESSION CREATED: \(sessionId)")
                    
                    // Load any initial messages from the session
                    if !initialMessages.isEmpty {
                        await MainActor.run {
                            messages = initialMessages
                        }
                    }
                    
                    // Read provider and model from config
                    print("🔧 READING PROVIDER AND MODEL FROM CONFIG")
                    guard let provider = await apiService.readConfigValue(key: "GOOSE_PROVIDER"),
                          let model = await apiService.readConfigValue(key: "GOOSE_MODEL") else {
                        throw APIError.noData
                    }
                    
                    print("🔧 UPDATING PROVIDER TO \(provider) WITH MODEL \(model)")
                    try await apiService.updateProvider(sessionId: sessionId, provider: provider, model: model)
                    print("✅ PROVIDER UPDATED FOR SESSION: \(sessionId)")
                    
                    // Extend the system prompt with iOS-specific context
                    print("🔧 EXTENDING PROMPT FOR SESSION: \(sessionId)")
                    try await apiService.extendSystemPrompt(sessionId: sessionId)
                    print("✅ PROMPT EXTENDED FOR SESSION: \(sessionId)")
                    
                    // Load enabled extensions just like desktop does
                    print("🔧 LOADING ENABLED EXTENSIONS FOR SESSION: \(sessionId)")
                    try await apiService.loadEnabledExtensions(sessionId: sessionId)
                    
                    currentSessionId = sessionId
                }
                
                guard let sessionId = currentSessionId else {
                    throw APIError.invalidResponse
                }

                currentStreamTask = apiService.startChatStreamWithSSE(
                    messages: messages,
                    sessionId: sessionId,
                    workingDirectory: "/tmp",
                    onEvent: { event in
                        handleSSEEvent(event)
                    },
                    onComplete: {
                        isLoading = false
                        currentStreamTask = nil
                    },
                    onError: { error in
                        isLoading = false
                        currentStreamTask = nil

                        print("🚨 Chat Error: \(error)")

                        let errorMessage = Message(
                            role: .assistant,
                            text: "❌ Error: \(error.localizedDescription)"
                        )
                        messages.append(errorMessage)
                    }
                )
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("🚨 Session setup error: \(error)")
                    
                    let errorMessage = Message(
                        role: .assistant,
                        text: "❌ Failed to initialize session: \(error.localizedDescription)"
                    )
                    messages.append(errorMessage)
                }
            }
        }
    }

    private func handleSSEEvent(_ event: SSEEvent) {
        switch event {
        case .message(let messageEvent):
            let incomingMessage = messageEvent.message

            // Track tool calls and responses
            for content in incomingMessage.content {
                switch content {
                case .toolRequest(let toolRequest):
                    activeToolCalls[toolRequest.id] = ToolCallWithTiming(
                        toolCall: toolRequest.toolCall,
                        startTime: Date()
                    )
                    toolCallMessageMap[toolRequest.id] = incomingMessage.id
                case .toolResponse(let toolResponse):
                    if let activeCall = activeToolCalls.removeValue(forKey: toolResponse.id) {
                        let duration = Date().timeIntervalSince(activeCall.startTime)
                        completedToolCalls[toolResponse.id] = CompletedToolCall(
                            toolCall: activeCall.toolCall,
                            result: toolResponse.toolResult,
                            duration: duration,
                            completedAt: Date()
                        )
                    }
                default:
                    break
                }
            }

            if let existingIndex = messages.firstIndex(where: { $0.id == incomingMessage.id }) {
                var updatedMessage = messages[existingIndex]

                if let existingTextContent = updatedMessage.content.first(where: {
                    if case .text = $0 { return true } else { return false }
                }),
                    let incomingTextContent = incomingMessage.content.first(where: {
                        if case .text = $0 { return true } else { return false }
                    })
                {
                    if case .text(let existingText) = existingTextContent,
                        case .text(let incomingText) = incomingTextContent
                    {
                        let combinedText = existingText.text + incomingText.text
                        updatedMessage = Message(
                            id: incomingMessage.id, role: incomingMessage.role,
                            content: [MessageContent.text(TextContent(text: combinedText))],
                            created: incomingMessage.created, metadata: incomingMessage.metadata)
                    }
                }

                messages[existingIndex] = updatedMessage
            } else {
                messages.append(incomingMessage)
            }

        case .error(let errorEvent):
            let errorMessage = Message(
                role: .assistant,
                text: "Error: \(errorEvent.error)"
            )
            messages.append(errorMessage)

        case .finish(let finishEvent):
            print("Stream finished: \(finishEvent.reason)")
            for (id, activeCall) in activeToolCalls {
                let duration = Date().timeIntervalSince(activeCall.startTime)
                completedToolCalls[id] = CompletedToolCall(
                    toolCall: activeCall.toolCall,
                    result: ToolResult(status: "timeout", value: nil, error: "Stream finished"),
                    duration: duration,
                    completedAt: Date()
                )
            }
            activeToolCalls.removeAll()

        case .modelChange(let modelEvent):
            print("Model changed: \(modelEvent.model) (\(modelEvent.mode))")

        case .notification(let notificationEvent):
            // Just ignore notifications silently - they're too verbose for shell output
            break

        case .ping:
            break
        }
    }

    private func stopStreaming() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
        isLoading = false
    }
    
    private func getToolCallsForMessage(_ messageId: String) -> [String] {
        return toolCallMessageMap.compactMap { (toolCallId, mappedMessageId) in
            mappedMessageId == messageId ? toolCallId : nil
        }.sorted()
    }
    
    func loadSession(_ sessionId: String) {
        Task {
            do {
                // Resume the session
                let (resumedSessionId, sessionMessages) = try await apiService.resumeAgent(sessionId: sessionId)
                print("✅ SESSION RESUMED: \(resumedSessionId)")
                print("📝 Loaded \(sessionMessages.count) messages")
                
                // Update all state on main thread at once
                await MainActor.run {
                    // Clear old state
                    activeToolCalls.removeAll()
                    completedToolCalls.removeAll()
                    toolCallMessageMap.removeAll()
                    
                    // Set new state
                    currentSessionId = resumedSessionId
                    messages = sessionMessages
                    print("📊 Messages array now has \(messages.count) messages")
                }
            } catch {
                print("🚨 Failed to load session: \(error)")
                await MainActor.run {
                    let errorMessage = Message(
                        role: .assistant,
                        text: "❌ Failed to load session: \(error.localizedDescription)"
                    )
                    messages.append(errorMessage)
                }
            }
        }
    }
    
    func createNewSession() {
        // Clear all state for a fresh session
        messages.removeAll()
        activeToolCalls.removeAll()
        completedToolCalls.removeAll()
        toolCallMessageMap.removeAll()
        currentSessionId = nil
        isLoading = false
        currentStreamTask = nil
        
        print("🆕 Created new session - cleared all state")
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @Binding var isShowing: Bool
    let onSessionSelect: (String) -> Void
    let onNewSession: () -> Void
    @State private var sessions: [ChatSession] = []
    
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
                    // Header
                    HStack {
                        Text("Sessions")
                            .font(.title2)
                            .fontWeight(.bold)
                        
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
                            ForEach(sessions) { session in
                                SessionRowView(session: session)
                                    .onTapGesture {
                                        onSessionSelect(session.id)
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isShowing = false
                                        }
                                    }
                                Divider()
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // New session button
                    Button(action: {
                        // Create new session
                        onNewSession()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("New Session")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding()
                    }
                    .background(Color(.systemBackground))
                }
                .frame(width: 280)
                .background(Color(.systemBackground))
                .offset(x: isShowing ? 0 : -280)
                
                Spacer()
            }
        }
        .onAppear {
            Task {
                await loadSessions()
            }
        }
    }
    
    private func loadSessions() async {
        let fetchedSessions = await GooseAPIService.shared.fetchSessions()
        await MainActor.run {
            self.sessions = fetchedSessions
        }
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: ChatSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(session.lastMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text(formatDate(session.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
// MARK: - Chat Session Model (matches goosed API)
struct ChatSession: Identifiable, Codable {
    let id: String
    let description: String
    let messageCount: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case description
        case messageCount = "message_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Computed properties for UI display
    var title: String {
        return description.isEmpty ? "Untitled Session" : description
    }
    
    var lastMessage: String {
        return "\(messageCount) message\(messageCount == 1 ? "" : "s")"
    }
    
    var timestamp: Date {
        // Parse the ISO 8601 date string
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: updatedAt) ?? Date()
    }
}

// MARK: - Tool Call Data Structures
struct ToolCallWithTiming {
    let toolCall: ToolCall
    let startTime: Date
}

struct CompletedToolCall {
    let toolCall: ToolCall
    let result: ToolResult
    let duration: TimeInterval
    let completedAt: Date
}

#Preview {
    ChatView(showingSidebar: .constant(false))
}
