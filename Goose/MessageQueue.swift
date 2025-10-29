import Foundation

/// Simple persistent queue for offline messages
class MessageQueue: ObservableObject {
    static let shared = MessageQueue()
    
    @Published var queuedMessages: [QueuedMessage] = []
    
    private let queueKey = "message_queue"
    
    struct QueuedMessage: Codable, Identifiable {
        let id: String
        let text: String
        let sessionId: String?  // Session to send to, or nil for new session
        let timestamp: Date
        
        init(text: String, sessionId: String?) {
            self.id = UUID().uuidString
            self.text = text
            self.sessionId = sessionId
            self.timestamp = Date()
        }
    }
    
    private init() {
        loadQueue()
    }
    
    /// Add a message to the queue
    func enqueue(text: String, sessionId: String?) {
        let message = QueuedMessage(text: text, sessionId: sessionId)
        queuedMessages.append(message)
        saveQueue()
        print("📥 Queued message for offline: '\(text.prefix(50))...' (session: \(sessionId ?? "new"))")
    }
    
    /// Remove a message from the queue
    func dequeue(_ messageId: String) {
        queuedMessages.removeAll { $0.id == messageId }
        saveQueue()
        print("📤 Dequeued message: \(messageId)")
    }
    
    /// Clear all queued messages
    func clearQueue() {
        queuedMessages.removeAll()
        saveQueue()
        print("🗑️ Cleared message queue")
    }
    
    /// Get count of queued messages
    var count: Int {
        queuedMessages.count
    }
    
    /// Check if queue has messages
    var hasMessages: Bool {
        !queuedMessages.isEmpty
    }
    
    // MARK: - Persistence
    
    private func saveQueue() {
        do {
            let data = try JSONEncoder().encode(queuedMessages)
            UserDefaults.standard.set(data, forKey: queueKey)
            print("💾 Saved \(queuedMessages.count) queued messages")
        } catch {
            print("⚠️ Failed to save message queue: \(error)")
        }
    }
    
    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else {
            print("📭 No queued messages found")
            return
        }
        
        do {
            queuedMessages = try JSONDecoder().decode([QueuedMessage].self, from: data)
            print("📬 Loaded \(queuedMessages.count) queued messages")
        } catch {
            print("⚠️ Failed to load message queue: \(error)")
            queuedMessages = []
        }
    }
}
