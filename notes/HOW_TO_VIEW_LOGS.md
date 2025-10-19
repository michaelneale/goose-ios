# How to View Session Debug Logs

## Quick Steps to See Logs

### 1. Open Xcode
```bash
open Goose.xcodeproj
```

### 2. Make Sure Console is Visible
- In Xcode, go to: **View → Debug Area → Show Debug Area** (or press `Cmd+Shift+Y`)
- Make sure the **Console** tab is selected (bottom right of debug area)

### 3. Clean and Rebuild
- Press `Cmd+Shift+K` (Product → Clean Build Folder)
- Then press `Cmd+B` (Product → Build)

### 4. Run the App
- Select "iPhone 17" or any simulator from the device dropdown
- Press `Cmd+R` (Product → Run)

### 5. Trigger Session Fetch
- In the running app, open the **sidebar** (tap the sidebar icon)
- Watch the Xcode console for output

## What You Should See

The console will show output like this:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 FETCHING SESSIONS
   Trial Mode: false
   Base URL: http://127.0.0.1:62996
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ HTTP 200 - Success!
📥 Raw JSON response (truncated):
{"sessions":[{"id":"abc123...","description":"Meeting schedule check",...}]}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ DECODED 7 SESSIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Session #1:
   ID: abc12345...
   Description: 'Meeting schedule check'
   Computed Title: 'Meeting schedule check • Oct 16, 3:45 PM'
   Message Count: 5
   Created: 2024-10-16T15:45:23.123Z
   Updated: 2024-10-16T15:45:23.123Z
...
```

## If You Don't See Logs

### Check Console Filter
At the bottom of the console, there's a search/filter bar. Make sure:
- It's empty or shows "All Output"
- No filters are active

### Check Scheme Settings
1. Product → Scheme → Edit Scheme
2. Select "Run" on the left
3. Go to "Arguments" tab
4. Make sure no environment variables are suppressing output

### Try Terminal Approach
If Xcode console isn't working, you can view device logs:
```bash
# For simulator
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "Goose"' --level debug
```

## Expected Results

### If Connected to Real Server:
- Trial Mode: **false**
- Base URL: Your actual goosed URL (e.g., `http://127.0.0.1:62996`)
- Sessions will show real data from your database
- You'll see the actual session descriptions and timestamps

### If in Trial Mode:
- Trial Mode: **true**
- Base URL contains "demo-goosed.fly.dev"
- Mock sessions with emoji titles like "📝 Debugging my python app"

## New Title Format

After rebuilding, your sessions will show with time stamps:
- **Today's sessions**: "Meeting schedule check • 3:45 PM"
- **This week**: "Meeting schedule check • Mon 3:45 PM"  
- **Older sessions**: "Meeting schedule check • Oct 16, 3:45 PM"

This should help distinguish between sessions created on the same day!

