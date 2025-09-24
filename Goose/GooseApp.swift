import SwiftUI

@main
struct GooseApp: App {
    @StateObject private var configurationHandler = ConfigurationHandler.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(configurationHandler)
                .onOpenURL { url in
                    print("📱 App received URL: \(url)")
                    _ = configurationHandler.handleURL(url)
                }
        }
    }
}
