import Combine
import Foundation

class GooseAPIService: ObservableObject {
    static let shared = GooseAPIService()

    @Published var isConnected = false
    @Published var connectionError: String?
    
    // The configured URL (unchanging) - either direct URL or ntfy pattern
    private var baseURL: String {
        UserDefaults.standard.string(forKey: "goose_base_url") ?? "http://127.0.0.1:62996"
    }
    
    // Is the configured URL an ntfy pattern?
    private var isNtfyPattern: Bool {
        baseURL.contains("ntfy.sh")
    }
    
    // The resolved URL - cached and refreshable for ntfy patterns
    private var cachedResolvedURL: String?
    
    private var resolvedURL: String {
        // If we have a cached resolved URL, use it
        if let cached = cachedResolvedURL {
            return cached
        }
        
        // For non-ntfy URLs, resolved == base (and cache it)
        if !isNtfyPattern {
            cachedResolvedURL = baseURL
        }
        
        // For ntfy patterns, return base URL as initial value
        // (will be resolved on first failure and then cached)
        return baseURL
    }
    
    private var secretKey: String {
        UserDefaults.standard.string(forKey: "goose_secret_key") ?? "test"
    }

    private init() {}
    
    // MARK: - Request Helper with Auto-Refresh
    
    /// Executes a request, and if it fails, refreshes from ntfy and retries once
    private func performRequest<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            // Try to refresh and retry
            print("🔄 Request failed, attempting to refresh from ntfy.sh...")
            if await refreshFromNtfy() {
                print("✅ Refreshed, retrying request...")
                return try await operation()
            }
            // If refresh failed or not ntfy pattern, throw original error
            throw error
        }
    }
    
    // MARK: - Proper SSE Streaming Implementation
    func startChatStreamWithSSE(
        messages: [Message],
        sessionId: String? = nil,
        workingDirectory: String = "/tmp",
        onEvent: @escaping (SSEEvent) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void,
        isRetry: Bool = false
    ) async -> URLSessionDataTask? {

        guard let url = URL(string: "\(resolvedURL)/reply") else {
            onError(APIError.invalidURL)
            return nil
        }

        let request = ChatRequest(
            messages: messages,
            sessionId: sessionId,
            sessionWorkingDir: workingDirectory,
            scheduledJobId: nil
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let requestData = try JSONEncoder().encode(request)
            urlRequest.httpBody = requestData

            // Debug logging
            print("🚀 Starting SSE stream to: \(url)\(isRetry ? " (RETRY)" : "")")
            print("🚀 Session ID: \(sessionId ?? "nil")")
            print("🚀 Number of messages: \(messages.count)")
            print("🚀 Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
            if let bodyString = String(data: requestData, encoding: .utf8) {
                print("🚀 Request body:")
                if let jsonData = bodyString.data(using: .utf8),
                    let prettyJson = try? JSONSerialization.jsonObject(with: jsonData),
                    let prettyData = try? JSONSerialization.data(
                        withJSONObject: prettyJson, options: .prettyPrinted),
                    let prettyString = String(data: prettyData, encoding: .utf8)
                {
                    print(prettyString)
                } else {
                    print(bodyString)
                }
            }
        } catch {
            onError(error)
            return nil
        }

        // Create a retry handler that refreshes from ntfy and retries
        let retryHandler: (Error) -> Void = { [weak self] error in
            guard let self = self, !isRetry else {
                // Already retried once, don't retry again
                onError(error)
                return
            }
            
            // If this is a potential connection error and we're using ntfy, try to refresh
            Task {
                print("🔄 SSE request failed, attempting to refresh from ntfy.sh...")
                if await self.refreshFromNtfy() {
                    print("✅ Refreshed, retrying SSE stream...")
                    _ = await self.startChatStreamWithSSE(
                        messages: messages,
                        sessionId: sessionId,
                        workingDirectory: workingDirectory,
                        onEvent: onEvent,
                        onComplete: onComplete,
                        onError: onError,
                        isRetry: true  // Mark as retry to prevent infinite loops
                    )
                } else {
                    // Refresh failed, pass error back to caller
                    onError(error)
                }
            }
        }

        // Create a custom URLSessionDataDelegate to handle streaming
        let delegate = SSEDelegate(
            onEvent: onEvent,
            onComplete: onComplete,
            onError: retryHandler
        )

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: urlRequest)

        // Store the delegate reference to prevent deallocation
        objc_setAssociatedObject(task, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        task.resume()
        return task
    }

    // MARK: - Connection Test
    func testConnection() async -> Bool {
        let fullURL = "\(resolvedURL)/status"
        print("🔍 Testing connection to: '\(fullURL)'")
        print("   Base URL: '\(baseURL)'")
        print("   Resolved URL: '\(resolvedURL)'")
        print("   Secret key length: \(secretKey.count)")
        
        guard let url = URL(string: fullURL) else {
            print("❌ Failed to create URL from: '\(fullURL)'")
            await MainActor.run {
                self.connectionError = "Invalid URL: \(fullURL)"
                self.isConnected = false
            }
            return false
        }

        var request = URLRequest(url: url)
        request.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                let connected = httpResponse.statusCode == 200
                await MainActor.run {
                    self.isConnected = connected
                    if connected {
                        self.connectionError = nil
                    } else {
                        // Get error details for connection test
                        let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                        print(
                            "🚨 Connection Test Failed - HTTP \(httpResponse.statusCode): \(errorBody)"
                        )
                        self.connectionError = "HTTP \(httpResponse.statusCode): \(errorBody)"
                    }
                }
                return connected
            } else {
                await MainActor.run {
                    self.isConnected = false
                    self.connectionError = "Invalid response"
                }
                return false
            }
        } catch {
            // Connection failed - try to refresh from ntfy.sh if available
            print("🔄 Connection failed, attempting to refresh from ntfy.sh...")
            let refreshed = await refreshFromNtfy()
            if refreshed {
                // Retry connection after refresh
                return await testConnection()
            }
            
            await MainActor.run {
                self.isConnected = false
                self.connectionError = error.localizedDescription
            }
            return false
        }
    }
    
    // MARK: - ntfy.sh URL Refresh
    /// Refresh the resolved URL from ntfy.sh pattern when connection fails
    private func refreshFromNtfy() async -> Bool {
        // Only refresh if baseURL is an ntfy pattern
        guard isNtfyPattern else {
            print("ℹ️ Base URL is not an ntfy pattern, cannot refresh")
            return false
        }
        
        print("📡 Refreshing tunnel URL from ntfy.sh pattern: \(baseURL)")
        
        do {
            let tunnelURL = try await fetchTunnelURLFromNtfy(ntfyURL: baseURL)
            let newResolvedURL = tunnelURL.replacingOccurrences(of: ":443", with: "")
            
            print("✅ Refreshed resolved URL: \(newResolvedURL)")
            
            // Update the cached resolved URL
            cachedResolvedURL = newResolvedURL
            
            return true
        } catch {
            print("❌ Failed to refresh from ntfy.sh: \(error)")
            return false
        }
    }
    
    /// Fetch the tunnel URL from ntfy.sh
    private func fetchTunnelURLFromNtfy(ntfyURL: String) async throws -> String {
        // Convert ntfy.sh URL to raw polling URL
        // Example: https://ntfy.sh/mytopic -> https://ntfy.sh/mytopic/raw?poll=1
        let rawURL = ntfyURL.appending("/raw?poll=1")
        
        guard let url = URL(string: rawURL) else {
            throw APIError.invalidURL
        }
        
        print("🔍 Fetching tunnel URL from: \(rawURL)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📡 ntfy.sh response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ ntfy.sh returned \(httpResponse.statusCode): \(errorBody)")
            throw APIError.httpError(httpResponse.statusCode, errorBody)
        }
        
        // Parse the raw response and get the last line (latest tunnel URL)
        guard let responseText = String(data: data, encoding: .utf8) else {
            throw APIError.noData
        }
        
        print("📦 ntfy.sh raw response: '\(responseText)'")
        
        let lines = responseText.components(separatedBy: .newlines).filter { !$0.isEmpty }
        print("📋 Found \(lines.count) lines in response")
        
        guard let lastLine = lines.last else {
            throw APIError.noData
        }
        
        // Trim any whitespace/newlines
        let cleanedURL = lastLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("📬 Received tunnel URL from ntfy.sh: \(cleanedURL)")
        
        return cleanedURL
    }

    // MARK: - Session Creation
    func startAgent(workingDir: String = "/tmp") async throws -> (sessionId: String, messages: [Message]) {
        return try await performRequest {
            guard let url = URL(string: "\(self.resolvedURL)/agent/start") else {
                throw APIError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(self.secretKey, forHTTPHeaderField: "X-Secret-Key")

            let body: [String: Any] = ["working_dir": workingDir]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                throw APIError.httpError(httpResponse.statusCode, errorBody)
            }

            let agentResponse = try JSONDecoder().decode(AgentResponse.self, from: data)
            return (agentResponse.id, agentResponse.conversation ?? [])
        }
    }
    
    // MARK: - Session Resume
    func resumeAgent(sessionId: String) async throws -> (sessionId: String, messages: [Message]) {
        return try await performRequest {
            guard let url = URL(string: "\(self.resolvedURL)/agent/resume") else {
                throw APIError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(self.secretKey, forHTTPHeaderField: "X-Secret-Key")

            let body: [String: Any] = ["session_id": sessionId]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                throw APIError.httpError(httpResponse.statusCode, errorBody)
            }

            let agentResponse = try JSONDecoder().decode(AgentResponse.self, from: data)
            return (agentResponse.id, agentResponse.conversation ?? [])
        }
    }

    // MARK: - System Prompt Extension
    func extendSystemPrompt(sessionId: String) async throws {
        return try await performRequest {
            guard let url = URL(string: "\(self.resolvedURL)/agent/prompt") else {
                throw APIError.invalidURL
            }

            let iOSPrompt = """
                You are being accessed through the Goose iOS application from a mobile device.

                Some extensions are builtin, such as Developer and Memory.
                When asked to code, write files, or run commands, IMMEDIATELY enable the Developer extension using platform__manage_extensions.
                DO NOT explain what you're going to do first - just enable Developer and start working.
                """

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(self.secretKey, forHTTPHeaderField: "X-Secret-Key")

            let body: [String: Any] = [
                "session_id": sessionId,
                "extension": iOSPrompt,
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            // Debug logging
            if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8)
            {
                print("📤 Sending to /agent/prompt:")
                print(bodyString)
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                throw APIError.httpError(httpResponse.statusCode, errorBody)
            }

            print("✅ System prompt extended for iOS context")
        }
    }
    
    // MARK: - Config Management
    func readConfigValue(key: String, isSecret: Bool = false) async -> String? {
        guard let url = URL(string: "\(resolvedURL)/config/read") else {
            print("⚠️ Invalid URL for config read")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")
        
        let body: [String: Any] = [
            "key": key,
            "is_secret": isSecret
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ Invalid response reading config")
                return nil
            }
            
            if httpResponse.statusCode == 200 {
                // The response is just a string value, not a JSON object
                let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove quotes if present (JSON string encoding)
                let cleanValue = value?.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                print("✅ Config '\(key)' = '\(cleanValue ?? "nil")'")
                return cleanValue
            } else {
                print("⚠️ Failed to read config '\(key)': HTTP \(httpResponse.statusCode)")
                return nil
            }
        } catch {
            print("⚠️ Error reading config '\(key)': \(error)")
            // Try to refresh and retry
            if await refreshFromNtfy() {
                print("✅ Refreshed, retrying config read...")
                return await readConfigValue(key: key, isSecret: isSecret)
            }
            return nil
        }
    }
    
    // MARK: - Provider Management
    func updateProvider(sessionId: String, provider: String, model: String?) async throws {
        return try await performRequest {
            guard let url = URL(string: "\(self.resolvedURL)/agent/update_provider") else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(self.secretKey, forHTTPHeaderField: "X-Secret-Key")
            
            var body: [String: Any] = [
                "session_id": sessionId,
                "provider": provider
            ]
            
            // Add model if provided
            if let model = model {
                body["model"] = model
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            // Debug logging
            if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
                print("📤 Updating provider to \(provider), model: \(model ?? "default")")
                print(bodyString)
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                throw APIError.httpError(httpResponse.statusCode, errorBody)
            }
            
            print("✅ Provider updated to \(provider) with model \(model ?? "default")")
        }
    }
    
    // MARK: - Extension Management
    func loadEnabledExtensions(sessionId: String) async throws {
        return try await performRequest {
            // Get extensions from config, just like desktop does
            guard let url = URL(string: "\(self.resolvedURL)/config/extensions") else {
                print("⚠️ Invalid URL for getting extensions config")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(self.secretKey, forHTTPHeaderField: "X-Secret-Key")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ Invalid response getting extensions config")
                return
            }
            
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                print("⚠️ Failed to get extensions config: \(errorBody)")
                return
            }
            
            // Parse the extensions config
            guard let extensionsConfig = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let extensions = extensionsConfig["extensions"] as? [[String: Any]] else {
                print("⚠️ Failed to parse extensions config")
                return
            }
            
            // Load only the enabled extensions
            for extensionConfig in extensions {
                if let enabled = extensionConfig["enabled"] as? Bool, enabled {
                    await self.loadExtension(sessionId: sessionId, extensionConfig: extensionConfig)
                }
            }
        }
    }
    
    private func loadExtension(sessionId: String, extensionConfig: [String: Any]) async {
        guard let url = URL(string: "\(resolvedURL)/extensions/add") else {
            print("⚠️ Invalid URL for extension loading")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")
        
        var body = extensionConfig
        body["session_id"] = sessionId
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ Invalid response loading extension")
                return
            }
            
            if httpResponse.statusCode == 200 {
                if let name = extensionConfig["name"] as? String {
                    print("✅ Extension '\(name)' loaded")
                }
            } else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                if let name = extensionConfig["name"] as? String {
                    print("⚠️ Failed to load extension '\(name)': \(errorBody)")
                }
            }
        } catch {
            print("⚠️ Error loading extension: \(error)")
        }
    }

    // MARK: - Sessions Management
    func fetchSessions() async -> [ChatSession] {
        guard let url = URL(string: "\(resolvedURL)/sessions") else {
            print("🚨 Invalid sessions URL")
            return []
        }

        var request = URLRequest(url: url)
        request.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("🚨 Invalid response when fetching sessions")
                return []
            }

            if httpResponse.statusCode == 200 {
                let sessionsResponse = try JSONDecoder().decode(SessionsResponse.self, from: data)
                print("✅ Fetched \(sessionsResponse.sessions.count) sessions")
                return sessionsResponse.sessions
            } else {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                print("🚨 Sessions fetch failed - HTTP \(httpResponse.statusCode): \(errorBody)")
                return []
            }
        } catch {
            print("🚨 Error fetching sessions: \(error)")
            // Try to refresh and retry
            if await refreshFromNtfy() {
                print("✅ Refreshed, retrying fetch sessions...")
                return await fetchSessions()
            }
            return []
        }
    }
}

