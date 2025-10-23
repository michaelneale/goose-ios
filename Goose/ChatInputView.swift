//
//  ChatInputView.swift
//  Goose
//
//  Shared input field component used by WelcomeView and ChatView
//

import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    @Environment(\.colorScheme) var colorScheme
    @FocusState.Binding var isFocused: Bool
    
    // Configuration
    var placeholder: String = "I want to..."
    var showPlusButton: Bool = false
    var isLoading: Bool = false
    var voiceManager: EnhancedVoiceManager? = nil
    var onSubmit: () -> Void
    var onStop: (() -> Void)? = nil
    
    // Trial mode banner
    var showTrialBanner: Bool = false
    var onTrialBannerTap: (() -> Void)? = nil
    
    // Track input field height
    @State private var inputHeight: CGFloat = 80
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Trial mode banner (behind the input)
            if showTrialBanner {
                VStack(spacing: 0) {
                    TrialModeBanner(onTap: {
                        onTrialBannerTap?()
                    })
                    
                    // Spacer to extend behind input
                    Spacer()
                        .frame(height: 80)
                }
                .frame(height: 180) // Fixed total height
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(colorScheme == .dark ?
                              Color(red: 0.15, green: 0.15, blue: 0.18) :
                              Color(red: 0.96, green: 0.96, blue: 0.98))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .strokeBorder(
                            colorScheme == .dark ?
                            Color(red: 0.25, green: 0.25, blue: 0.28) :
                            Color(red: 0.88, green: 0.88, blue: 0.90),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Listening indicator banner (behind the input) - GROWS WITH INPUT
            if let vm = voiceManager,
               vm.voiceMode != .normal && vm.state == .listening {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .symbolEffect(.variableColor.iterative.reversing)
                        
                        Text("Listening...")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // Spacer that matches the input field height
                    Spacer()
                        .frame(height: inputHeight)
                }
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(colorScheme == .dark ?
                              Color(red: 0.15, green: 0.15, blue: 0.18) :
                              Color(red: 0.96, green: 0.96, blue: 0.98))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .strokeBorder(
                            colorScheme == .dark ?
                            Color(red: 0.25, green: 0.25, blue: 0.28) :
                            Color(red: 0.88, green: 0.88, blue: 0.90),
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.2), value: inputHeight)
            }
            
            VStack(spacing: 0) {

                VStack(alignment: .leading, spacing: 12) {
                    // Text field on top
                    TextField(placeholder, text: $text, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .lineLimit(1...4)
                        .padding(.vertical, 8)
                        .focused($isFocused)
                        .onSubmit {
                            onSubmit()
                        }
                    
                    // Buttons row at bottom
                    HStack(spacing: 10) {
                        // Plus button (optional)
                        if showPlusButton {
                            Button(action: {
                                print("File attachment tapped")
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .inset(by: 0.5)
                                            .stroke(Color(UIColor.separator), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 10) {
                            // Voice mode indicator text (if voice manager provided)
                            if let vm = voiceManager, vm.voiceMode != .normal {
                                Text("Transcribe")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                            
                            // Voice button (if voice manager provided)
                            if let vm = voiceManager {
                                Button(action: {
                                    vm.cycleVoiceMode()
                                }) {
                                    Image(systemName: vm.voiceMode == .normal ? "waveform" : "waveform.circle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(vm.voiceMode == .normal ? .primary : .blue)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .inset(by: 0.5)
                                                .stroke(Color(UIColor.separator), lineWidth: 0.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Send/Stop button
                            Button(action: {
                                if isLoading, let stopHandler = onStop {
                                    stopHandler()
                                } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    onSubmit()
                                }
                            }) {
                                Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(
                                        isLoading ? .white : (colorScheme == .dark ? .black : .white)
                                    )
                                    .frame(width: 32, height: 32)
                                    .background(
                                        isLoading ? Color.red :
                                        (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                                            ? Color.gray.opacity(0.3)
                                            : (colorScheme == .dark ? Color.white : Color.black))
                                    )
                                    .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isLoading && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 10)
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { geometry in
                        Color(UIColor.secondarySystemBackground)
                            .onAppear {
                                inputHeight = geometry.size.height
                            }
                            .onChange(of: geometry.size.height) { newHeight in
                                inputHeight = newHeight
                            }
                    }
                )
                .cornerRadius(32)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .inset(by: 0.5)
                        .stroke(Color(UIColor.separator), lineWidth: 0.5)
                )
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 12,
                    x: 0,
                    y: 0
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 0)
            }
            .zIndex(1) // Input on top
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        @FocusState private var isFocused: Bool
        
        var body: some View {
            VStack {
                Spacer()
                
                // With trial banner
                ChatInputView(
                    text: $text,
                    isFocused: $isFocused,
                    onSubmit: {
                        print("Submit tapped")
                    },
                    showTrialBanner: true,
                    onTrialBannerTap: {
                        print("Trial banner tapped")
                    }
                )
            }
        }
    }
    
    return PreviewWrapper()
}
