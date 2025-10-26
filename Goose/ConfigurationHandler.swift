import Foundation
import UIKit

// MARK: - Server Configuration Model
struct ServerConfiguration: Identifiable, Codable, Equatable {
    let id: String
    var name: String?  // Optional custom name
    let url: String
    let secret: String
    var lastUsed: Date
    
    init(id: String = UUID().uuidString, name: String? = nil, url: String, secret: String, lastUsed: Date = Date()) {
        self.id = id
        self.name = name
        self.url = url
        self.secret = secret
        self.lastUsed = lastUsed
    }
    
    /// Display name for the server (custom name or formatted URL)
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        // Format URL for display (remove protocol and port)
        var formatted = url
        formatted = formatted.replacingOccurrences(of: "https://", with: "")
        formatted = formatted.replacingOccurrences(of: "http://", with: "")
        formatted = formatted.replacingOccurrences(of: ":443", with: "")
        
        // Truncate if too long
        if formatted.count > 30 {
            return String(formatted.prefix(27)) + "..."
        }
        return formatted
    }
    
    /// Subtitle showing the URL (only shown when custom name is set)
    var subtitle: String? {
        guard name != nil && !name!.isEmpty else { return nil }
        var formatted = url
        formatted = formatted.replacingOccurrences(of: "https://", with: "")
        formatted = formatted.replacingOccurrences(of: "http://", with: "")
        formatted = formatted.replacingOccurrences(of: ":443", with: "")
        return formatted
    }
}

// MARK: - Server Storage Manager
class ServerStorage: ObservableObject {
    static let shared = ServerStorage()
    
    @Published var savedServers: [ServerConfiguration] = []
    @Published var currentServerId: String?
    
    private let serversKey = "saved_servers"
    private let currentServerKey = "current_server_id"
    
    private init() {
        loadServers()
        loadCurrentServerId()
        ensureCurrentServerInList()
    }
    
    /// Ensure the current UserDefaults configuration is in the server list
    func ensureCurrentServerInList() {
        let currentURL = UserDefaults.standard.string(forKey: "goose_base_url") ?? ""
        let currentSecret = UserDefaults.standard.string(forKey: "goose_secret_key") ?? ""
        
        // Skip if no valid configuration
        guard !currentURL.isEmpty, !currentSecret.isEmpty else { return }
        
        // Check if this server already exists
        if let existing = savedServers.first(where: { $0.url == currentURL && $0.secret == currentSecret }) {
            // Set it as current
            currentServerId = existing.id
            saveCurrentServerId()
        } else {
            // Add the current configuration as an unnamed server
            let server = ServerConfiguration(name: nil, url: currentURL, secret: currentSecret)
            savedServers.insert(server, at: 0)
            currentServerId = server.id
            saveServers()
            saveCurrentServerId()
        }
    }
    
    /// Load saved servers from UserDefaults
    private func loadServers() {
        guard let data = UserDefaults.standard.data(forKey: serversKey),
              let servers = try? JSONDecoder().decode([ServerConfiguration].self, from: data) else {
            savedServers = []
            return
        }
        // Sort by last used (most recent first)
        savedServers = servers.sorted { $0.lastUsed > $1.lastUsed }
    }
    
    /// Save servers to UserDefaults
    private func saveServers() {
        guard let data = try? JSONEncoder().encode(savedServers) else { return }
        UserDefaults.standard.set(data, forKey: serversKey)
        UserDefaults.standard.synchronize()
    }
    
    /// Load current server ID
    private func loadCurrentServerId() {
        currentServerId = UserDefaults.standard.string(forKey: currentServerKey)
    }
    
    /// Save current server ID
    private func saveCurrentServerId() {
        if let id = currentServerId {
            UserDefaults.standard.set(id, forKey: currentServerKey)
        } else {
            UserDefaults.standard.removeObject(forKey: currentServerKey)
        }
        UserDefaults.standard.synchronize()
    }
    
