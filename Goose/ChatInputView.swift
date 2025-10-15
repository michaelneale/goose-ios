//
//  ChatInputView.swift
//  Goose
//
//  Shared input field component used by WelcomeView and ChatView
//

import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    @EnvironmentObject var themeManager: ThemeManager
    
    // Configuration
    var placeholder: String = "I want to..."
    var showPlusButton: Bool = true
    var isLoading: Bool = false
    var voiceManager: EnhancedVoiceManager? = nil
    var onSubmit: () -> Void
    var onStop: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Show transcribed text while in voice mode (if voice manager provided)
            if let vm = voiceManager,
               vm.voiceMode != .normal && !vm.transcribedText.isEmpty {
                HStack {
                    Text("Transcribing: \"\(vm.transcribedText)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(themeManager.backgroundColor.opacity(0.75))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Text field on top
                TextField(placeholder, text: $text, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.chatInputTextColor)
                    .lineLimit(1...4)
                    .padding(.vertical, 8)
                    .disabled(voiceManager?.voiceMode != .normal && voiceManager != nil)
                    .onSubmit {
                        onSubmit()
                    }
                
                // Buttons row at bottom
                HStack(spacing: 10) {
                    // Plus button - file attachment
                    Button(action: {
                        print("File attachment tapped")
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.chatInputIconColor)
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .inset(by: 0.5)
                                    .stroke(themeManager.chatInputButtonBorderColor, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Puzzle icon - extensions
                    Button(action: {
                        print("Extensions tapped")
                    }) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeManager.chatInputIconColor)
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .inset(by: 0.5)
                                    .stroke(themeManager.chatInputButtonBorderColor, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        // Auto selector - LLM dropdown
                        Button(action: {
                            print("LLM selector tapped")
                        }) {
                            HStack(spacing: 5) {
                                Text("Auto")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(themeManager.chatInputIconColor)
                                
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(themeManager.chatInputIconColor)
                            }
                            .padding(.horizontal, 10)
                            .frame(width: 84, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .inset(by: 0.5)
                                    .stroke(themeManager.chatInputButtonBorderColor, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Voice mode indicator text
                        if let vm = voiceManager, vm.voiceMode != .normal {
                            Text(vm.voiceMode == .audio ? "Transcribe" : "Full Audio")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.isDarkMode ? .blue : .blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                        
                        // Wave - audio/voice button
                        if let vm = voiceManager {
                            Button(action: {
                                vm.cycleVoiceMode()
                            }) {
                                Image(systemName: vm.voiceMode == .normal ? "waveform" : "waveform.circle.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(vm.voiceMode == .normal ? themeManager.chatInputIconColor : .blue)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .inset(by: 0.5)
                                            .stroke(themeManager.chatInputButtonBorderColor, lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Send button - always solid with inverted arrow
                        Button(action: {
                            if isLoading, let stopHandler = onStop {
                                stopHandler()
                            } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSubmit()
                            }
                        }) {
                            Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(themeManager.isDarkMode ? .black : .white)
                                .frame(width: 32, height: 32)
                                .background(isLoading ? Color.red : (themeManager.isDarkMode ? Color.white : Color.black))
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        .allowsHitTesting(!isLoading || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 21)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 21)
                            .fill(themeManager.chatInputBackgroundColor.opacity(0.85))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 21)
                    .inset(by: 0.5)
                    .stroke(themeManager.chatInputBorderColor, lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

#Preview {
    VStack {
        // Simple version (like WelcomeView)
        ChatInputView(
            text: .constant(""),
            onSubmit: {
                print("Submit tapped")
            }
        )
        
        Spacer()
    }
    .environmentObject(ThemeManager.shared)
}
