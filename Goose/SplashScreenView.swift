import SwiftUI

struct SplashScreenView: View {
    @Binding var isActive: Bool
    @State private var logoOpacity: Double = 0.0
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            themeManager.backgroundColor
                .ignoresSafeArea()
            
            // Goose logo centered
            Image("GooseLogo")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .opacity(logoOpacity)
        }
        .onAppear {
            print("🎬 SplashScreenView appeared")
            print("🎨 isDarkMode: \(themeManager.isDarkMode)")
            print("🎨 backgroundColor: \(themeManager.backgroundColor)")
            
            // Fade in logo
            withAnimation(.easeIn(duration: 0.5)) {
                logoOpacity = 1.0
            }
            
            // After 1.5 seconds, transition to main content
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print("⏱️ Splash timer expired, transitioning...")
                withAnimation(.easeOut(duration: 0.5)) {
                    isActive = false
                }
                print("✅ isActive set to false")
            }
        }
    }
}

#Preview {
    SplashScreenView(isActive: .constant(true))
        .environmentObject(ThemeManager.shared)
}

