Great! Now I have the complete picture. Let me provide you with a simple explanation of how tool calls are rendered in this Swift code:

## How Tool Calls are Rendered in the Swift iOS App

Here's how it works simply:

### 1. **Data Structures** (lines 757-767 in ChatView.swift)
- **`ToolCallWithTiming`**: Tracks active/running tool calls with start time
- **`CompletedToolCall`**: Stores finished tool calls with results and duration

### 2. **State Management** (lines 11-13 in ChatView.swift)
```swift
@State private var activeToolCalls: [String: ToolCallWithTiming] = [:]
@State private var completedToolCalls: [String: CompletedToolCall] = [:]
@State private var toolCallMessageMap: [String: String] = [:]
```
- Maps tool call IDs to their status and which message they belong to

### 3. **Event Processing** (lines 339-362 in ChatView.swift)
When SSE events come in:
- **Tool Request**: Creates a new `ToolCallWithTiming` and starts tracking
- **Tool Response**: Moves from `activeToolCalls` to `completedToolCalls` with duration

### 4. **Visual Rendering** (lines 42-53 in ChatView.swift)
```swift
ForEach(getToolCallsForMessage(message.id), id: \.self) { toolCallId in
    HStack {
        Spacer()
        if let activeCall = activeToolCalls[toolCallId] {
            ToolCallProgressView(toolCall: activeCall.toolCall)  // Shows spinner
        } else if let completedCall = completedToolCalls[toolCallId] {
            CompletedToolCallView(completedCall: completedCall)  // Shows result
        }
        Spacer()
    }
}
```

### 5. **UI Components** (in MessageBubbleView.swift)
- **`ToolCallProgressView`** (lines 448-501): Shows a spinning progress indicator with tool name
- **`CompletedToolCallView`** (lines 504-579): Shows checkmark/X with execution time and status

### The Flow:
1. Tool call starts → Add to `activeToolCalls` → Show `ToolCallProgressView` (spinner)
2. Tool completes → Move to `completedToolCalls` → Show `CompletedToolCallView` (✓/✗)
3. Each tool call appears centered below its parent message
4. Shows: tool name, first argument (truncated), duration, and success/failure status

The clever part is it tracks which message each tool belongs to using `toolCallMessageMap`, so tools appear under the right assistant message in the chat.
