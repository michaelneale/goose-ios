# Solution: Improve Session Title Display

## Problem
Server is returning sessions with generic/repetitive descriptions like "Meeting schedule check".

## Proposed Solution
Enhance the `ChatSession` title computation to:
1. Detect generic/unhelpful descriptions
2. Fall back to more meaningful alternatives
3. Ensure each session is distinguishable

## Implementation Options:

### Option A: Fallback to Date-based Titles
If description is generic or empty, show "Session from [date]"

```swift
var title: String {
    let genericTitles = ["Meeting schedule check", "Calendar schedule check", "Untitled"]
    
    // Check if description is empty or generic
    if description.isEmpty || genericTitles.contains(description) {
        return "Session from \(formatShortDate(timestamp))"
    }
    
    return description
}

private func formatShortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}
```

### Option B: Truncate and Add Timestamp for Duplicates
Keep the description but add timestamp suffix if it's duplicated

```swift
// In the view where sessions are displayed
// Group by description and add index for duplicates
```

### Option C: Show Message Count for Generic Titles
```swift
var title: String {
    let genericTitles = ["Meeting schedule check", "Calendar schedule check"]
    
    if description.isEmpty {
        return "Untitled Session"
    }
    
    if genericTitles.contains(description) {
        return "\(description) (\(messageCount) messages)"
    }
    
    return description
}
```

## Recommended: Option A + C Combined
Best user experience - shows meaningful info for all cases:

```swift
var title: String {
    // List of generic/template titles that aren't helpful
    let genericTitles = ["Meeting schedule check", "Calendar schedule check", "check"]
    
    // Empty description - fallback to date
    if description.isEmpty {
        return "Session from \(formatShortDate(timestamp))"
    }
    
    // Generic description - add context
    if genericTitles.contains(where: { description.lowercased().contains($0.lowercased()) }) {
        let dateStr = formatShortDate(timestamp)
        return "\(description) • \(dateStr)"
    }
    
    // Good description - use as-is
    return description
}

private func formatShortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d" // e.g., "Oct 16"
    return formatter.string(from: date)
}
```

This will show:
- "Meeting schedule check • Oct 16" (instead of just "Meeting schedule check")
- "Meeting schedule check • Sep 20" (distinguishable from above)
- "Debugging my python app" (good descriptions stay unchanged)
- "Session from Oct 16" (for empty descriptions)

## Implementation
Update the `ChatSession` struct in `ChatView.swift`.

