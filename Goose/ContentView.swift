import SwiftUI

struct ContentView: View {
    @State private var isSettingsPresented = false
    @State private var showingSidebar = false
    @EnvironmentObject var configurationHandler: ConfigurationHandler

    var body: some View {
        NavigationView {
            ChatView(showingSidebar: $showingSidebar)
                .navigationTitle("goose")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSidebar = true
                            }
                        }) {
                            VStack(spacing: 3) {
                                Rectangle()
                                    .frame(width: 16, height: 2)
                                Rectangle()
                                    .frame(width: 16, height: 2)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            isSettingsPresented = true
                        }) {
                            Image(systemName: "gear")
                        }
                    }
                }
                .sheet(isPresented: $isSettingsPresented) {
                    SettingsView()
                        .environmentObject(configurationHandler)
                }
        }
        .overlay(alignment: .top) {
            if configurationHandler.isConfiguring {
                ConfigurationStatusView(message: "Configuring...", isLoading: true)
            } else if configurationHandler.configurationSuccess {
                ConfigurationStatusView(message: "✅ Configuration successful!", isSuccess: true)
            } else if let error = configurationHandler.configurationError {
                ConfigurationStatusView(message: "❌ \(error)", isError: true)
                    .onTapGesture {
                        configurationHandler.clearError()
                    }
            }
        }
    }
}

struct ConfigurationStatusView: View {
    let message: String
    var isLoading = false
    var isSuccess = false
    var isError = false
    
    var backgroundColor: Color {
        if isSuccess { return .green }
        if isError { return .red }
        return .blue
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            if isError {
                Text("Tap to dismiss")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(8)
        .shadow(radius: 4)
        .padding(.top, 50) // Account for nav bar
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: isLoading)
        .animation(.spring(), value: isSuccess)
        .animation(.spring(), value: isError)
    }
}

#Preview {
    ContentView()
        .environmentObject(ConfigurationHandler.shared)
}
