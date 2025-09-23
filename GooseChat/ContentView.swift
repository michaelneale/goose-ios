import SwiftUI

struct ContentView: View {
    @State private var isSettingsPresented = false
    
    var body: some View {
        NavigationView {
            ChatView()
                .navigationTitle("Goose Chat")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
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
                }
        }
    }
}

#Preview {
    ContentView()
}
