import SwiftUI

/// Displays an assistant message with optional tool completion pills
struct AssistantMessageView: View {
    let message: Message
    let completedTasks: [CompletedToolCall]
    let sessionName: String
    @State private var showFullText = false
    
    private enum Constants {
        static let cornerRadius: CGFloat = 16
        static let fontSize: CGFloat = 16
        static let padding = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        static let horizontalMargin: CGFloat = 12
        static let maxHeightRatio: CGFloat = 0.7
        static let spacing: CGFloat = 8
    }
    
    private var maxHeight: CGFloat {
        UIScreen.main.bounds.height * Constants.maxHeightRatio
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: Constants.spacing) {
                // Message content (filtered to exclude tool responses and requests)
                if !filteredContent.isEmpty {
                    ForEach(Array(filteredContent.enumerated()), id: \.offset) { _, content in
                        MessageContentView(content: content)
                    }
                }
                
                // Tool completion pills
                if !completedTasks.isEmpty {
                    toolCompletionPills
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Constants.horizontalMargin)
        .sheet(isPresented: $showFullText) {
            FullTextOverlay(content: filteredContent)
        }
    }
    
    /// Filter out tool responses and tool requests (shown as pills instead)
    private var filteredContent: [MessageContent] {
        message.content.filter { content in
            !isToolResponse(content) && !isToolRequest(content)
        }
    }
    
    /// Tool completion pills view
    @ViewBuilder
    private var toolCompletionPills: some View {
        if completedTasks.count == 1 {
            // Single task - navigate directly to output
            singleTaskPill(completedTasks[0])
        } else {
            // Multiple tasks - show combined view
            multipleTasksPill
        }
    }
    
    private func singleTaskPill(_ task: CompletedToolCall) -> some View {
        NavigationLink(destination: TaskOutputDetailView(
            task: task,
            taskNumber: 1,
            sessionName: sessionName,
            messageTimestamp: message.created
        ).environmentObject(ThemeManager.shared)) {
            TaskPillContent(
                icon: "checkmark.circle",
                text: task.toolCall.name
            )
        }
        .buttonStyle(.plain)
    }
    
    private var multipleTasksPill: some View {
        NavigationLink(destination: TaskDetailView(
            message: message,
            completedTasks: completedTasks,
            sessionName: sessionName
        ).environmentObject(ThemeManager.shared)) {
            TaskPillContent(
                icon: "checkmark.circle",
                text: "\(completedTasks.count) Tasks completed"
            )
        }
        .buttonStyle(.plain)
    }
    
    private func isToolResponse(_ content: MessageContent) -> Bool {
        if case .toolResponse = content { return true }
        return false
    }
    
    private func isToolRequest(_ content: MessageContent) -> Bool {
        if case .toolRequest = content { return true }
        return false
    }
}

/// Reusable pill content for task completion
struct TaskPillContent: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.85))
        .cornerRadius(16)
    }
}

/// Displays different types of message content
struct MessageContentView: View {
    let content: MessageContent
    
    var body: some View {
        switch content {
        case .text(let textContent):
            MarkdownText(text: textContent.text)
                .textSelection(.enabled)
            
        case .toolRequest(let toolContent):
            ToolRequestView(toolContent: toolContent)
            
        case .toolResponse:
            EmptyView()
            
        case .toolConfirmationRequest(let toolContent):
            ToolConfirmationView(toolContent: toolContent)
            
        case .summarizationRequested:
            EmptyView()
            
        case .conversationCompacted(let content):
            MarkdownText(text: "📝 \(content.msg)")
                .textSelection(.enabled)
        }
    }
}

#Preview {
    NavigationView {
        ScrollView {
            VStack(spacing: 16) {
                AssistantMessageView(
                    message: Message(role: .assistant, text: "I can help you with that!"),
                    completedTasks: [],
                    sessionName: "Test Session"
                )
                
                AssistantMessageView(
                    message: Message(role: .assistant, text: "Here's some **formatted** text with `code`"),
                    completedTasks: [],
                    sessionName: "Test Session"
                )
            }
            .padding()
        }
    }
}
