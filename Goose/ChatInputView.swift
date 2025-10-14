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
    
    // Configuration
    var placeholder: String = "I want to..."
    var showPlusButton: Bool = false
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
                .background(Color(UIColor.systemBackground).opacity(0.95))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Text field on top
                TextField(placeholder, text: $text, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .lineLimit(1...4)
                    .padding(.vertical, 8)
                    .disabled(voiceManager?.voiceMode != .normal && voiceManager != nil)
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
                            Text(vm.voiceMode == .audio ? "Transcribe" : "Full Audio")
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
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(21)
            .overlay(
                RoundedRectangle(cornerRadius: 21)
                    .inset(by: 0.5)
                    .stroke(Color(UIColor.separator), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
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
}
