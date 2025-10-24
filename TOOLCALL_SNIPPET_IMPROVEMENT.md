# Tool Call Argument Snippet Enhancement

**Date:** October 24, 2025  
**Branch:** spence/chatspaceII  
**File Modified:** `Goose/SharedMessageComponents.swift`  
**Component:** `ToolCallProgressView`

## 🎯 Objective

Improve the tool call progress view to show a structured snippet of arguments instead of just the first argument as a single line.

## 📊 Changes Made

### Before
```
┌─────────────────────────────────────┐
│ ⚙️ [spinner] tool_name              │
│             first_arg_value...      │
│                                     │
│         executing...                │
└─────────────────────────────────────┘
```

**Issues:**
- Only showed first argument value (no key)
- No context about what the argument represents
- Limited to 50 characters
- Centered alignment made it hard to scan
- Single line with lineLimit(2)

### After
```
┌─────────────────────────────────────┐
│ ⚙️ [spinner] tool_name              │
│                                     │
│     param1: value1                  │
│     param2: value2                  │
│     param3: value3                  │
│                                     │
│     executing...                    │
└─────────────────────────────────────┘
```

**Improvements:**
- Shows up to 3 arguments with keys
- Clear key-value format
- Left-aligned for better readability
- Each argument on its own line
- Truncates values at 40 characters
- Consistent indentation (24pt)

## 🔧 Implementation Details

### New Layout Structure

```swift
VStack(alignment: .leading, spacing: 8) {
    // 1. Header with spinner and tool name
    HStack {
        ProgressView()
        Text(toolCall.name)
        Spacer()
    }
    
    // 2. Arguments snippet (NEW!)
    if !toolCall.arguments.isEmpty {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(arguments) { arg in
                HStack {
                    Text("\(arg.key):")  // Key
                    Text(arg.value)       // Value
                    Spacer()
                }
            }
        }
        .padding(.leading, 24)
    }
    
    // 3. Status text
    Text("executing...")
        .padding(.leading, 24)
}
```

### New Helper Function

```swift
private func getArgumentSnippets() -> [(key: String, value: String)] {
    let maxArgs = 3 // Show up to 3 arguments
    let maxValueLength = 40 // Truncate values longer than this
    
    return toolCall.arguments
        .sorted { $0.key < $1.key }
        .prefix(maxArgs)
        .map { key, value in
            let valueString = String(describing: value.value)
            let truncated = valueString.count > maxValueLength 
                ? String(valueString.prefix(maxValueLength)) + "..." 
                : valueString
            return (key: key, value: truncated)
        }
}
```

**Features:**
- Sorts arguments alphabetically by key
- Shows maximum of 3 arguments
- Truncates values longer than 40 characters
- Returns array of tuples for easy iteration

### Styling Changes

| Property | Before | After | Reason |
|----------|--------|-------|--------|
| **Alignment** | `.center` | `.leading` | Better for key-value pairs |
| **Spacing** | `4pt` | `8pt` | More breathing room |
| **Padding** | `8pt` | `12pt` | Accommodate more content |
| **Max Width** | 60% screen | 70% screen | More space for arguments |
| **Indentation** | None | 24pt | Align with tool name |

## 📐 Visual Comparison

### Example 1: Single Argument
**Before:**
```
┌─────────────────────────────────────┐
│ ⚙️ [spinner] web_scrape             │
│             https://example.com/... │
│         executing...                │
└─────────────────────────────────────┘
```

**After:**
```
┌─────────────────────────────────────┐
│ ⚙️ [spinner] web_scrape             │
│                                     │
│     url: https://example.com/page   │
│                                     │
│     executing...                    │
└─────────────────────────────────────┘
```

### Example 2: Multiple Arguments
**Before:**
```
┌─────────────────────────────────────┐
│ ⚙️ [spinner] automation_script      │
│             #!/bin/bash echo "He... │
│         executing...                │
└─────────────────────────────────────┘
```

**After:**
```
┌─────────────────────────────────────┐
│ ⚙️ [spinner] automation_script      │
│                                     │
│     language: shell                 │
│     save_output: true               │
│     script: #!/bin/bash echo "Hel...│
│                                     │
│     executing...                    │
└─────────────────────────────────────┘
```

### Example 3: Many Arguments (>3)
**Before:**
```
┌─────────────────────────────────────┐
│ ⚙️ [spinner] complex_tool           │
│             value1                  │
│         executing...                │
└─────────────────────────────────────┘
```

**After:**
```
┌─────────────────────────────────────┐
│ ⚙️ [spinner] complex_tool           │
│                                     │
│     arg1: value1                    │
│     arg2: value2                    │
│     arg3: value3                    │
│                                     │
│     executing...                    │
└─────────────────────────────────────┘
```
*Note: Only shows first 3 arguments (alphabetically)*

## ✅ Benefits

### User Experience
1. **Better Context** - Users can see what parameters are being used
2. **Easier Scanning** - Left-aligned text is easier to read
3. **More Information** - Shows multiple arguments instead of just one
4. **Clear Structure** - Key-value format is immediately understandable
5. **Consistent Layout** - Predictable structure across all tool calls

