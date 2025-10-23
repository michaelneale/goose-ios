# Trial Mode Implementation - COMPLETED ✅

## Summary
Implemented a smart trial mode for the Goose iOS app that provides a single persistent session with demo sessions for context.

## Requirements Met

### 1. Welcome Screen Behavior ✅
- **Input always creates NEW sessions** in trial mode
- User can start fresh conversations from welcome screen
- Each message from welcome input creates a brand new session
- No session persistence when typing on welcome screen

### 2. Sidebar Behavior ✅
- **Shows real "Trial Session" at the top** of sessions list
- Displays demo sessions below for context/examples (clearly marked as "Example" and "read-only")
- **Clicking trial session**: Loads the real persistent trial session
- **Clicking demo session**: Shows demo messages (read-only view)

### 3. Session Persistence ✅
- Single trial session ID stored in UserDefaults (`trial_session_id`)
- Session resumes across app launches
- If session can't be resumed (404), creates new one
- Session ID stored for future use

### 4. Demo Session Behavior ✅
- **Viewing demo**: Shows read-only demo messages
- **Typing in demo**: Automatically starts a fresh NEW session
- Demo sessions clearly labeled "(read-only)" in descriptions
- Provides context without confusing users

## Implementation Details

### Files Modified

#### 1. `ChatView.swift`
- **Removed trial logic from `startChatStream()`**
  - Now always creates NEW sessions when called from welcome screen
  - Trial session only managed when explicitly loading via sidebar
  
- **Modified `loadSession()`** to handle demo sessions
  - Detects demo sessions by ID prefix `trial-demo-`
  - **For demo sessions**: Loads mock messages (read-only view)
  - **For trial session**: Loads/creates real persistent session
  - **For normal sessions**: Standard resume behavior

- **Modified `sendMessage()`** to handle demo sessions
  - Detects when user types in a demo session
  - Clears demo session ID to trigger new session creation
  - Seamlessly transitions from demo to new session

- **Kept `getOrCreateTrialSession()` helper**
  - Checks UserDefaults for stored session ID
  - Attempts to resume existing session
  - Creates new session if needed
  - Stores session ID for future use

#### 2. `GooseAPIService.swift`
- **Modified `getMockSessions()`** to include real trial session
  - Checks UserDefaults for `trial_session_id`
  - Adds trial session at TOP if it exists
  - Labeled as "🎯 Trial Session"
  - Demo sessions appear below

## User Experience

### Trial Mode Flow:
1. **First Launch**
   - No stored session
   - Welcome screen input creates new session
   - Session not stored (fresh each time from welcome)
   
2. **Via Sidebar - Trial Session**
   - Shows "🎯 Trial Session" at top
   - Clicking it: loads real persistent trial session
   - Session resumes across app launches
   - Persists via UserDefaults

3. **Via Sidebar - Demo Sessions**
   - Shows 3 example sessions below trial session
   - Labeled "(read-only)" in descriptions
   - Clicking them: shows demo messages
   - Typing in demo: starts NEW session automatically

4. **Session Persistence**
   - Trial session ID stored in UserDefaults
   - Resumes automatically when clicking trial session
   - If server can't find session (404), creates new one
   - Welcome screen always bypasses this logic

## Key Features

### Single Session Logic
- Only ONE real session in trial mode
- All sidebar interactions use this session
- Welcome screen creates throwaway sessions

### Smart Resumption
- Trial session resumes across app launches
- Handles server errors gracefully (creates new on 404)
- UserDefaults persistence is transparent

### Demo Sessions
- Provide context/examples showing what's possible
- Read-only view when clicked
- Seamlessly transition to new session when user types
- No confusion between demo and real data

## Testing Checklist

- [ ] Welcome screen input creates new sessions every time
- [ ] Sidebar shows trial session at top
- [ ] Clicking trial session loads real persistent session
- [ ] Clicking demo session shows demo messages (read-only)
- [ ] Typing in demo session starts NEW session
- [ ] Trial session persists across app restarts
- [ ] Session resumes properly with stored ID
- [ ] Creates new session if resume fails (404)
- [ ] Demo sessions clearly labeled as "(read-only)"

## Code Quality

- ✅ Build succeeds
- ✅ Clean separation of concerns
- ✅ Clear comments explaining behavior
- ✅ Graceful error handling
- ✅ UserDefaults key management
- ✅ Session state management

## Notes

- Trial mode detected by checking if baseURL contains "demo-goosed.fly.dev"
- UserDefaults key: `"trial_session_id"`
- Welcome screen bypasses trial session logic entirely
- Sidebar always uses trial session in trial mode
- Demo sessions are purely UI elements (data still from mock messages)
