import SwiftUI

struct SafeAreaExtension: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Computed property for background color - matches WelcomeCard
    private var backgroundColor: Color {
        colorScheme == .dark ?
        Color(red: 0.15, green: 0.15, blue: 0.18) :
        Color(red: 0.98, green: 0.98, blue: 0.99)
    }
    
    var body: some View {
        GeometryReader { geometry in
            backgroundColor
                .frame(height: geometry.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)
        }
        .frame(height: 0) // Don't take up layout space
    }
}

#Preview {
    ZStack {
        Color(UIColor.systemBackground)
            .ignoresSafeArea()
        
        VStack(spacing: 0) {
            SafeAreaExtension()
            
            Text("Content below")
                .padding()
            
            Spacer()
        }
    }
}
