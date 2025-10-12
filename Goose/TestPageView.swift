import SwiftUI

struct TestPageView: View {
    @Binding var showingSidebar: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Page")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Development and testing playground")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
                    
                    // Quick Actions Section
                    GroupBox("Quick Actions") {
                        VStack(spacing: 12) {
                            HStack {
                                Button(action: {
                                    print("Debug info tapped")
                                }) {
                                    Label("Debug Info", systemImage: "info.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: {
                                    print("Test API tapped")
                                }) {
                                    Label("Test API", systemImage: "network")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            HStack {
                                Button(action: {
                                    print("Clear Cache tapped")
                                }) {
                                    Label("Clear Cache", systemImage: "trash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: {
                                    print("Export Logs tapped")
                                }) {
                                    Label("Export Logs", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // System Info Section
                    GroupBox("System Information") {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "iOS Version", value: UIDevice.current.systemVersion)
                            InfoRow(label: "Device Model", value: UIDevice.current.model)
                            InfoRow(label: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            InfoRow(label: "Build Number", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Feature Tests Section
                    GroupBox("Feature Tests") {
                        VStack(spacing: 12) {
                            NavigationLink(destination: GooseCodeView()) {
                                HStack {
                                    Image(systemName: "terminal")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("GooseCode (Legacy)")
                                            .font(.headline)
                                        Text("Original coding interface")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                            
                            NavigationLink(destination: GooseCodeProView()) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.purple)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("GooseCode Pro")
                                                .font(.headline)
                                            Text("NEW")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.purple)
                                                .foregroundColor(.white)
                                                .cornerRadius(4)
                                        }
                                        Text("VIM/EMACS + AI Assistant + Live Preview")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                            
                            Button(action: {
                                print("Markdown Test tapped")
                            }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.green)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Markdown Renderer")
                                            .font(.headline)
                                        Text("Test markdown rendering capabilities")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                            
                            Button(action: {
                                print("UI Components tapped")
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.3.group")
                                        .foregroundColor(.purple)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("UI Components")
                                            .font(.headline)
                                        Text("Test custom UI components")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Placeholder for more test sections
                    GroupBox("Experimental Features") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🚧 Under Development")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("This section will contain experimental features and prototypes as they're developed.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Spacer(minLength: 100) // Bottom padding
                }
                .padding()
            }
            .navigationTitle("Test Page")
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
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    TestPageView(showingSidebar: .constant(false))
}
