import SwiftUI

struct TrialModeInstructionsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connect to Your Goose Desktop")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Follow these simple steps to link your iPhone to your desktop Goose agent")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 20) {
                        InstructionStep(
                            number: 1,
                            title: "Install Goose Desktop",
                            description: "Download and install the Goose desktop application on your computer if you haven't already.",
                            icon: "desktopcomputer"
                        )
                        
                        InstructionStep(
                            number: 2,
                            title: "Enable Tunneling",
                            description: "Open Goose desktop, go to Settings → App, and turn on the Tunneling option.",
                            icon: "network"
                        )
                        
                        InstructionStep(
                            number: 3,
                            title: "Sign In on Desktop",
                            description: "When prompted, sign in to your account on the desktop app to enable secure tunneling.",
                            icon: "person.crop.circle.badge.checkmark"
                        )
                        
                        InstructionStep(
                            number: 4,
                            title: "Scan QR Code",
                            description: "A QR code will appear in the desktop app. Use your iPhone's camera to scan it.",
                            icon: "qrcode.viewfinder"
                        )
                        
                        InstructionStep(
                            number: 5,
                            title: "Sign In on iPhone",
                            description: "Sign in again on your iPhone when prompted to securely link to your desktop.",
                            icon: "iphone.badge.checkmark"
                        )
                    }
                    
                    // Important Note
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Important", systemImage: "info.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Text("Make sure both devices are connected to the internet. The tunneling feature creates a secure connection between your iPhone and desktop, allowing you to access your personal Goose agent from anywhere.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ?
                                  Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.5) :
                                  Color(red: 0.96, green: 0.96, blue: 0.98))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                colorScheme == .dark ?
                                Color(red: 0.25, green: 0.25, blue: 0.28) :
                                Color(red: 0.88, green: 0.88, blue: 0.90),
                                lineWidth: 1
                            )
                    )
                    
                    // Trial Mode Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trial Mode Features")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("While in trial mode, you can:")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(text: "Ask questions and get answers", isIncluded: true)
                            FeatureRow(text: "View example sessions", isIncluded: true)
                            FeatureRow(text: "Explore the app interface", isIncluded: true)
                            FeatureRow(text: "Access your file system", isIncluded: false)
                            FeatureRow(text: "Run commands and scripts", isIncluded: false)
                            FeatureRow(text: "Save persistent sessions", isIncluded: false)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            }
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? 
                          Color(red: 0.2, green: 0.2, blue: 0.25) :
                          Color(red: 0.95, green: 0.95, blue: 0.97))
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let text: String
    let isIncluded: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isIncluded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(isIncluded ? .green : .gray)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(isIncluded ? .primary : .secondary)
            
            Spacer()
        }
    }
}

#Preview {
    TrialModeInstructionsView()
}
