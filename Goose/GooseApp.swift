import SwiftUI

@main
struct GooseApp: App {
    @StateObject private var configurationHandler = ConfigurationHandler.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    init() {
        // Remove ALL glass/blur effects from navigation bars globally
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        
        // Apply to all navigation bar states
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        
        // Remove blur from toolbar items
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().barTintColor = .clear
        UINavigationBar.appearance().backgroundColor = .clear
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(configurationHandler)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onOpenURL { url in
                    print("📱 App received URL: \(url)")
                    _ = configurationHandler.handleURL(url)
                }
        }
    }
}
