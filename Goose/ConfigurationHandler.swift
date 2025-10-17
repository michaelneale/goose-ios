import Foundation
import UIKit

/// Handles configuration of the app from QR codes and URLs
class ConfigurationHandler: ObservableObject {
    static let shared = ConfigurationHandler()
    
    @Published var isConfiguring = false
    @Published var configurationError: String?
    @Published var configurationSuccess = false
    @Published var isTailscaleError = false
    
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
}
