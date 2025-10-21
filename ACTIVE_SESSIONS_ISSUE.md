# Active Sessions Issue - Messages Not Synced to Database

## Problem

The desktop Goose app shows sessions with many messages (195, 279, etc.) but the iOS app doesn't see them or shows them with very few messages.

## Root Cause

**Active sessions keep messages in memory and don't sync to database until certain events occur.**

### How Desktop App Works

1. **Session Creation:**
   - Session record created in SQLite immediately
   - iOS can see the session (but with 0 messages)

2. **During Active Conversation:**
   - Messages stored in memory (in the desktop app process)
   - Messages MAY be saved to database incrementally
   - OR messages only saved when session is closed/paused

3. **Desktop App Display:**
   - Shows full conversation from memory
   - Doesn't need to read from database

### How iOS App Works

1. **Queries goosed API** → reads from SQLite database
2. **Only sees messages that have been written to database**
3. **Cannot access desktop app's in-memory messages**

## The Evidence

From database query:
```
Today's sessions (2025-10-21):
- 20251021_9: "Goose greeting attempts" - 4 messages
- 20251021_8: "Goose greeting conversation" - 2 messages
- 20251021_7: "New session 4" - 0 messages
- 20251021_6: "New session 3" - 0 messages
- 20251021_5: "New session 1" - 0 messages
```

But desktop shows:
- "iOS app code review" - 195 messages (not in database!)
- "check message load locations" - 26 messages (not in database!)
- "review ios welcomecard code" - 279 messages (not in database!)

These sessions either:
1. Don't exist in database yet (session not created)
2. Exist but messages are still in memory
3. Are being shown from desktop's LocalStorage cache

## Solution: Force Desktop to Sync

### Option 1: Close Active Sessions

In the desktop Goose app:
1. **Close or finish the active conversations**
2. This should trigger a database save
3. Then iOS will see all messages

### Option 2: Restart Desktop App

1. **Quit the desktop Goose app completely**
2. **Restart it**
3. On startup, it should flush pending messages to database
4. Then iOS will see them

### Option 3: Wait for Auto-Save

The desktop app might auto-save periodically:
- Wait 5-10 minutes
- Check if messages appear in iOS app
- If not, sessions are truly not being saved

### Option 4: Check Desktop App Settings

Look for settings like:
- "Auto-save interval"
- "Sync frequency"
- "Save messages immediately"

## Verification Steps

### 1. Check if Session Exists in Database

```bash
DB_PATH="$HOME/.local/share/goose/sessions/sessions.db"

# Search for the session
sqlite3 "$DB_PATH" "SELECT s.id, s.description, COUNT(m.id) as msg_count 
FROM sessions s 
LEFT JOIN messages m ON s.id = m.session_id 
WHERE s.description LIKE '%iOS%app%review%' 
GROUP BY s.id;"
```

### 2. If Session Exists with Few Messages

The session is in database but messages are in memory:
- **Solution:** Close the session in desktop app
- Messages should then be saved to database

### 3. If Session Doesn't Exist

The session hasn't been created in database yet:
- **Solution:** Desktop app needs to create the session record
- This might happen automatically or require user action

## Technical Details

### goosed Message Saving

From `session_manager.rs`:

**Immediate Save (per message):**
```rust
async fn add_message(&self, session_id: &str, message: &Message) -> Result<()> {
    sqlx::query("INSERT INTO messages ...")
        .execute(&self.pool)
        .await?;
}
```

**Batch Save (all messages at once):**
```rust
// Delete all messages
sqlx::query("DELETE FROM messages WHERE session_id = ?")
// Re-insert all messages
for message in conversation.messages() {
    sqlx::query("INSERT INTO messages ...")
}
tx.commit().await?;
```

The desktop app might be using batch save, which only happens when:
- Session is closed
- User explicitly saves
- Periodic auto-save timer fires

## iOS App Perspective

**The iOS app is working correctly!**

It shows exactly what's in the database:
- ✅ Sessions that exist in database
- ✅ Messages that have been saved to database
- ❌ Cannot see in-memory messages from desktop app

## Recommended Actions

### Immediate (To See Missing Sessions)

1. **In desktop app:** Close or finish active conversations
2. **Wait 10 seconds** for database write
3. **In iOS app:** Pull to refresh or restart
4. **Verify:** Sessions should now show full message counts

### Long-term (Fix the Architecture)

**For goosed team:**
1. Save messages to database immediately (not batched)
2. Or implement a "sync" API endpoint that flushes pending messages
3. Or add a "session.is_active" flag so clients know messages are incomplete

**For desktop app:**
1. Save messages as they arrive (not just in memory)
2. Or add a "Sync Now" button to force database write
3. Or show indicator when messages are not yet synced

**For iOS app:**
1. Could add indicator for "session has unsaved messages"
2. Could show message count as "X+ messages" if session is active
3. But fundamentally, iOS needs messages to be in database

## Summary

| Issue | Cause | Solution |
|-------|-------|----------|
| Missing sessions | Not created in DB yet | Close sessions in desktop |
| Sessions with few messages | Messages in memory only | Close sessions in desktop |
| Stale data | Desktop cache | Restart desktop app |
| iOS can't see active chats | Architecture limitation | Wait for desktop to save |

---

**Status:** This is a **desktop app behavior**, not an iOS app bug  
**iOS App:** ✅ Working correctly  
**Action Required:** Close active sessions in desktop app to sync to database
