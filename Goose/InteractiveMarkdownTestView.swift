import SwiftUI

struct InteractiveMarkdownTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var customMarkdown: String = "Type your **markdown** here to test it!"
    @State private var selectedTestCase = 0
    
    private let testCases = MarkdownRenderingTests.getManualTestCases()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Test case selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Test Case:")
                        .font(.headline)
                    
                    Picker("Test Case", selection: $selectedTestCase) {
                        ForEach(0..<testCases.count, id: \.self) { index in
                            Text(testCases[index].title).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedTestCase) { _, newValue in
                        customMarkdown = testCases[newValue].markdown
                    }
                    
                    Text("Expected: \(testCases[selectedTestCase].expectedBehavior)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Split view: Input and Output
                HSplitView {
                    // Input section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Markdown Input")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TextEditor(text: $customMarkdown)
                            .font(.monospaced(.body)())
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // Output section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rendered Output")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                MarkdownText(text: customMarkdown)
                                    .textSelection(.enabled)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                
                Divider()
                
                // Quick test buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Tests")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            QuickTestButton(title: "Bold", markdown: "**Bold text**") {
                                customMarkdown = "**Bold text**"
                            }
                            
                            QuickTestButton(title: "Italic", markdown: "*Italic text*") {
                                customMarkdown = "*Italic text*"
                            }
                            
                            QuickTestButton(title: "Code", markdown: "`inline code`") {
                                customMarkdown = "`inline code`"
                            }
                            
                            QuickTestButton(title: "Link", markdown: "[Link](https://apple.com)") {
                                customMarkdown = "[Link](https://apple.com)"
                            }
                            
                            QuickTestButton(title: "Heading", markdown: "# Heading") {
                                customMarkdown = "# Heading"
                            }
                            
                            QuickTestButton(title: "Code Block", markdown: "```\ncode block\n```") {
                                customMarkdown = "```\ncode block\n```"
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGray6))
            }
            .navigationTitle("Interactive Markdown Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            customMarkdown = testCases[0].markdown
        }
    }
}

struct QuickTestButton: View {
    let title: String
    let markdown: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(markdown)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Helper view for split layout on iOS
struct HSplitView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 1) {
                    content
                }
                
                VStack(spacing: 1) {
                    content
                }
            }
        } else {
            // Fallback for older iOS versions
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    HStack(spacing: 1) {
                        content
                    }
                } else {
                    VStack(spacing: 1) {
                        content
                    }
                }
            }
        }
    }
}

#Preview {
    InteractiveMarkdownTestView()
}
