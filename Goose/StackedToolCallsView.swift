//
//  StackedToolCallsView.swift
//  Goose
//
//  Created on 10/24/25.
//  Tool call stacking with Time Machine-style carousel
//

import SwiftUI

/// Represents a tool call that can be either active or completed
/// Represents a tool call that can be either active or completed
/// Represents a tool call that can be either active or completed
enum ToolCallState: Identifiable {
    case active(id: String, timing: ToolCallWithTiming)
    case completed(id: String, completed: CompletedToolCall)
    
    // Unique ID for SwiftUI ForEach
    var id: String {
        switch self {
        case .active(let id, _):
            return id
        case .completed(let id, _):
            return id
        }
    }
    
    var toolCall: ToolCall {
        switch self {
        case .active(_, let timing):
            return timing.toolCall
        case .completed(_, let completed):
            return completed.toolCall
        }
    }
    
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}

/// Main container for tool call stacking
/// Handles single card vs stacked cards vs expanded carousel
/// Main container for tool call stacking
/// Handles single card vs stacked cards vs expanded carousel
struct StackedToolCallsView: View {
    let toolCalls: [ToolCallState]
    let showGroupInfo: Bool
    
    @State private var isExpanded = false
    @State private var selectedIndex = 0
    
    init(toolCalls: [ToolCallState], showGroupInfo: Bool = false) {
        self.toolCalls = toolCalls
        self.showGroupInfo = showGroupInfo
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Group info header (only for grouped items)
            if showGroupInfo && toolCalls.count > 1 {
                GroupHeaderView(toolCalls: toolCalls)
            }
            
            Group {
                if toolCalls.count == 1 {
                    // Single tool call - show normal card (no stacking)
                    ToolCallCardView(toolCallState: toolCalls[0])
                } else {
                    // Multiple tool calls - show stack or carousel
                    if isExpanded {
                        // Expanded state - carousel view
                        ToolCallCarouselView(
                            toolCalls: toolCalls,
                            selectedIndex: $selectedIndex,
                            onCollapse: {
                                isExpanded = false
                            }
                        )
                    } else {
                        // Collapsed state - stacked cards
                        ToolCallStackView(
                            toolCalls: toolCalls,
                            onTap: {
                                print("🎯 Stack tapped - expanding to carousel")
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isExpanded = true
                                }
                            }
                        )
                    }
                }
            }
        }
        .onChange(of: toolCalls.count) { oldValue, newValue in
            // Auto-collapse if only 1 tool call remains
            if newValue <= 1 && isExpanded {
                withAnimation {
                    isExpanded = false
                }
            }
            // Reset selected index if out of bounds
            if selectedIndex >= newValue {
                selectedIndex = max(0, newValue - 1)
            }
        }
    }
}

/// Header showing grouped tool call information
struct GroupHeaderView: View {
    let toolCalls: [ToolCallState]
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("Grouped: \(toolCalls.count) tool calls")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Show unique tool names
            if !uniqueToolNames.isEmpty {
                Text(uniqueToolNames.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 4)
    }
    
    private var uniqueToolNames: [String] {
        let names = Set(toolCalls.map { $0.toolCall.name })
        return Array(names).sorted().map { name in
            // Shorten common prefixes
            name.replacingOccurrences(of: "computercontroller__", with: "")
        }
    }
}


/// Stacked cards view (collapsed state)
/// Shows up to 3 cards with depth effect
struct ToolCallStackView: View {
    let toolCalls: [ToolCallState]
    let onTap: () -> Void
    
    // Visual constants
    private let maxVisibleCards = 3
    private let cardOffsetIncrement: CGFloat = 4
    private let cardScaleDecrement: CGFloat = 0.02
    private let baseShadowRadius: CGFloat = 5
    
    var body: some View {
        ZStack {
            // Show only the top 3 cards (or fewer if less than 3)
            ForEach(Array(visibleToolCalls.enumerated()), id: \.element.id) { index, call in
                ToolCallCardView(toolCallState: call)
                    .offset(y: CGFloat(index) * cardOffsetIncrement)
                    .scaleEffect(1.0 - CGFloat(index) * cardScaleDecrement)
                    .shadow(
                        color: .black.opacity(0.15),
                        radius: baseShadowRadius - CGFloat(index),
                        x: 0,
                        y: CGFloat(index) * 2
                    )
                    .zIndex(Double(visibleToolCalls.count - index))
                    // Only top card should be interactive in stack mode
                    .allowsHitTesting(index == 0)
            }
            
            // Show indicator if there are more than 3 cards
            if toolCalls.count > maxVisibleCards {
                VStack {
                    Spacer()
                    Text("+\(toolCalls.count - maxVisibleCards) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 2)
                        )
                        .offset(y: CGFloat(maxVisibleCards) * cardOffsetIncrement + 8)
                }
            }
        }
        .contentShape(Rectangle()) // Make entire stack tappable
        .onTapGesture {
            onTap()
        }
    }
    