    /// Add or update a server configuration
    func saveServer(_ server: ServerConfiguration) {
        // Check if server already exists (by URL and secret)
        if let index = savedServers.firstIndex(where: { $0.url == server.url && $0.secret == server.secret }) {
            // Update existing server
            var updated = savedServers[index]
            updated.name = server.name
            updated.lastUsed = Date()
            savedServers[index] = updated
            
            // If this is the current server, update the ID
            if currentServerId == savedServers[index].id {
                currentServerId = updated.id
                saveCurrentServerId()
            }
        } else {
            // Add new server
            var newServer = server
            newServer.lastUsed = Date()
            savedServers.insert(newServer, at: 0)
        }
        
        // Sort by last used
        savedServers.sort { $0.lastUsed > $1.lastUsed }
        saveServers()
    }
    
    /// Get current server configuration
    var currentServer: ServerConfiguration? {
        guard let id = currentServerId else { return nil }
        return savedServers.first { $0.id == id }
    }
    
    /// Switch to a saved server
    func switchToServer(_ server: ServerConfiguration) {
        // Update last used
        if let index = savedServers.firstIndex(where: { $0.id == server.id }) {
            savedServers[index].lastUsed = Date()
            saveServers()
        }
        
        // Set as current
        currentServerId = server.id
        saveCurrentServerId()
        
        // Apply to UserDefaults
        UserDefaults.standard.set(server.url, forKey: "goose_base_url")
        UserDefaults.standard.set(server.secret, forKey: "goose_secret_key")
        UserDefaults.standard.synchronize()
        
        // Notify that configuration changed
        NotificationCenter.default.post(name: Notification.Name("RefreshSessions"), object: nil)
    }
    
    /// Delete a server
    func deleteServer(_ server: ServerConfiguration) {
        savedServers.removeAll { $0.id == server.id }
        
        // If this was the current server, clear current
        if currentServerId == server.id {
            currentServerId = nil
            saveCurrentServerId()
        }
        
        saveServers()
    }
    
    /// Get server by current UserDefaults configuration
    func getServerFromCurrentDefaults() -> ServerConfiguration? {
        let url = UserDefaults.standard.string(forKey: "goose_base_url") ?? ""
        let secret = UserDefaults.standard.string(forKey: "goose_secret_key") ?? ""
        
        guard !url.isEmpty, !secret.isEmpty else { return nil }
        
        // Check if this matches an existing server
        return savedServers.first { $0.url == url && $0.secret == secret }
    }
    
    /// Mark current UserDefaults as a server
    func saveCurrentConfiguration(withName name: String? = nil) -> ServerConfiguration {
        let url = UserDefaults.standard.string(forKey: "goose_base_url") ?? ""
        let secret = UserDefaults.standard.string(forKey: "goose_secret_key") ?? ""
        
        // Check if this configuration already exists
        if let existing = savedServers.first(where: { $0.url == url && $0.secret == secret }) {
            // Update name if provided
            var updated = existing
            if let name = name {
                updated.name = name
            }
            updated.lastUsed = Date()
            saveServer(updated)
            currentServerId = updated.id
            saveCurrentServerId()
            return updated
        } else {
            // Create new server
            let server = ServerConfiguration(name: name, url: url, secret: secret)
            saveServer(server)
            currentServerId = server.id
            saveCurrentServerId()
            return server
        }
    }
}

/// Handles configuration of the app from QR codes and URLs
class ConfigurationHandler: ObservableObject {
    static let shared = ConfigurationHandler()
    
    @Published var isConfiguring = false
    @Published var configurationError: String?
    @Published var configurationSuccess = false
    @Published var isTailscaleError = false
    @Published var showSaveServerDialog = false
    
    private init() {}
    
    /// Configuration data structure matching the format from launch_tunnel.sh
    struct ConfigurationData: Codable {
        let url: String
        let secret: String
    }
    

    
    /// Handles incoming URL from QR code scan or deep link
    /// Expected format: goosechat://configure?data=<url-encoded-json>
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "goosechat" else {
            print("❌ Invalid URL scheme: \(url.scheme ?? "nil")")
            return false
        }
        
        guard url.host == "configure" else {
            print("❌ Unknown URL host: \(url.host ?? "nil")")
            return false
        }
        
        // Parse query parameters
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataParam = queryItems.first(where: { $0.name == "data" })?.value else {
            print("❌ Missing 'data' parameter in URL")
            self.configurationError = "Invalid configuration link"
            return false
        }
        
        // URL decode the parameter
        guard let decodedData = dataParam.removingPercentEncoding,
              let jsonData = decodedData.data(using: .utf8) else {
            print("❌ Failed to decode URL parameter")
            self.configurationError = "Failed to decode configuration"
            return false
        }
        
