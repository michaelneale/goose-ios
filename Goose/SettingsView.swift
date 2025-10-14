import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = GooseAPIService.shared
    @EnvironmentObject var configurationHandler: ConfigurationHandler

    @State private var baseURL: String = ""
    @State private var secretKey: String = ""
    @State private var isTestingConnection = false
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("http://127.0.0.1:62996", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Secret Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("Enter secret key", text: $secretKey)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section(header: Text("Connection Status")) {
                    HStack {
                        Image(
                            systemName: apiService.isConnected
                                ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundColor(apiService.isConnected ? .green : .red)

                        VStack(alignment: .leading) {
                            Text(apiService.isConnected ? "Connected" : "Disconnected")
                                .fontWeight(.medium)

                            if let error = apiService.connectionError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        Spacer()

                        Button("Test") {
                            testConnection()
                        }
                        .disabled(isTestingConnection)
                    }

                    if isTestingConnection {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Testing connection...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("About")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goose")
                            .font(.headline)
                        Text("A general purpose AI Agent by Block")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Version 1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Trial Mode")
                        }
                        .foregroundColor(.orange)
                    }
                    .alert("Reset to Trial Mode?", isPresented: $showResetConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) {
                            configurationHandler.resetToTrialMode()
                            // Reload the settings to reflect the change immediately
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                loadSettings()
                            }
                        }
                    } message: {
                        Text("This will reset your configuration to use the trial service.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSettings()
        }
        .onChange(of: configurationHandler.configurationSuccess) { success in
            if success {
                // Reload settings when configuration is successful
                loadSettings()
            }
        }
    }

    private func loadSettings() {
        baseURL = UserDefaults.standard.string(forKey: "goose_base_url") ?? "http://127.0.0.1:62996"
        secretKey = UserDefaults.standard.string(forKey: "goose_secret_key") ?? "test"
    }

    private func saveSettings() {
        UserDefaults.standard.set(baseURL, forKey: "goose_base_url")
        UserDefaults.standard.set(secretKey, forKey: "goose_secret_key")
        
        // Post notification to refresh sessions when URL changes
        NotificationCenter.default.post(name: Notification.Name("RefreshSessions"), object: nil)
    }

    private func testConnection() {
        isTestingConnection = true

        // Temporarily save settings for testing
        let originalBaseURL = UserDefaults.standard.string(forKey: "goose_base_url")
        let originalSecretKey = UserDefaults.standard.string(forKey: "goose_secret_key")

        UserDefaults.standard.set(baseURL, forKey: "goose_base_url")
        UserDefaults.standard.set(secretKey, forKey: "goose_secret_key")

        Task {
            _ = await apiService.testConnection()

            await MainActor.run {
                isTestingConnection = false

                // Restore original settings if test failed
                if !apiService.isConnected {
                    if let originalURL = originalBaseURL {
                        UserDefaults.standard.set(originalURL, forKey: "goose_base_url")
                    }
                    if let originalKey = originalSecretKey {
                        UserDefaults.standard.set(originalKey, forKey: "goose_secret_key")
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
