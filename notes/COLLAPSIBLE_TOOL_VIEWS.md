# Collapsible Tool Views Implementation

## Date: 2025-10-10

## Summary
Made all tool-related views (tool calls, tool requests, and tool confirmations) collapsible in the iOS Goose app to reduce visual clutter and improve conversation readability.

## Problem
Tool calls were taking up too much vertical space in the chat view, making conversations hard to follow. Tool requests and responses showed all details by default, which was overwhelming.

## Solution Implemented

### 1. CollapsibleToolCallView (for completed tool calls)
- **Location**: `MessageBubbleView.swift` lines 506-617
- **Features**:
  - Collapsed by default (`@State private var isExpanded: Bool = false`)
  - Shows compact view: chevron, status icon, tool name, duration, status
  - Expanded view shows: arguments, error details (if failed), result values (if successful), completion timestamp
  - Smooth animation with `withAnimation(.easeInOut(duration: 0.2))`
  - Color coding: green for success, red for failure

### 2. CollapsibleToolRequestView (for tool invocations)
- **Location**: `MessageBubbleView.swift` lines 259-345
- **Features**:
  - Collapsed by default
  - Shows: chevron, wrench icon (orange), tool name, argument count
  - Expanded view shows: formatted argument key-value pairs
  - Maintains orange color theme for tool requests

### 3. CollapsibleToolConfirmationView (for permission requests)
- **Location**: `MessageBubbleView.swift` lines 369-462
- **Features**:
  - **Expanded by default** (since user action is required)
  - Shows: chevron, question mark icon (blue), tool name
  - Collapsed state shows "(action required)" indicator
  - Expanded view shows: permission question, arguments, action buttons
  - Blue color theme for permission requests

### 4. Integration Points
- **ChatView.swift** line 47: Updated to use `CollapsibleToolCallView` instead of `CompletedToolCallView`
- Original view structs (`ToolRequestView`, `ToolConfirmationView`, `CompletedToolCallView`) now proxy to collapsible versions for backward compatibility

## Technical Details

### State Management
- Each collapsible view manages its own `@State` for expansion
- No global state needed - each instance tracks its own collapsed/expanded state

### Visual Design
- Consistent chevron icons across all collapsible views (▶ collapsed, ▼ expanded)
- Color coding by type:
  - Orange: Tool requests
  - Green/Red: Tool responses (success/failure)
  - Blue: Permission requests
- Subtle borders and backgrounds (opacity 0.1-0.3)
- Corner radius: 8px for outer containers, 6px for inner content blocks

### Animation
- All transitions use: `withAnimation(.easeInOut(duration: 0.2))`
- Transition effects: `.opacity.combined(with: .move(edge: .top))`

### Layout
- Max width: 70% of screen width for tool calls, no restriction for requests
- Padding: 8px for main content, 12px horizontal for expanded details
- Arguments displayed with aligned keys (minWidth: 60) for better readability

## Files Modified
1. `Goose/MessageBubbleView.swift` - Added all three collapsible views
2. `Goose/ChatView.swift` - Updated to use CollapsibleToolCallView

## Build Status
✅ Successfully builds without errors
- Tested with: `xcodebuild -scheme Goose -destination 'platform=iOS Simulator,name=iPhone 17'`

## Benefits
1. **Cleaner UI**: Tool details hidden by default reduces visual noise
2. **Better Readability**: Conversations flow more naturally without interruption
3. **User Control**: Users can expand tools they're interested in
4. **Smart Defaults**: Permission requests expand automatically since they need action
5. **Consistent Experience**: All tool-related UI follows the same interaction pattern

## Future Considerations
- Could add a preference to control default expansion state
- Could add "expand all"/"collapse all" buttons for power users
- Could persist expansion state across app launches
- Could add keyboard shortcuts for expand/collapse

## Testing Notes
- Tool calls start collapsed ✓
- Tool requests start collapsed ✓
- Permission requests start expanded ✓
- Smooth animations work correctly ✓
- Content truncation works for long arguments/results ✓
- Build succeeds without warnings ✓
