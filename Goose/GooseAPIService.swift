import Foundation
import Combine

class GooseAPIService: ObservableObject {
    static let shared = GooseAPIService()

    @Published var isConnected = false
    @Published var connectionError: String?

    private var baseURL: String {
        UserDefaults.standard.string(forKey: "goose_base_url") ?? "http://127.0.0.1:62996"
    }

    private var secretKey: String {
        UserDefaults.standard.string(forKey: "goose_secret_key") ?? "test"
    }

    private init() {}

    // MARK: - Proper SSE Streaming Implementation
    func startChatStreamWithSSE(
        messages: [Message],
        sessionId: String? = nil,
        workingDirectory: String = "/tmp",
        onEvent: @escaping (SSEEvent) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) -> URLSessionDataTask? {

        guard let url = URL(string: "\(baseURL)/reply") else {
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
            print("🚀 Starting SSE stream to: \(url)")
            print("🚀 Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
            if let bodyString = String(data: requestData, encoding: .utf8) {
                print("🚀 Request body:")
                if let jsonData = bodyString.data(using: .utf8), 
                   let prettyJson = try? JSONSerialization.jsonObject(with: jsonData), 
                   let prettyData = try? JSONSerialization.data(withJSONObject: prettyJson, options: .prettyPrinted), 
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    print(prettyString)
                } else {
                    print(bodyString)
                }
            }
        } catch {
            onError(error)
            return nil
        }

        // Create a custom URLSessionDataDelegate to handle streaming
        let delegate = SSEDelegate(
            onEvent: onEvent,
            onComplete: onComplete,
            onError: onError
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
        guard let url = URL(string: "\(baseURL)/status") else {
            await MainActor.run {
                self.connectionError = "Invalid URL"
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
                        print("🚨 Connection Test Failed - HTTP \(httpResponse.statusCode): \(errorBody)")
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
            await MainActor.run {
                self.isConnected = false
                self.connectionError = error.localizedDescription
            }
            return false
        }
    }
    
    // MARK: - Session Creation
    func startAgent(workingDir: String = "/tmp") async throws -> String {
        guard let url = URL(string: "\(baseURL)/agent/start") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")
        
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
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessionId = json["id"] as? String else {
            throw APIError.decodingError(NSError(domain: "GooseAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get session id from response"]))
        }
        
        return sessionId
    }
    
    func updateProvider(sessionId: String, provider: String = "openai", model: String = "gpt-4o") async throws {
        guard let url = URL(string: "\(baseURL)/agent/update_provider") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")
        
        let body: [String: Any] = [
            "session_id": sessionId,
            "provider": provider,
            "model": model
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            throw APIError.httpError(httpResponse.statusCode, errorBody)
        }
    }
    
    // MARK: - Sessions Management
    func fetchSessions() async -> [ChatSession] {
        guard let url = URL(string: "\(baseURL)/sessions") else {
            print("🚨 Invalid sessions URL")
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue(secretKey, forHTTPHeaderField: "X-Secret-Key")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // First, let's see what the actual response looks like
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("🔍 Sessions API response:")
                        print(responseString)
                        
                        // Pretty print if it's valid JSON
                        if let jsonData = responseString.data(using: .utf8), let jsonObject = try? JSONSerialization.jsonObject(with: jsonData), let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted), let prettyString = String(data: prettyData, encoding: .utf8) {
                            print("🔍 Pretty JSON:")
                            print(prettyString)
                        }
                    }
                    
                    // Try different response formats
                    let sessions: [ChatSession]
                    do {
                        // Try as wrapped response first
                        let sessionsResponse = try JSONDecoder().decode(SessionsResponse.self, from: data)
                        sessions = sessionsResponse.sessions
                    } catch {
                        print("🔍 Failed to decode as SessionsResponse, trying as direct array: \(error)")
                        do {
                            // Try as direct array
                            sessions = try JSONDecoder().decode([ChatSession].self, from: data)
                        } catch {
                            print("🔍 Failed to decode as array too: \(error)")
                            throw error
                        }
                    }
                    print("✅ Fetched \(sessions.count) sessions")
                    return sessions
                } else {
                    let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
                    print("🚨 Sessions fetch failed - HTTP \(httpResponse.statusCode): \(errorBody)")
                    return []
                }
            } else {
                print("🚨 Invalid response when fetching sessions")
                return []
            }
        } catch {
            print("🚨 Error fetching sessions: \(error)")
            // Return mock data as fallback
            return [
                ChatSession(id: "1", title: "iOS Development Help", lastMessage: "How to implement SwiftUI navigation", timestamp: Date().addingTimeInterval(-3600)),
                ChatSession(id: "2", title: "Python Script Debug", lastMessage: "Error in data processing", timestamp: Date().addingTimeInterval(-7200)),
                ChatSession(id: "3", title: "API Integration", lastMessage: "REST API authentication", timestamp: Date().addingTimeInterval(-86400))
            ]
        }
    }
}

// MARK: - Sessions Response Model
struct SessionsResponse: Codable {
    let sessions: [ChatSession]
}

// MARK: - SSE Delegate
class SSEDelegate: NSObject, URLSessionDataDelegate {
    private let onEvent: (SSEEvent) -> Void
    private let onComplete: () -> Void
    private let onError: (Error) -> Void
    private var buffer = ""
    
    init(onEvent: @escaping (SSEEvent) -> Void, onComplete: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        self.onEvent = onEvent
        self.onComplete = onComplete
        self.onError = onError
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
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
                self.onError(APIError.httpError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)"))
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
        
        print("🚀 SSE Received chunk: \(string)")
        
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
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didCompleteWithError error: Error?) {
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
                print("🚀 SSE: Processing event data: '\(eventData)'")
                if !eventData.isEmpty {
                    print("🚀 Processing SSE event: \(eventData)")
                    do {
                        let jsonData = eventData.data(using: .utf8)!
                        let event = try JSONDecoder().decode(SSEEvent.self, from: jsonData)
                        
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