// MARK: - Response Models
struct AgentResponse: Codable {
    let id: String
    let conversation: [Message]?  // conversation is directly an array of messages
}

struct SessionsResponse: Codable {
    let sessions: [ChatSession]
}

// MARK: - SSE Delegate
class SSEDelegate: NSObject, URLSessionDataDelegate {
    private let onEvent: (SSEEvent) -> Void
    private let onComplete: () -> Void
    private let onError: (Error) -> Void
    private var buffer = ""

    init(
        onEvent: @escaping (SSEEvent) -> Void, onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onEvent = onEvent
        self.onComplete = onComplete
        self.onError = onError
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let httpResponse = response as? HTTPURLResponse else {
            DispatchQueue.main.async {
                self.onError(APIError.invalidResponse)
            }
            completionHandler(.cancel)
            return
        }

        print("🚀 SSE Response Status: \(httpResponse.statusCode)")
        print("🚀 SSE Response Headers: \(httpResponse.allHeaderFields)")

        guard httpResponse.statusCode == 200 else {
            DispatchQueue.main.async {
                self.onError(
                    APIError.httpError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)"))
            }
            completionHandler(.cancel)
            return
        }

        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let string = String(data: data, encoding: .utf8) else {
            print("🚨 SSE: Failed to decode data as UTF-8")
            return
        }

        // Only log if not a notification (to reduce spam)
        if !string.contains("\"type\":\"Notification\"") {
            print("🚀 SSE Received chunk: \(string)")
        }

        // Add to buffer
        buffer += string

        // Process complete lines
        let lines = buffer.components(separatedBy: .newlines)

        // Keep the last incomplete line in buffer
        if !buffer.hasSuffix("\n") && !buffer.hasSuffix("\r\n") {
            buffer = lines.last ?? ""
            let completeLines = Array(lines.dropLast())
            processSSELines(completeLines)
        } else {
            buffer = ""
            processSSELines(lines)
        }
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didCompleteWithError error: Error?
    ) {
        if let error = error {
            DispatchQueue.main.async {
                self.onError(error)
            }
        } else {
            DispatchQueue.main.async {
                self.onComplete()
            }
        }
    }

    private func processSSELines(_ lines: [String]) {
        for line in lines {
            if line.hasPrefix("data: ") {
                let eventData = String(line.dropFirst(6))
                if !eventData.isEmpty {
                    do {
                        let jsonData = eventData.data(using: .utf8)!
                        let event = try JSONDecoder().decode(SSEEvent.self, from: jsonData)

                        // Only log non-notification events for cleaner output
                        if case .notification = event {
                            // Skip verbose logging for notifications
                        } else {
                            print("🚀 SSE Event: \(eventData)")
                        }

                        DispatchQueue.main.async {
                            self.onEvent(event)
                        }

                        // Check if this is a finish event
                        if case .finish = event {
                            DispatchQueue.main.async {
                                self.onComplete()
                            }
                            return
                        }
                    } catch {
                        print("🚨 Failed to decode SSE event: \(error)")
                        print("🚨 Raw event data: \(eventData)")
                        DispatchQueue.main.async {
                            self.onError(error)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String)
    case noData
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code, let body):
            return "HTTP Error \(code): \(body)"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
