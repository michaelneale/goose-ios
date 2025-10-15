import SwiftUI

struct SplashScreenView: View {
    @Binding var isActive: Bool
    @State private var logoOpacity: Double = 0.0
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Use themed background color so dark mode matches app
            themeManager.backgroundColor
                .ignoresSafeArea()
            
            // Goose logo centered
            Image("GooseLogo")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(themeManager.primaryTextColor)
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .opacity(logoOpacity)
        }
        .onAppear {
            // Check if this is first launch or if app hasn't been opened in a while
            let lastOpenKey = "last_app_open_time"
            let isFirstLaunch = UserDefaults.standard.object(forKey: "has_launched_before") == nil
            let lastOpenTime = UserDefaults.standard.object(forKey: lastOpenKey) as? Date ?? Date.distantPast
            let hoursSinceLastOpen = Date().timeIntervalSince(lastOpenTime) / 3600
            
            // Show longer splash on first launch or if hasn't been opened in 24+ hours
            let showLongerSplash = isFirstLaunch || hoursSinceLastOpen > 24
            
            // Save current launch time
            UserDefaults.standard.set(Date(), forKey: lastOpenKey)
            UserDefaults.standard.set(true, forKey: "has_launched_before")
            
            // Adjust animation timings based on context
            let fadeInDuration = showLongerSplash ? 0.4 : 0.2
            let displayDuration = showLongerSplash ? 1.0 : 0.3
            let fadeOutDuration = showLongerSplash ? 0.4 : 0.2
            
            // Fade in logo
            withAnimation(.easeIn(duration: fadeInDuration)) {
                logoOpacity = 1.0
            }
            
            // After display duration, transition to main content
            DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
                withAnimation(.easeOut(duration: fadeOutDuration)) {
                    isActive = false
                }
            }
        }
    }
}

#Preview {
    SplashScreenView(isActive: .constant(true))
        .environmentObject(ThemeManager.shared)
}
