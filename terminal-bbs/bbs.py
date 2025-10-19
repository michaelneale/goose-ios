#!/usr/bin/env python3
import asyncio
import json
import os
import textwrap
from datetime import datetime

DATA_DIR = os.path.join(os.path.dirname(__file__), 'data')
USERS_FILE = os.path.join(DATA_DIR, 'users.json')
MESSAGES_FILE = os.path.join(DATA_DIR, 'messages.json')
BULLETINS_FILE = os.path.join(DATA_DIR, 'bulletins.json')

WELCOME = r"""
[2J[H
[36m========================================
         Goose Retro BBS (Local)
========================================[0m
"""

MENU = r"""
[33mMain Menu[0m
[1] Message Board
[2] Bulletins
[3] Who's Online
[4] Logoff
Select: """

BOARD_MENU = r"""
[33mMessage Board[0m
[L] List messages
[R] Read message
[P] Post message
[B] Back
Select: """

def ensure_data():
    os.makedirs(DATA_DIR, exist_ok=True)
    if not os.path.exists(USERS_FILE):
        with open(USERS_FILE, 'w') as f:
            json.dump({}, f)
    if not os.path.exists(MESSAGES_FILE):
        with open(MESSAGES_FILE, 'w') as f:
            json.dump([], f)
    if not os.path.exists(BULLETINS_FILE):
        with open(BULLETINS_FILE, 'w') as f:
            json.dump([
                {"title": "Welcome to Goose Retro BBS", "body": "This is a tiny local BBS. Have fun!"},
                {"title": "Tips", "body": "Use netcat: nc localhost 2323"}
            ], f)

ONLINE = set()

class Session:
    def __init__(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        self.reader = reader
        self.writer = writer
        self.addr = writer.get_extra_info('peername')
        self.username = None

    async def send(self, s: str):
        self.writer.write(s.encode())
        await self.writer.drain()

    async def getline(self, prompt: str = '') -> str:
        if prompt:
            await self.send(prompt)
        data = await self.reader.readline()
        return data.decode(errors='ignore').strip()

    async def login(self):
        await self.send(WELCOME)
        await self.send("Do you have an account? (y/n): ")
        have = (await self.getline()).lower()
        if have.startswith('n'):
            await self.signup()
        else:
            await self.signin()

    async def signup(self):
        await self.send("\n[32mSignup[0m\n")
        while True:
            username = await self.getline("Choose username: ")
            if not username:
                continue
            users = load_users()
            if username in users:
                await self.send("Username taken. Try again.\n")
                continue
            password = await self.getline("Choose password: ")
            users[username] = {"password": password, "created": datetime.utcnow().isoformat()}
            save_users(users)
            self.username = username
            ONLINE.add(username)
            await self.send(f"\nWelcome, {username}!\n")
            return

    async def signin(self):
        await self.send("\n[34mLogin[0m\n")
        for _ in range(3):
            username = await self.getline("Username: ")
            password = await self.getline("Password: ")
            users = load_users()
            if users.get(username, {}).get('password') == password:
                self.username = username
                ONLINE.add(username)
                await self.send(f"\nWelcome back, {username}!\n")
                return
            await self.send("Invalid credentials.\n")
        await self.send("Too many attempts. Bye.\n")
        self.writer.close()
        await self.writer.wait_closed()

    async def main_menu(self):
        while self.username:
            choice = (await self.getline(MENU)).strip().lower()
            if choice == '1':
                await self.message_board()
            elif choice == '2':
                await self.bulletins()
            elif choice == '3':
                await self.whos_online()
            elif choice == '4':
                await self.logoff()
                break
            else:
                await self.send("Unknown selection.\n")

    async def message_board(self):
        while True:
            ch = (await self.getline(BOARD_MENU)).strip().lower()
            if ch == 'l':
                msgs = load_messages()
                if not msgs:
                    await self.send("No messages yet.\n")
                else:
                    out = ["\n#  Date (UTC)           From       Subject"]
                    for i, m in enumerate(msgs, 1):
                        out.append(f"{i:2d} {m['ts'][:19]:<20} {m['from'][:10]:<10} {m['subject']}")
                    await self.send("\n".join(out) + "\n")
            elif ch == 'r':
                idx = await self.getline("Read which #: ")
                try:
                    n = int(idx)
                    msgs = load_messages()
                    m = msgs[n-1]
                    wrapped = "\n".join(textwrap.wrap(m['body'], width=70))
                    await self.send(f"\nSubject: {m['subject']}\nFrom: {m['from']}\nDate: {m['ts']}\n\n{wrapped}\n\n")
                except Exception:
                    await self.send("Invalid message number.\n")
            elif ch == 'p':
                subj = await self.getline("Subject: ")
                await self.send("Enter message. End with a single '.' on its own line.\n")
                lines = []
                while True:
                    line = await self.getline()
                    if line == '.':
                        break
                    lines.append(line)
                body = "\n".join(lines)
                msgs = load_messages()
                msgs.append({
                    'subject': subj or '(no subject)',
                    'body': body,
                    'from': self.username,
                    'ts': datetime.utcnow().isoformat()
                })
                save_messages(msgs)
                await self.send("Posted.\n")
            elif ch == 'b':
                return
            else:
                await self.send("Unknown option.\n")

    async def bulletins(self):
        bulls = load_bulletins()
        out = ["\n[35mBulletins[0m"]
        for i, b in enumerate(bulls, 1):
            out.append(f"[{i}] {b['title']}")
        out.append("Select number to read or B to go back: ")
        sel = (await self.getline("\n" + "\n".join(out))).strip().lower()
        if sel == 'b':
            return
        try:
            n = int(sel)
            b = bulls[n-1]
            wrapped = "\n".join(textwrap.wrap(b['body'], width=70))
            await self.send(f"\n{b['title']}\n{'-'*len(b['title'])}\n{wrapped}\n\n")
        except Exception:
            await self.send("Invalid selection.\n")

    async def whos_online(self):
        if not ONLINE:
            await self.send("No one online.\n")
        else:
            names = ", ".join(sorted(ONLINE))
            await self.send(f"Online: {names}\n")

    async def logoff(self):
        await self.send("Goodbye!\n")
        if self.username in ONLINE:
            ONLINE.remove(self.username)
        self.writer.close()
        await self.writer.wait_closed()


def load_users():
    with open(USERS_FILE) as f:
        return json.load(f)

def save_users(users):
    with open(USERS_FILE, 'w') as f:
        json.dump(users, f, indent=2)

def load_messages():
    with open(MESSAGES_FILE) as f:
        return json.load(f)

def save_messages(msgs):
    with open(MESSAGES_FILE, 'w') as f:
        json.dump(msgs, f, indent=2)

def load_bulletins():
    with open(BULLETINS_FILE) as f:
        return json.load(f)

async def handle_client(reader, writer):
    s = Session(reader, writer)
    try:
        await s.login()
        if s.username:
            await s.main_menu()
    except (asyncio.IncompleteReadError, ConnectionResetError):
        pass
    finally:
        if s.username in ONLINE:
            ONLINE.remove(s.username)
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass

async def main(host='127.0.0.1', port=2323):
    ensure_data()
    server = await asyncio.start_server(handle_client, host, port)
    addr = ", ".join(str(sock.getsockname()) for sock in server.sockets)
    print(f"BBS listening on {addr}")
    async with server:
        await server.serve_forever()

if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nShutting down.")
