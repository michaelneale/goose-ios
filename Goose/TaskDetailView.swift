//
//  TaskDetailView.swift
//  Goose
//
//  Created by Thomas Petersen on 10/9/25.
//

import SwiftUI

// MARK: - Task Detail View (Shows completed tasks with conversation)
struct TaskDetailView: View {
    let message: Message
    let completedTasks: [CompletedToolCall]
    let sessionName: String
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var taskName: String {
        if completedTasks.count == 1 {
            return completedTasks[0].toolCall.name
        } else {
            return "\(completedTasks.count) Tasks"
        }
    }
    
    // Extract text content from the message
    var messageText: String {
        for content in message.content {
            if case .text(let textContent) = content {
                return textContent.text
            }
        }
        return ""
    }
    
    // Format timestamp
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Timestamp at the top
                Text(formatTimestamp(message.created))
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.secondaryTextColor)
                    .padding(.bottom, 4)
                
                // Show the conversation/reasoning text
                if !messageText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Response")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        Text(messageText)
                            .font(.system(size: 16))
                            .foregroundColor(themeManager.primaryTextColor)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.bottom, 8)
                }
                
                // Show all task outputs inline
                if !completedTasks.isEmpty {
                    ForEach(Array(completedTasks.enumerated()), id: \.offset) { index, task in
                        VStack(alignment: .leading, spacing: 12) {
                            // Task separator/header
                            if completedTasks.count > 1 {
                                Divider()
                                    .padding(.vertical, 8)
                                
                                HStack {
                                    Image(systemName: task.result.status == "success" ? "checkmark.circle" : "xmark.circle")
                                        .foregroundColor(task.result.status == "success" ? .green : .red)
                                        .font(.system(size: 16))
                                    
                                    Text(task.toolCall.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(themeManager.primaryTextColor)
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.2fs", task.duration))
                                        .font(.system(size: 12))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                            }
                            
                            // Arguments
                            if !task.toolCall.arguments.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Arguments")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(themeManager.primaryTextColor)
                                        .padding(.bottom, 4)
                                    
                                    ForEach(Array(task.toolCall.arguments.keys.sorted()), id: \.self) { key in
                                        if let argValue = task.toolCall.arguments[key]?.value {
                                            Text("\(key): \(String(describing: argValue))")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(themeManager.secondaryTextColor)
                                        }
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                            
                            // Output
                            if let value = task.result.value {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Output")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(themeManager.primaryTextColor)
                                        .padding(.bottom, 4)
                                    
                                    Text(String(describing: value.value))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(themeManager.primaryTextColor)
                                        .textSelection(.enabled)
                                }
                            }
                            
                            // Error
                            if let error = task.result.error {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Error")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.red)
                                        .padding(.bottom, 4)
                                    
                                    Text(error)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.red)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(themeManager.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Back chevron on the left
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .buttonStyle(.plain)
            }
            
            // Breadcrumb in the center
            ToolbarItem(placement: .principal) {
                HStack(spacing: 4) {
                    Text(sessionName)
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    Text(taskName)
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Task Output Detail View (Shows individual task output)
struct TaskOutputDetailView: View {
    let task: CompletedToolCall
    let taskNumber: Int
    let sessionName: String
    var messageTimestamp: Int64? = nil // Optional timestamp from message
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    // Format timestamp
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.secondaryTextColor)
                    .font(.system(size: 16))
                
                TextField("Search output...", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.primaryTextColor)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeManager.secondaryTextColor)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(themeManager.isDarkMode ? Color(red: 0.11, green: 0.11, blue: 0.11) : Color(red: 0.98, green: 0.98, blue: 0.98))
            .cornerRadius(26)
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 12)
            
            // Task output
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Timestamp (if provided from message)
                    if let timestamp = messageTimestamp {
                        Text(formatTimestamp(timestamp))
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .padding(.bottom, 8)
                    }
                    
                    // Header with tool name and status
                    HStack {
                        Image(systemName: task.result.status == "success" ? "checkmark.circle" : "xmark.circle")
                            .foregroundColor(task.result.status == "success" ? .green : .red)
                            .font(.system(size: 16))
                        
                        Text("\(task.toolCall.name)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Spacer()
                        
                        Text(String(format: "%.2fs", task.duration))
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        Text("• \(task.result.status)")
                            .font(.system(size: 12))
                            .foregroundColor(task.result.status == "success" ? .green : .red)
                    }
                    .padding(.bottom, 4)
                    
                    // Arguments
                    if !task.toolCall.arguments.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arguments")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.bottom, 4)
                            
                            ForEach(Array(task.toolCall.arguments.keys.sorted()), id: \.self) { key in
                                if let argValue = task.toolCall.arguments[key]?.value {
                                    Text("\(key): \(String(describing: argValue))")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // Full output/result - displayed directly as code
                    if let value = task.result.value {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.bottom, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(String(describing: value.value))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    
                    if let error = task.result.error {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.bottom, 4)
                            
                            Text(error)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.red)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding()
            }
        }
        .background(themeManager.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Back chevron on the left
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .buttonStyle(.plain)
            }
            
            // Breadcrumb in the center
            ToolbarItem(placement: .principal) {
                HStack(spacing: 4) {
                    Text(sessionName)
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    Text(task.toolCall.name)
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)
                }
            }
        }
    }
}

#Preview {
    TaskDetailView(message: Message(role: .assistant, text: "Here's a preview of the task detail view"), completedTasks: [], sessionName: "Test Session")
        .environmentObject(ThemeManager.shared)
}
