//
//  TaskDetailView.swift
//  Goose
//
//  Created by Thomas Petersen on 10/9/25.
//

import SwiftUI

// MARK: - Array Extension for Safe Subscripting
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

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
    
    // Unescape string literals (convert \n, \t, etc. to actual characters)
    private func unescapeString(_ string: String) -> String {
        var result = ""
        var i = string.startIndex
        
        while i < string.endIndex {
            if string[i] == "\\" && string.index(after: i) < string.endIndex {
                let next = string.index(after: i)
                switch string[next] {
                case "n":
                    result.append("\n")
                    i = string.index(after: next)
                case "t":
                    result.append("\t")
                    i = string.index(after: next)
                case "r":
                    result.append("\r")
                    i = string.index(after: next)
                case "\\":
                    result.append("\\")
                    i = string.index(after: next)
                case "\"":
                    result.append("\"")
                    i = string.index(after: next)
                default:
                    result.append(string[i])
                    i = string.index(after: i)
                }
            } else {
                result.append(string[i])
                i = string.index(after: i)
            }
        }
        
        return result
    }
    
    // Format output value (handle JSON and other formats)
    private func formatOutputValue(_ value: Any) -> String {
        // If it's an array of message objects (typical tool output format)
        if let array = value as? [[String: Any]] {
            // Extract text from messages marked for "user" audience
            var outputTexts: [String] = []
            
            for item in array {
                // Check if this is a text message for the user
                if let text = item["text"] as? String,
                   let annotations = item["annotations"] as? [String: Any],
                   let audience = annotations["audience"] as? [String],
                   audience.contains("user") {
                    if !text.isEmpty {
                        outputTexts.append(unescapeString(text))
                    }
                }
            }
            
            // If we found user-facing text, return it
            if !outputTexts.isEmpty {
                return outputTexts.joined(separator: "\n")
            }
            
            // Otherwise, check for any non-empty text
            for item in array {
                if let text = item["text"] as? String, !text.isEmpty {
                    outputTexts.append(unescapeString(text))
                }
            }
            
            if !outputTexts.isEmpty {
                return outputTexts.joined(separator: "\n")
            }
            
            // If no text found, fall back to formatted JSON
            if let jsonData = try? JSONSerialization.data(withJSONObject: array, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        }
        
        // If it's a dictionary, try to extract text or format as JSON
        if let dict = value as? [String: Any] {
            // Check if it's a single message object with text
            if let text = dict["text"] as? String, !text.isEmpty {
                return unescapeString(text)
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        }
        
        // If it's a string, check if it's already formatted JSON
        if let string = value as? String {
            // If it starts with { or [, it might be JSON
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) {
                // Try to parse and reformat
                if let data = trimmed.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    return prettyString
                }
            }
            return unescapeString(string)
        }
        
        // Fallback to string description
        return String(describing: value)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Timestamp at the top
                    Text(formatTimestamp(message.created))
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding(.bottom, 4)
                        .padding(.top, 100) // Add padding for custom nav bar
                
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
                                    
                                    MarkdownText(text: formatOutputValue(value.value), isUserMessage: false)
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
        
            // Custom navigation bar overlay with frosted glass
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Back button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.primaryTextColor)
                            .frame(width: 44, height: 44)
                    }
                    .padding(.leading, 4)
                    
                    // Breadcrumb (left-aligned) - positioned to match main chat session name at 48px
                    HStack(spacing: 4) {
                        Text(sessionName)
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Text(taskName)
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 0)
                .padding(.top, 56)
                .padding(.bottom, 12)
            }
            .background(
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    Rectangle()
                        .fill(themeManager.backgroundColor.opacity(0.95))
                }
                .ignoresSafeArea()
            )
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
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
    @State private var searchMatches: [Int] = []
    @State private var currentMatchIndex: Int = 0
    @State private var outputLines: [String] = []
    
    // Format timestamp
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Search functionality
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchMatches = []
            currentMatchIndex = 0
            return
        }
        
        searchMatches = []
        for (index, line) in outputLines.enumerated() {
            if line.lowercased().contains(searchText.lowercased()) {
                searchMatches.append(index)
            }
        }
        
        if !searchMatches.isEmpty {
            currentMatchIndex = 0
        }
    }
    
    private func nextMatch() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
    }
    
    private func previousMatch() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + searchMatches.count) % searchMatches.count
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Task output with padding for nav bar
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
                    
                    // Full output/result - displayed directly as code with line numbers
                    if let value = task.result.value {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(themeManager.primaryTextColor)
                                .padding(.bottom, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(outputLines.enumerated()), id: \.offset) { index, line in
                                        HStack(alignment: .top, spacing: 12) {
                                            // Line number
                                            Text("\(index + 1)")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
                                                .frame(minWidth: 40, alignment: .trailing)
                                            
                                            // Line content with search highlight
                                            if searchMatches.contains(index) {
                                                Text(line)
                                                    .font(.system(size: 12, design: .monospaced))
                                                    .foregroundColor(themeManager.primaryTextColor)
                                                    .background(
                                                        searchMatches[safe: currentMatchIndex] == index ?
                                                            Color.orange.opacity(0.4) : Color.yellow.opacity(0.3)
                                                    )
                                                    .id("line-\(index)")
                                            } else {
                                                Text(line)
                                                    .font(.system(size: 12, design: .monospaced))
                                                    .foregroundColor(themeManager.primaryTextColor)
                                            }
                                            
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .textSelection(.enabled)
                            }
                        }
                        .onAppear {
                            // Split output into lines
                            let outputString = String(describing: value.value)
                            outputLines = outputString.components(separatedBy: .newlines)
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
                    .padding(.top, 0) // Padding for nav bar (matches main chat)
                    .padding(.bottom, 100) // Padding for search bar
                }
            }
            .background(themeManager.backgroundColor)
            
            // Search field at bottom
            VStack {
                Spacer()
                
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .font(.system(size: 16))
                    
                    TextField("Search output...", text: $searchText)
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.primaryTextColor)
                        .onChange(of: searchText) { oldValue, newValue in
                            performSearch()
                        }
                    
                    if !searchMatches.isEmpty {
                        Text("\(currentMatchIndex + 1)/\(searchMatches.count)")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        Button(action: previousMatch) {
                            Image(systemName: "chevron.up")
                                .foregroundColor(themeManager.secondaryTextColor)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: nextMatch) {
                            Image(systemName: "chevron.down")
                                .foregroundColor(themeManager.secondaryTextColor)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchMatches = []
                            currentMatchIndex = 0
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
                .background(themeManager.chatInputBackgroundColor.opacity(0.85))
                .cornerRadius(26)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        
        
            // Custom navigation bar overlay with frosted glass
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Back button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.primaryTextColor)
                            .frame(width: 44, height: 44)
                    }
                    .padding(.leading, 4)
                    
                    // Breadcrumb (left-aligned) - positioned to match main chat session name at 48px
                    HStack(spacing: 4) {
                        Text(sessionName)
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Text(task.toolCall.name)
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 0)
                .padding(.top, 56)
                .padding(.bottom, 24)
            }
            .background(
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    Rectangle()
                        .fill(themeManager.backgroundColor.opacity(0.95))
                }
                .ignoresSafeArea()
            )
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
    }
}

#Preview {
    TaskDetailView(message: Message(role: .assistant, text: "Here's a preview of the task detail view"), completedTasks: [], sessionName: "Test Session")
        .environmentObject(ThemeManager.shared)
}

