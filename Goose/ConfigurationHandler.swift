import Foundation

/// Handles configuration of the app from QR codes and URLs
class ConfigurationHandler: ObservableObject {
    static let shared = ConfigurationHandler()
    
    @Published var isConfiguring = false
    @Published var configurationError: String?
    @Published var configurationSuccess = false
    
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
        
        print("📋 applyConfiguration called with:")
        print("   URL: '\(config.url)'")
        print("   Contains ntfy.sh: \(config.url.contains("ntfy.sh"))")
        
        // Check if this is a ntfy.sh URL
        if config.url.contains("ntfy.sh") {
            print("📡 Detected ntfy.sh URL, fetching actual tunnel URL...")
            Task {
                await resolveAndApplyNtfyURL(ntfyURL: config.url, secret: config.secret)
            }
            return
        }
        
        print("⚠️ NOT detected as ntfy.sh URL, applying directly...")
        
        // Direct URL (old format)
        let baseURL: String
        if config.url.hasPrefix("http://") || config.url.hasPrefix("https://") {
            // Already has protocol, use as-is but remove :443 if present
            baseURL = config.url.replacingOccurrences(of: ":443", with: "")
        } else {
            // No protocol, add https://
            baseURL = "https://\(config.url.replacingOccurrences(of: ":443", with: ""))"
        }
        
        print("✅ Applying configuration:")
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
                    
                    // Clear success flag after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.configurationSuccess = false
                    }
                } else {
                    self.configurationError = GooseAPIService.shared.connectionError ?? "Connection test failed"
                    print("❌ Configuration test failed: \(self.configurationError ?? "Unknown error")")
                }
            }
        }
    }
    
    /// Resolve ntfy.sh URL and apply the actual tunnel URL from the message
    private func resolveAndApplyNtfyURL(ntfyURL: String, secret: String) async {
        do {
            // Fetch the latest message from ntfy.sh
            let tunnelURL = try await fetchTunnelURLFromNtfy(ntfyURL: ntfyURL)
            
            // Store the ntfy.sh URL for future refreshes
            UserDefaults.standard.set(ntfyURL, forKey: "goose_ntfy_url")
            
            // Apply the resolved tunnel URL (already has https://)
            let baseURL = tunnelURL.replacingOccurrences(of: ":443", with: "")
            
            print("✅ Resolved tunnel URL from ntfy.sh:")
            print("   Raw tunnelURL: '\(tunnelURL)'")
            print("   Base URL: '\(baseURL)'")
            print("   URL length: \(baseURL.count)")
            print("   Secret: \(String(repeating: "*", count: secret.count))")
            
            // Save to UserDefaults
            UserDefaults.standard.set(baseURL, forKey: "goose_base_url")
            UserDefaults.standard.set(secret, forKey: "goose_secret_key")
            UserDefaults.standard.synchronize()
            
            // Test the connection
            let success = await GooseAPIService.shared.testConnection()
            
            await MainActor.run {
                self.isConfiguring = false
                
                if success {
                    self.configurationSuccess = true
                    self.configurationError = nil
                    print("✅ Configuration applied successfully!")
                    
                    // Clear success flag after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.configurationSuccess = false
                    }
                } else {
                    self.configurationError = GooseAPIService.shared.connectionError ?? "Connection test failed"
                    print("❌ Configuration test failed: \(self.configurationError ?? "Unknown error")")
                }
            }
            
        } catch {
            await MainActor.run {
                self.isConfiguring = false
                self.configurationError = "Failed to fetch tunnel URL from ntfy.sh: \(error.localizedDescription)"
                print("❌ Failed to resolve ntfy.sh URL: \(error)")
            }
        }
    }
    
    /// Fetch the tunnel URL from ntfy.sh
    func fetchTunnelURLFromNtfy(ntfyURL: String) async throws -> String {
        // Convert ntfy.sh URL to raw polling URL
        // Example: https://ntfy.sh/mytopic -> https://ntfy.sh/mytopic/raw?poll=1
        let rawURL = ntfyURL.appending("/raw?poll=1")
        
        guard let url = URL(string: rawURL) else {
            throw NSError(domain: "ConfigurationHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ntfy.sh URL"])
        }
        
        print("🔍 Fetching tunnel URL from: \(rawURL)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ConfigurationHandler", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from ntfy.sh"])
        }
        
        print("📡 ntfy.sh response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error details"
            print("❌ ntfy.sh returned \(httpResponse.statusCode): \(errorBody)")
            throw NSError(domain: "ConfigurationHandler", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch from ntfy.sh: HTTP \(httpResponse.statusCode)"])
        }
        
        // Parse the raw response and get the last line (latest tunnel URL)
        guard let responseText = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ConfigurationHandler", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response"])
        }
        
        print("📦 ntfy.sh raw response: '\(responseText)'")
        
        let lines = responseText.components(separatedBy: .newlines).filter { !$0.isEmpty }
        print("📋 Found \(lines.count) lines in response")
        
        guard let lastLine = lines.last else {
            throw NSError(domain: "ConfigurationHandler", code: 4, userInfo: [NSLocalizedDescriptionKey: "No tunnel URL found in ntfy.sh response (empty topic)"])
        }
        
        // Trim any whitespace/newlines
        let cleanedURL = lastLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("📬 Received tunnel URL from ntfy.sh: \(cleanedURL)")
        
        return cleanedURL
    }
    
    /// Clear any configuration errors
    func clearError() {
        configurationError = nil
    }
}
