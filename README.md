# Goose Chat iOS

A native iOS client for the Goose AI Assistant that communicates with the goose-server API.

## Features

- **Real-time Chat**: Stream responses from Goose using Server-Sent Events (SSE)
- **Markdown Support**: Basic markdown rendering for formatted text
- **Tool Integration**: Display tool requests, responses, and permission confirmations
- **Settings**: Configure server URL and authentication
- **Modern UI**: Clean SwiftUI interface with message bubbles

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

1. Open `GooseChat.xcodeproj` in Xcode
2. Build and run the project on your device or simulator
3. Configure the server settings:
   - Tap the gear icon in the top-right corner
   - Enter your Goose server URL (default: `http://127.0.0.1:3000`)
   - Enter your secret key (default: `test`)
   - Tap "Test" to verify the connection
   - Tap "Save" to store the settings

## Architecture

### Core Components

- **GooseAPIService**: Handles API communication and SSE streaming
- **ChatView**: Main chat interface with message list and input
- **MessageBubbleView**: Renders individual messages with markdown support
- **SettingsView**: Configuration interface for server settings
- **Message Models**: Data structures matching the Goose server API

### API Integration

The app integrates with the following Goose server endpoints:

- `POST /reply` - Stream chat responses via Server-Sent Events
- `GET /status` - Test server connectivity
- `POST /confirm` - Handle tool permission confirmations (planned)

### Message Types

The app supports various message content types:

- **Text**: Regular text messages with basic markdown formatting
- **Tool Requests**: Display when Goose wants to use a tool
- **Tool Responses**: Show results of tool execution
- **Tool Confirmations**: Permission requests for tool usage

## Usage

1. Launch the app
2. Configure your server settings if needed
3. Start chatting with Goose by typing in the input field
4. Messages will stream in real-time as Goose responds
5. Tool interactions will be displayed with special formatting

## Development

### Project Structure

```
GooseChat/
├── GooseChatApp.swift          # App entry point
├── ContentView.swift           # Main navigation
├── ChatView.swift              # Chat interface
├── MessageBubbleView.swift     # Message rendering
├── SettingsView.swift          # Configuration
├── Message.swift               # Data models
├── GooseAPIService.swift       # API client
└── Assets.xcassets/           # App assets
```

### Key Features

- **Streaming Support**: Real-time message streaming using URLSessionDataTask
- **Error Handling**: Comprehensive error handling for network issues
- **Markdown Rendering**: Basic support for bold text and inline code
- **Tool Visualization**: Special UI for tool requests and responses
- **Settings Persistence**: UserDefaults for storing server configuration

## Future Enhancements

- [ ] Full markdown rendering with proper library
- [ ] Tool permission handling
- [ ] Session management
- [ ] Message history persistence
- [ ] Push notifications
- [ ] Dark mode support
- [ ] Accessibility improvements

## License

This project follows the same license as the main Goose project.
