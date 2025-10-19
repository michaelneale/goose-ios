# Goose Retro BBS (Terminal)

A tiny local BBS you can log into from your terminal, for that classic vibe.

Features:
- Login/Signup with simple JSON storage
- Message board: list, read, post
- Bulletins
- Who's online
- ANSI color menus

Quick start (macOS/Linux):

```bash
cd terminal-bbs
python3 -m venv .venv
source .venv/bin/activate
python bbs.py
```

In another terminal, connect with netcat:

```bash
nc 127.0.0.1 2323
```

Notes:
- Data is stored under `terminal-bbs/data` (users.json, messages.json, bulletins.json)
- To stop the server, Ctrl+C in the server terminal
- This is for local fun; not hardened for the internet!

Ideas to extend:
- Telnet/SSH support (e.g., via `telnetlib3` or SSH wrappers)
- ANSI art splash screen
- Sysop commands (kick, broadcast)
- File uploads/downloads (careful with security)
