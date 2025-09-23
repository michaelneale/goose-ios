import SwiftUI

struct ChatView: View {
    @StateObject private var apiService = GooseAPIService.shared
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var currentStreamTask: URLSessionDataTask?
    @State private var showingErrorDetails = false
    @State private var activeToolCalls: [String: ToolCallWithTiming] = [:]  // Track active tool calls
    @State private var completedToolCalls: [String: CompletedToolCall] = [:] // Track completed tool calls
    @State private var toolCallMessageMap: [String: String] = [:] // Map tool call ID to message ID

    var body: some View {
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
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input Area
            HStack(spacing: 12) {
                TextField("build, solve, create...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
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
            .padding()
        }
        .onAppear {
            Task {
                await apiService.testConnection()
            }
        }
    }

    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty && !isLoading else { return }

        // Add user message
        let userMessage = Message(role: .user, text: trimmedText)
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        // Start streaming response
        startChatStream()
    }

    private func startChatStream() {
        let sessionId = UUID().uuidString

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

                // Add error message
                let errorMessage = Message(
                    role: .assistant,
                    text: """
                        ❌ Error: \(error.localizedDescription)
                        """
                )
                messages.append(errorMessage)
            }
        )
    }

    private func handleSSEEvent(_ event: SSEEvent) {
        switch event {
        case .message(let messageEvent):
            let incomingMessage = messageEvent.message

            // Track tool calls and responses
            for content in incomingMessage.content {
                switch content {
                case .toolRequest(let toolRequest):
                    // Add tool call to active tracking with start time and associate with message
                    activeToolCalls[toolRequest.id] = ToolCallWithTiming(
                        toolCall: toolRequest.toolCall,
                        startTime: Date()
                    )
                    toolCallMessageMap[toolRequest.id] = incomingMessage.id
                case .toolResponse(let toolResponse):
                    // Move from active to completed with result and timing
                    if let activeCall = activeToolCalls.removeValue(forKey: toolResponse.id) {
                        let duration = Date().timeIntervalSince(activeCall.startTime)
                        completedToolCalls[toolResponse.id] = CompletedToolCall(
                            toolCall: activeCall.toolCall,
                            result: toolResponse.toolResult,
                            duration: duration,
                            completedAt: Date()
                        )
                        // Keep the message association
                    }
                default:
                    break
                }
            }

            // Check if this message already exists (by ID)
            print("🚀 ChatView: Received message with ID: '\(incomingMessage.id)'")
            print("🚀 ChatView: Current messages count: \(messages.count)")
            if let existingIndex = messages.firstIndex(where: { $0.id == incomingMessage.id }) {
                // Update existing message by accumulating text content
                var updatedMessage = messages[existingIndex]

                // Combine text content from existing and incoming message
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

                        // Create updated message with accumulated text
                        let combinedText = existingText.text + incomingText.text
                        updatedMessage = Message(
                            role: incomingMessage.role,
                            text: combinedText,
                            created: incomingMessage.created
                        )
                        // Preserve the original server ID
                        updatedMessage = Message(
                            id: incomingMessage.id, role: incomingMessage.role,
                            content: [MessageContent.text(TextContent(text: combinedText))],
                            created: incomingMessage.created, metadata: incomingMessage.metadata)
                    }
                }

                print("🚀 ChatView: Updated existing message at index \(existingIndex)")
                messages[existingIndex] = updatedMessage
            } else {
                // New message - add it to the list
                print("🚀 ChatView: Adding new message with ID: '\(incomingMessage.id)'")
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
            // Clear any remaining active tool calls when stream finishes
            // Move any remaining active calls to completed with timeout status
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
            print("Notification: \(notificationEvent.message)")

        case .ping:
            // Ignore ping events - they're just keep-alives
            break
        }
    }

    private func stopStreaming() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
        isLoading = false
    }
    
    private func getToolCallsForMessage(_ messageId: String) -> [String] {
        // Return tool call IDs that belong to this message
        return toolCallMessageMap.compactMap { (toolCallId, mappedMessageId) in
            mappedMessageId == messageId ? toolCallId : nil
        }.sorted() // Sort for consistent ordering
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
    ChatView()
}
