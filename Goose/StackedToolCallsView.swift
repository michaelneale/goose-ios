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

            Group {
                if toolCalls.count == 1 {
                    // Single tool call - show normal card (no stacking)
                    ToolCallCardView(toolCallState: toolCalls[0])
                        .background(Color.green.opacity(0.2))
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
                        .background(Color.green.opacity(0.2))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        let _ = {
            print("\n🎨 === TOOL CALL STACK DEBUG ===")
            print("📊 Total tool calls: \(toolCalls.count)")
            print("👁️  Visible cards: \(visibleToolCalls.count)")
            print("📋 Tool calls:")
            for (index, call) in toolCalls.enumerated() {
                let name = call.toolCall.name
                let status = call.isCompleted ? "✅" : "⏳"
                print("   [\(index)] \(status) \(name) (id: \(call.id.prefix(8)))")
            }
            print("🎨 === END STACK DEBUG ===\n")
        }()
        
        ZStack(alignment: .top) {
            // Show only the top 3 cards (or fewer if less than 3)
            ForEach(Array(visibleToolCalls.enumerated()), id: \.element.id) { index, call in
                ToolCallCardView(toolCallState: call)
                    .offset(y: CGFloat(index) * cardOffsetIncrement)
                    .scaleEffect(1.0 - CGFloat(index) * cardScaleDecrement)
                    .shadow(
                        color: .black.opacity(0.05),
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
        .background(Color.blue.opacity(0.2)) // Light blue debug background
        .padding(.bottom, 16)
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
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
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
    
    @State private var dragState: DragState = .inactive
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width * 0.75
    private let cardSpacing: CGFloat = 16
    
    private enum DragState {
        case inactive
        case dragging
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Close button in top right
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        onCollapse()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 24, height: 24)
                        )
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
            .zIndex(1)

            // Horizontal scroll with peek preview and snap
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cardSpacing) {
                        ForEach(Array(toolCalls.enumerated()), id: \.element.id) { index, call in
                            ToolCallCardView(toolCallState: call)
                                .frame(width: cardWidth)
                                .scaleEffect(selectedIndex == index ? 1.0 : 0.92)
                                .opacity(selectedIndex == index ? 1.0 : 0.7)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedIndex)
                                .id(index)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedIndex = index
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, (UIScreen.main.bounds.width - cardWidth) / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { _ in
                                dragState = .dragging
                            }
                            .onEnded { value in
                                dragState = .inactive
                                // Calculate which card we're closest to based on drag
                                let dragDistance = value.translation.width
                                let cardPlusSpacing = cardWidth + cardSpacing
                                let threshold = cardPlusSpacing / 3
                                
                                if dragDistance < -threshold && selectedIndex < toolCalls.count - 1 {
                                    // Swiped left - go to next
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedIndex += 1
                                    }
                                } else if dragDistance > threshold && selectedIndex > 0 {
                                    // Swiped right - go to previous
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedIndex -= 1
                                    }
                                } else {
                                    // Snap back to current
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        proxy.scrollTo(selectedIndex, anchor: .center)
                                    }
                                }
                            }
                    )
                }
                .onChange(of: selectedIndex) { _, newIndex in
                    if dragState == .inactive {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                .onAppear {
                    proxy.scrollTo(selectedIndex, anchor: .center)
                }
            }
            .frame(height: 220)
            
            // Counter and navigation
            HStack(spacing: 20) {
                Button(action: {
                    if selectedIndex > 0 {
                        withAnimation {
                            selectedIndex -= 1
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(selectedIndex > 0 ? .primary : .gray)
                }
                .disabled(selectedIndex == 0)
                
                Spacer()
                
                Text("\(selectedIndex + 1) of \(toolCalls.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    if selectedIndex < toolCalls.count - 1 {
                        withAnimation {
                            selectedIndex += 1
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(selectedIndex < toolCalls.count - 1 ? .primary : .gray)
                }
                .disabled(selectedIndex == toolCalls.count - 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(Color.green.opacity(0.2))
        }
        .padding(.horizontal, -16)  // Extend into ChatView gutter to show peek preview
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
