import SwiftUI

struct ChatView: View {
    @Binding var showingSidebar: Bool
    var initialMessage: String? = nil
    var sessionIdToLoad: String? = nil
    var sessionName: String = "New Session"
    @StateObject private var apiService = GooseAPIService.shared
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var currentStreamTask: URLSessionDataTask?
    @State private var showingErrorDetails = false
    @State private var isSettingsPresented = false
    @State private var activeToolCalls: [String: ToolCallWithTiming] = [:]
    @State private var completedToolCalls: [String: CompletedToolCall] = [:]
    @State private var toolCallMessageMap: [String: String] = [:]
    @State private var currentSessionId: String?
    @State private var localCachedSessions: [ChatSession] = [] // Local cached sessions for ChatView's sidebar
    @EnvironmentObject var themeManager: ThemeManager
    
    // Voice features
    @StateObject private var voiceManager = EnhancedVoiceManager()
    
    // Memory management
    private let maxMessages = 50 // Limit messages to prevent memory issues
    private let maxToolCalls = 20 // Limit tool calls to prevent memory issues
    
    // Efficient scroll management
    @State private var scrollTimer: Timer?
    @State private var shouldAutoScroll = true
    @State private var scrollRefreshTrigger = UUID() // Force scroll refresh

    var body: some View {
        ZStack(alignment: .top) {
            // Main chat view
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubbleView(
                                    message: message,
                                    completedTasks: getCompletedTasksForMessage(message.id)
                                )
                                    .environmentObject(themeManager)
                                    .id(message.id)
                                
                                // Show ONLY active/in-progress tool calls (completed ones are in the pill)
                                ForEach(getToolCallsForMessage(message.id), id: \.self) { toolCallId in
                                    if let activeCall = activeToolCalls[toolCallId] {
                                        HStack {
                                            Spacer()
                                            ToolCallProgressView(toolCall: activeCall.toolCall)
                                            Spacer()
                                        }
                                        .id("tool-\(toolCallId)")
                                    }
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
                                .frame(height: 120)
                        }
                        .padding(.horizontal)
                        .padding(.top, 90)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        // Only scroll when app comes to foreground, not on every update
                        if shouldAutoScroll {
                            scrollToBottom(proxy)
                        }
                    }
                    .onChange(of: scrollRefreshTrigger) { _ in
                        // Force scroll when session is loaded
                        if shouldAutoScroll && !messages.isEmpty {
                            scrollToBottom(proxy)
                        }
                    }
                }
            }
            
            // Gradient fade overlay to dim content above the input box
            VStack {
                Spacer()
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color(UIColor.systemBackground).opacity(0.7),
                        Color(UIColor.systemBackground)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
            
            // Floating Input Area
            VStack {
                Spacer()
                
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
                            sendMessage()
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
                                if isLoading {
                                    stopStreaming()
                                } else {
                                    sendMessage()
                                }
                            }) {
                                Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(isLoading ? .white : (themeManager.isDarkMode ? .black : .white))
                                    .frame(width: 32, height: 32)
                                    .background(isLoading ? Color.red : (themeManager.isDarkMode ? Color.white : Color.black))
                                    .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isLoading && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 21)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 21)
                                .fill(themeManager.chatInputBackgroundColor.opacity(0.85))
                        )
                )
                } // End of transcription VStack
                .overlay(
                    RoundedRectangle(cornerRadius: 21)
                        .inset(by: 0.5)
                        .stroke(themeManager.chatInputBorderColor, lineWidth: 0.5)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 0)
            }
            
            // Custom navigation bar with background
            VStack(spacing: 0) {
                // Status bar spacer
                Color.clear
                    .frame(height: 0)
                
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
                    
                    Text(sessionName)
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(themeManager.backgroundColor.opacity(0.95))
            .frame(maxWidth: .infinity, alignment: .top)
            .shadow(color: Color.black.opacity(0.05), radius: 0, y: 1)
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
                        sendMessage()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await apiService.testConnection()
                
                // If we have a session ID to load, load it first
                if let sessionId = sessionIdToLoad, !sessionId.isEmpty {
                    loadSession(sessionId)
                }
                // Otherwise, if we have an initial message from the welcome screen, send it
                else if let message = initialMessage, !message.isEmpty {
                    await MainActor.run {
                        inputText = message
                        sendMessage()
                    }
                }
            }
        }
    }
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
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
                proxy.scrollTo(scrollId, anchor: .bottom)
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

                currentStreamTask = await apiService.startChatStreamWithSSE(
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
        // Only block events if we're explicitly switching sessions
        // Don't block normal streaming operation
        if currentStreamTask == nil {
            print("⚠️ Ignoring SSE event - stream was cancelled")
            return
        }
        
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
                case .summarizationRequested(_):
                    // Handle summarization requests - just log for now
                    print("📝 Summarization requested for message: \(incomingMessage.id)")
                default:
                    break
                }
            }

            // Batch UI updates to reduce frequency
            DispatchQueue.main.async {
                // Double-check we still have an active session before updating UI
                guard self.currentSessionId != nil else {
                    print("⚠️ Ignoring UI update - session was cleared")
                    return
                }
                
                if let existingIndex = self.messages.firstIndex(where: { $0.id == incomingMessage.id }) {
                    var updatedMessage = self.messages[existingIndex]

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

                    self.messages[existingIndex] = updatedMessage
                } else {
                    self.messages.append(incomingMessage)
                    // Manage memory by limiting messages and tool calls
                    self.limitMessages()
                    self.limitToolCalls()
                }
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
    
    private func getCompletedTasksForMessage(_ messageId: String) -> [CompletedToolCall] {
        // Get the message
        guard let message = messages.first(where: { $0.id == messageId }) else {
            print("⚠️ Message \(messageId) not found")
            return []
        }
        
        // Extract tool request IDs from message content
        let toolRequestIds = message.content.compactMap { content -> String? in
            if case .toolRequest(let toolContent) = content {
                return toolContent.id
            }
            return nil
        }
        
        // Look up completed tasks by ID
        let completed = toolRequestIds.compactMap { toolId in
            completedToolCalls[toolId]
        }
        
        if !toolRequestIds.isEmpty {
            print("📊 Message \(messageId.prefix(8))... has \(toolRequestIds.count) tool requests, \(completed.count) completed")
            if completed.count != toolRequestIds.count {
                print("  ⚠️ Missing completions for: \(toolRequestIds.filter { !completedToolCalls.keys.contains($0) })")
            }
        }
        
        return completed
    }
    
    private func reconstructToolCallsFromMessages() {
        print("🔧 Reconstructing tool calls from \(messages.count) messages...")
        
        // Step 1: Collect all tool requests and responses from messages
        var toolRequests: [String: (toolCall: ToolCall, messageId: String)] = [:]
        var toolResponses: [String: ToolResult] = [:]
        
        for message in messages {
            for content in message.content {
                switch content {
                case .toolRequest(let toolRequest):
                    toolRequests[toolRequest.id] = (toolRequest.toolCall, message.id)
                    print("  📥 Found tool request: \(toolRequest.toolCall.name) (ID: \(toolRequest.id))")
                    
                case .toolResponse(let toolResponse):
                    toolResponses[toolResponse.id] = toolResponse.toolResult
                    print("  📤 Found tool response: \(toolResponse.id) - \(toolResponse.toolResult.status)")
                    
                default:
                    break
                }
            }
        }
        
        // Step 2: Match requests with responses and create CompletedToolCall objects
        var reconstructedCount = 0
        for (toolId, requestData) in toolRequests {
            if let result = toolResponses[toolId] {
                // Create CompletedToolCall with placeholder timing
                completedToolCalls[toolId] = CompletedToolCall(
                    toolCall: requestData.toolCall,
                    result: result,
                    duration: 0.0, // Historical - no duration data
                    completedAt: Date() // Use current date as placeholder
                )
                
                // Map tool call to message
                toolCallMessageMap[toolId] = requestData.messageId
                
                reconstructedCount += 1
                print("  ✅ Matched: \(requestData.toolCall.name)")
            } else {
                print("  ⚠️ Unmatched request: \(requestData.toolCall.name) (ID: \(toolId))")
            }
        }
        
        print("📊 Reconstructed \(reconstructedCount) completed tool calls from messages")
        print("📊 completedToolCalls dictionary now has \(completedToolCalls.count) entries")
    }
    
    private func limitMessages() {
        guard messages.count > maxMessages else { return }
        
        // Keep only the most recent messages, but always keep the first message (usually system prompt)
        let messagesToRemove = messages.count - maxMessages
        let startIndex = messages.count > 1 ? 1 : 0 // Keep first message if exists
        
        let removedMessages = Array(messages[startIndex..<startIndex + messagesToRemove])
        messages.removeSubrange(startIndex..<startIndex + messagesToRemove)
        
        // Clean up tool call mappings for removed messages
        for removedMessage in removedMessages {
            toolCallMessageMap = toolCallMessageMap.filter { $0.value != removedMessage.id }
        }
        
        print("🧹 Memory cleanup: removed \(messagesToRemove) old messages")
    }
    
    private func limitToolCalls() {
        // Limit completed tool calls to prevent memory accumulation
        guard completedToolCalls.count > maxToolCalls else { return }
        
        let toolCallsToRemove = completedToolCalls.count - maxToolCalls
        let sortedCalls = completedToolCalls.sorted { $0.value.completedAt < $1.value.completedAt }
        
        for i in 0..<toolCallsToRemove {
            let toolCallId = sortedCalls[i].key
            completedToolCalls.removeValue(forKey: toolCallId)
            toolCallMessageMap.removeValue(forKey: toolCallId)
        }
        
        print("🧹 Tool call cleanup: removed \(toolCallsToRemove) old tool calls")
    }
    
    func loadSession(_ sessionId: String) {
        // CRITICAL: Cancel any existing stream before switching sessions
        if let currentTask = currentStreamTask {
            print("🛑 Cancelling existing stream before session switch")
            currentTask.cancel()
            currentStreamTask = nil
        }
        
        Task {
            do {
                // Resume the session
                let (resumedSessionId, sessionMessages) = try await apiService.resumeAgent(sessionId: sessionId)
                print("✅ SESSION RESUMED: \(resumedSessionId)")
                print("📝 Loaded \(sessionMessages.count) messages")
                
                // Read provider and model from config (same as new session)
                print("🔧 READING PROVIDER AND MODEL FROM CONFIG")
                guard let provider = await apiService.readConfigValue(key: "GOOSE_PROVIDER"),
                      let model = await apiService.readConfigValue(key: "GOOSE_MODEL") else {
                    throw APIError.noData
                }
                
                print("🔧 UPDATING PROVIDER TO \(provider) WITH MODEL \(model)")
                try await apiService.updateProvider(sessionId: resumedSessionId, provider: provider, model: model)
                print("✅ PROVIDER UPDATED FOR RESUMED SESSION: \(resumedSessionId)")
                
                // Extend the system prompt with iOS-specific context (same as new session)
                print("🔧 EXTENDING PROMPT FOR RESUMED SESSION: \(resumedSessionId)")
                try await apiService.extendSystemPrompt(sessionId: resumedSessionId)
                print("✅ PROMPT EXTENDED FOR RESUMED SESSION: \(resumedSessionId)")
                
                // Load enabled extensions just like desktop does (same as new session)
                print("🔧 LOADING ENABLED EXTENSIONS FOR RESUMED SESSION: \(resumedSessionId)")
                try await apiService.loadEnabledExtensions(sessionId: resumedSessionId)
                
                // Update all state on main thread at once
                await MainActor.run {
                    // CRITICAL: Clear ALL old state first to prevent event contamination
                    self.stopStreaming() // This clears currentStreamTask and isLoading
                    activeToolCalls.removeAll()
                    completedToolCalls.removeAll()
                    toolCallMessageMap.removeAll()
                    
                    // Set new state with forced UI refresh
                    currentSessionId = resumedSessionId
                    
                    // Force UI refresh by clearing and setting messages
                    messages.removeAll()
                    messages = sessionMessages
                    
                    print("📊 Messages array now has \(messages.count) messages")
                    print("📊 First message ID: \(messages.first?.id ?? "none")")
                    print("📊 Last message ID: \(messages.last?.id ?? "none")")
                    
                    // 🔧 RECONSTRUCT tool call data from historical messages
                    reconstructToolCallsFromMessages()
                    
                    // Force scroll to bottom after loading
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        shouldAutoScroll = true
                        scrollRefreshTrigger = UUID() // Force UI refresh and scroll
                    }
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
        // CRITICAL: Cancel any existing stream before creating new session
        if let currentTask = currentStreamTask {
            print("🛑 Cancelling existing stream before creating new session")
            currentTask.cancel()
            currentStreamTask = nil
        }
        
        // Clear all state for a fresh session
        messages.removeAll()
        activeToolCalls.removeAll()
        completedToolCalls.removeAll()
        toolCallMessageMap.removeAll()
        currentSessionId = nil
        isLoading = false
        
        print("🆕 Created new session - cleared all state")
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @Binding var isShowing: Bool
    @Binding var isSettingsPresented: Bool
    @Binding var cachedSessions: [ChatSession] // Use cached sessions from parent
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
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(width: 32, height: 32)
                        .background(themeManager.chatInputBackgroundColor.opacity(0.85))
                        .cornerRadius(8)
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
                        CategoryButton(icon: "tray", title: "Inbox")
                        CategoryButton(icon: "checklist", title: "Tasks")
                        CategoryButton(icon: "books.vertical", title: "Library")
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
                // Refresh sessions in background when drawer opens (optional)
                Task {
                    await refreshSessions()
                }
            }
        }
    }
    
    // Optional: Refresh sessions in background when drawer opens
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
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            // Category action
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
        Text(session.title)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(themeManager.primaryTextColor)
            .lineLimit(1)
            .padding(.leading, 20)
            .padding(.trailing, 1)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .environmentObject(ThemeManager.shared)
}