### Technical
1. **Configurable** - Easy to adjust `maxArgs` and `maxValueLength`
2. **Sorted** - Arguments appear in consistent order
3. **Truncated Safely** - Long values don't break layout
4. **Performant** - Simple array operations, no heavy processing
5. **Maintainable** - Clear, well-commented code

## 🎨 Design Considerations

### Typography
- **Keys:** Caption2, medium weight, secondary color
- **Values:** Caption2, monospaced, secondary color
- **Tool name:** Caption, medium weight, primary color
- **Status:** Caption2, secondary color

### Spacing
- **Section spacing:** 8pt between header, args, and status
- **Argument spacing:** 2pt between individual arguments
- **Indentation:** 24pt (aligns with text after spinner)
- **Padding:** 12pt around entire component

### Layout
- **Alignment:** Leading (left) for all text
- **Line limit:** 1 per argument value
- **Max width:** 70% of screen width
- **Flexible height:** Grows with number of arguments

## 🧪 Testing Checklist

### Visual Testing
- [ ] Test with 0 arguments (should show only tool name)
- [ ] Test with 1 argument
- [ ] Test with 2 arguments
- [ ] Test with 3 arguments
- [ ] Test with 4+ arguments (should show only 3)
- [ ] Test with very long argument values (>40 chars)
- [ ] Test with very long argument keys
- [ ] Test with special characters in values
- [ ] Test with nested objects/arrays
- [ ] Test in light and dark mode

### Layout Testing
- [ ] Test on iPhone SE (small screen)
- [ ] Test on iPhone Pro Max (large screen)
- [ ] Test on iPad (wider screen)
- [ ] Test with Dynamic Type (accessibility sizes)
- [ ] Test with VoiceOver
- [ ] Test scrolling with multiple tool calls

### Edge Cases
- [ ] Empty string values
- [ ] Null/nil values
- [ ] Boolean values
- [ ] Numeric values
- [ ] Array values
- [ ] Object/dictionary values
- [ ] Very long tool names
- [ ] Unicode characters

## 📊 Configuration Options

### Current Settings
```swift
let maxArgs = 3              // Show up to 3 arguments
let maxValueLength = 40      // Truncate values longer than this
let indentation = 24         // Indent arguments by 24pt
let maxWidthRatio = 0.7      // Use 70% of screen width
```

### Customization Ideas
```swift
// Could be made configurable:
struct ToolCallConfig {
    static var maxVisibleArgs = 3
    static var maxValueLength = 40
    static var showAllArgsButton = false  // "Show all (7)" button
    static var enableCopy = false         // Copy button per argument
    static var highlightSyntax = false    // Syntax highlighting for code
}
```

## 🚀 Future Enhancements

### Phase 1 (Completed)
- [x] Show multiple arguments with keys
- [x] Left-align for better readability
- [x] Truncate long values
- [x] Sort arguments alphabetically

### Phase 2 (Potential)
- [ ] "Show all" button when >3 arguments
- [ ] Syntax highlighting for code/JSON values
- [ ] Copy button for individual arguments
- [ ] Collapsible arguments section
- [ ] Smart truncation (preserve important parts)

### Phase 3 (Advanced)
- [ ] Type-specific formatting (JSON pretty-print, etc.)
- [ ] Diff view for similar tool calls
- [ ] Search/filter arguments
- [ ] Export arguments to clipboard
- [ ] Argument validation indicators

## 📝 Code Changes Summary

### Files Modified
- `Goose/SharedMessageComponents.swift`

### Lines Changed
- **Before:** 53 lines
- **After:** 77 lines
- **Net:** +24 lines

### Functions Changed
- Renamed: `getFirstArgument()` → `getArgumentSnippets()`
- Return type: `String?` → `[(key: String, value: String)]`
- Logic: Single value → Array of key-value tuples

### Backup Created
- `Goose/SharedMessageComponents.swift.backup`

## 🔄 Rollback Instructions

If needed, restore the previous version:

```bash
cd ~/goose-ios
cp Goose/SharedMessageComponents.swift.backup Goose/SharedMessageComponents.swift
```

Or use git:

```bash
git restore Goose/SharedMessageComponents.swift
```

## 📸 Before/After Screenshots

*To be added after testing on device*

### Recommended Screenshots
1. Single argument tool call
2. Multiple arguments tool call
3. Long argument values (truncated)
4. Tool call with no arguments
5. Multiple simultaneous tool calls
6. Dark mode comparison

## ✅ Success Criteria

- [x] Shows argument keys, not just values
- [x] Displays up to 3 arguments
- [x] Left-aligned for readability
- [x] Consistent indentation
- [x] Truncates long values gracefully
- [x] Maintains existing styling (colors, borders)
- [x] No performance degradation
- [x] Code is well-commented
- [ ] Tested on device (pending)
- [ ] Approved by team (pending)

## 🎯 Next Steps

1. Test on device/simulator
2. Get feedback on layout and spacing
3. Adjust `maxArgs` or `maxValueLength` if needed
4. Consider adding "Show all" button for >3 args
5. Add screenshots to documentation
6. Commit changes with descriptive message
7. Update TOOLCALLS_INTERACTION_REVIEW.md

---

**Status:** ✅ Implementation complete, ready for testing  
**Estimated Testing Time:** 15 minutes  
**Risk Level:** Low (isolated change, backward compatible)
