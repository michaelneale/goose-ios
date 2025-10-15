# Tool Display Design Sync Plan

## Objective
Bring the tool display design from `design-explorations-main` into the current `fix-tools` branch.
Goal: Cleaner, more minimal consolidated pill approach.

## Current State (fix-tools branch)
- Shows **individual pills** for each completed tool
- Each pill links to `TaskDetailView` with single task
- No dedicated single-task detail view

## Target State (design-explorations-main)
- Shows **consolidated pill** for completed tools
  - Single tool: `[✓ tool_name →]` → links to `TaskOutputDetailView`
  - Multiple tools: `[✓ 3 Tasks completed →]` → links to `TaskDetailView`
- Has dedicated `TaskOutputDetailView` for single tool inspection
- Cleaner, more minimal UI

## Files to Update

### 1. MessageBubbleView.swift
**Current behavior:**
```swift
// Shows each completed tool as individual pill
ForEach(completedTasks, id: \.toolCall.name) { completedTask in
    CompletedToolPillView(completedCall: completedTask, message: message, sessionName: sessionName)
}
```

**Target behavior:**
```swift
// Show consolidated pill based on count
if completedTasks.count == 1 {
    // Single task - link to TaskOutputDetailView
    NavigationLink(destination: TaskOutputDetailView(...)) {
        // Pill UI
    }
} else {
    // Multiple tasks - link to TaskDetailView
    NavigationLink(destination: TaskDetailView(...)) {
        // Pill UI showing "X Tasks completed"
    }
}
```

**Changes needed:**
- [ ] Replace `ForEach` loop with conditional single/multiple display
- [ ] Update single task pill to link to `TaskOutputDetailView`
- [ ] Update multiple tasks pill to show count and link to `TaskDetailView`
- [ ] Update pill styling to match design-explorations-main (check colors, spacing)
- [ ] Remove or update `CompletedToolPillView` struct

### 2. TaskDetailView.swift
**Check if needs updates:**
- [ ] Compare current TaskDetailView with design-explorations-main version
- [ ] Check if navigation bar styling matches
- [ ] Check if breadcrumb display matches
- [ ] Update if differences found

### 3. Add TaskOutputDetailView.swift
**Need to copy from design-explorations-main:**
- [ ] Copy `TaskOutputDetailView` struct (lines 217-510 in design_taskdetail.swift)
- [ ] This provides dedicated single-tool detail view
- [ ] Includes search functionality for output
- [ ] Has proper navigation bar with breadcrumbs

## Implementation Steps

### Step 1: Copy TaskOutputDetailView
- Extract from design-explorations-main
- Add to current branch
- Verify it compiles

### Step 2: Update MessageBubbleView
- Update completed tasks display logic
- Change from individual pills to consolidated pill
- Wire up navigation to correct detail views
- Update styling to match design-explorations-main

### Step 3: Review TaskDetailView
- Compare with design-explorations-main
- Update if needed for consistency

### Step 4: Test
- [ ] Test single tool execution → verify pill → verify drill-down to TaskOutputDetailView
- [ ] Test multiple tools execution → verify pill shows count → verify TaskDetailView shows all
- [ ] Test navigation back buttons work correctly
- [ ] Test breadcrumb navigation
- [ ] Verify styling matches across light/dark themes

## Key Design Principles
1. **Minimal by default**: Don't show tool details in main chat
2. **Progressive disclosure**: Click to see details
3. **Consolidated view**: One pill per message for tools
4. **Clear indication**: Show tool executed but keep UI clean

## Notes
- Active/executing tools remain unchanged (already show progress indicator)
- Only completed tools display changes
- Maintains all functionality, just cleaner presentation