    /// Returns up to 3 tool calls for display
    private var visibleToolCalls: [ToolCallState] {
        Array(toolCalls.prefix(maxVisibleCards))
    }
}



/// Card view that can display both active and completed tool calls
struct ToolCallCardView: View {
    let toolCallState: ToolCallState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with tool name and status indicator
            HStack(spacing: 8) {
                if toolCallState.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Text(toolCallState.toolCall.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Arguments snippet
            if !toolCallState.toolCall.arguments.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(getArgumentSnippets()), id: \.key) { item in
                        HStack(alignment: .top, spacing: 4) {
                            Text("\(item.key):")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text(item.value)
                                .font(.caption2)
                                .monospaced()
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.leading, 24)
            }
            
            // Status text
            Text(toolCallState.isCompleted ? "completed" : "executing...")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 24)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(toolCallState.isCompleted ? Color.green.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7)
    }
    
    private func getArgumentSnippets() -> [(key: String, value: String)] {
        let maxArgs = 3
        let maxValueLength = 40
        
        return toolCallState.toolCall.arguments
            .sorted { $0.key < $1.key }
            .prefix(maxArgs)
            .map { key, value in
                let valueString = String(describing: value.value)
                let truncated = valueString.count > maxValueLength 
                    ? String(valueString.prefix(maxValueLength)) + "..." 
                    : valueString
                return (key: key, value: truncated)
            }
    }
}

/// Carousel view (expanded state)
/// Time Machine-style vertical carousel with navigation
struct ToolCallCarouselView: View {
    let toolCalls: [ToolCallState]
    @Binding var selectedIndex: Int
    let onCollapse: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        onCollapse()
                    }
                }
            
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            onCollapse()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .background(
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 32, height: 32)
                            )
                    }
                    .padding()
                }
                
                // Carousel with TabView
                TabView(selection: $selectedIndex) {
                    ForEach(Array(toolCalls.enumerated()), id: \.element.id) { index, call in
                        ToolCallCardView(toolCallState: call)
                            .padding(.horizontal, 20)
                            .scaleEffect(selectedIndex == index ? 1.0 : 0.85)
                            .rotation3DEffect(
                                .degrees(selectedIndex == index ? 0 : 15),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.5
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedIndex)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 350)
                
                // Navigation counter
                HStack {
                    Text("\(selectedIndex + 1) of \(toolCalls.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 2)
                        )
                }
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct StackedToolCallsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            Text("Single Tool Call")
                .font(.headline)
            StackedToolCallsView(toolCalls: [mockToolCall(name: "web_scrape")])
            
            Text("Two Tool Calls")
                .font(.headline)
            StackedToolCallsView(toolCalls: [
                mockToolCall(name: "web_scrape"),
                mockToolCall(name: "automation_script")
            ])
            
            Text("Three Tool Calls")
                .font(.headline)
            StackedToolCallsView(toolCalls: [
                mockToolCall(name: "web_scrape"),
                mockToolCall(name: "automation_script"),
                mockToolCall(name: "pdf_tool")
            ])
            
            Text("Four Tool Calls")
                .font(.headline)
            StackedToolCallsView(toolCalls: [
                mockToolCall(name: "web_scrape"),
                mockToolCall(name: "automation_script"),
                mockToolCall(name: "pdf_tool"),
                mockToolCall(name: "xlsx_tool")
            ])
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
    
    
    static func mockToolCall(name: String) -> ToolCallState {
        .active(
            id: UUID().uuidString,
            timing: ToolCallWithTiming(
                toolCall: ToolCall(
                    name: name,
                    arguments: [
                        "url": AnyCodable("https://example.com"),
                        "save_as": AnyCodable("text")
                    ]
                ),
                startTime: Date()
            )
        )
    }
}
#endif
