# iOS Session History UTC Timezone Fix

## Problem
The iOS app was showing sessions on the wrong day because it was comparing dates in local timezone (EDT) while the API returns UTC timestamps.

## Example Issue
- API: `2025-10-21T01:18:01Z` (UTC - Oct 21 at 1:18 AM)
- iOS converted to: `2025-10-20 21:18:01 EDT` (Oct 20 at 9:18 PM)
- iOS showed: **YESTERDAY** ❌
- Should show: **TODAY** ✅

## Solution
Changed all date comparisons to use UTC timezone instead of local timezone.

## Files Changed

### 1. NEW: Goose/CalendarExtensions.swift
Created utility extensions for UTC calendar operations:
- `Calendar.utc` - Returns a calendar configured for UTC
- `Date.startOfDayUTC` - Gets start of day in UTC
- `Date.isSameDayUTC(as:)` - Compares dates in UTC
- `Date.istodayUTC` - Checks if date is today in UTC
- `Date.isYesterdayUTC` - Checks if date is yesterday in UTC

### 2. MODIFIED: Goose/WelcomeCard.swift
Changed 2 occurrences:
- Line 53: `sessionDensity` function
- Line 80: `greeting` function

**Before:**
```swift
let calendar = Calendar.current  // Uses local timezone
```

**After:**
```swift
let calendar = Calendar.utc  // Uses UTC timezone
```

### 3. MODIFIED: Goose/NodeMatrix.swift
Changed 4 occurrences:
- Line 56: `targetDate(for:)` function
- Line 61: `daySessions(for:)` function  
- Line 87: `dateLabel(for:)` function
- Line 682: Preview code

### 4. MODIFIED: Goose/SidebarView.swift
Changed 2 occurrences:
- Line 38: `groupSessionsByDate` function
- Line 75: `formatDateHeader` function

### 5. MODIFIED: Goose.xcodeproj/project.pbxproj
Added CalendarExtensions.swift to the project build system.

## Testing
After building and running the app:
1. Sessions with `updated_at` on Oct 21 UTC should appear in "Today"
2. Sessions with `updated_at` on Oct 20 UTC should appear in "Yesterday"
3. Behavior should now match the desktop app exactly

## Backups
All original files backed up with `.before_utc_fix` extension:
- `WelcomeCard.swift.before_utc_fix`
- `NodeMatrix.swift.before_utc_fix`
- `SidebarView.swift.before_utc_fix`
- `project.pbxproj.before_calendar_ext`

## Rollback
To rollback changes:
```bash
cd ~/goose-ios
cp Goose/WelcomeCard.swift.before_utc_fix Goose/WelcomeCard.swift
cp Goose/NodeMatrix.swift.before_utc_fix Goose/NodeMatrix.swift
cp Goose/SidebarView.swift.before_utc_fix Goose/SidebarView.swift
rm Goose/CalendarExtensions.swift
cp Goose.xcodeproj/project.pbxproj.before_calendar_ext Goose.xcodeproj/project.pbxproj
```