        print("📱 Decoded configuration data: \(decodedData)")
        
        do {
            // Parse the JSON configuration
            let config = try JSONDecoder().decode(ConfigurationData.self, from: jsonData)
            
            // Apply the configuration
            applyConfiguration(config)
            return true
            
        } catch {
            print("❌ Failed to parse configuration: \(error)")
            self.configurationError = "Invalid configuration format"
            return false
        }
    }
    
    /// Apply the configuration to UserDefaults
    private func applyConfiguration(_ config: ConfigurationData) {
        isConfiguring = true
        configurationError = nil
        configurationSuccess = false
        
        print("📋 Applying configuration:")
        print("   URL: '\(config.url)'")
        let baseURL: String
        if config.url.hasPrefix("http://") || config.url.hasPrefix("https://") {
            // Already has protocol, use as-is but remove :443 if present
            baseURL = config.url.replacingOccurrences(of: ":443", with: "")
        } else {
            // No protocol, add https://
            baseURL = "https://\(config.url.replacingOccurrences(of: ":443", with: ""))"
        }
        
        print("   Base URL: \(baseURL)")
        print("   Secret: \(String(repeating: "*", count: config.secret.count))")
        
        // Save to UserDefaults
        UserDefaults.standard.set(baseURL, forKey: "goose_base_url")
        UserDefaults.standard.set(config.secret, forKey: "goose_secret_key")
        UserDefaults.standard.synchronize()
        
        // Test the connection
        Task {
            let success = await GooseAPIService.shared.testConnection()
            
            await MainActor.run {
                self.isConfiguring = false
                
                if success {
                    self.configurationSuccess = true
                    self.configurationError = nil
                    print("✅ Configuration applied successfully!")
                    
                    // Ensure the new configuration is in the server list
                    ServerStorage.shared.ensureCurrentServerInList()
                    
                    // Clear success flag after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.configurationSuccess = false
                    }
                } else {
                    // Check if this is a Tailscale URL (100.x.x.x range or .ts.net domain)
                    let originalError = GooseAPIService.shared.connectionError ?? "Connection test failed"
                    if self.isTailscaleURL(baseURL) {
                        self.isTailscaleError = true
                        self.configurationError = "Please log in to Tailscale to connect to your agent"
                    } else {
                        self.isTailscaleError = false
                        self.configurationError = originalError
                    }
                    print("❌ Configuration test failed: \(self.configurationError ?? "Unknown error")")
                }
            }
        }
    }

    /// Check if a URL is a Tailscale URL
    /// Returns true for both 100.x.x.x IP addresses and .ts.net domains
    func isTailscaleURL(_ urlString: String) -> Bool {
        return urlString.hasPrefix("http://100.") || 
               urlString.hasPrefix("https://100.") ||
               urlString.contains(".ts.net")
    }
    
    /// Clear any configuration errors
    func clearError() {
        configurationError = nil
        isTailscaleError = false
    }
    
    /// Open Tailscale app or App Store
    func openTailscale() {
        // Try to open the Tailscale app first
        if let tailscaleURL = URL(string: "tailscale://"), 
           UIApplication.shared.canOpenURL(tailscaleURL) {
            UIApplication.shared.open(tailscaleURL)
        } else {
            // If app isn't installed, open App Store
            if let appStoreURL = URL(string: "https://apps.apple.com/app/tailscale/id1470499037") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
    
    /// Reset configuration to demo/trial mode
    func resetToTrialMode() {
        let config = ConfigurationData(
            url: "https://demo-goosed.fly.dev",
            secret: "test"
        )
        applyConfiguration(config)
        print("🎯 Reset to trial mode")
    }
    
    /// Save current configuration as a server
    func saveCurrentConfigurationAsServer(withName name: String? = nil) {
        let server = ServerStorage.shared.saveCurrentConfiguration(withName: name)
        print("💾 Saved server configuration: \(server.displayName)")
    }
    
    /// Switch to a saved server configuration
    func switchToServer(_ server: ServerConfiguration) {
        ServerStorage.shared.switchToServer(server)
        print("🔄 Switched to server: \(server.displayName)")
        
        // Test the connection
        Task {
            _ = await GooseAPIService.shared.testConnection()
        }
    }
}
