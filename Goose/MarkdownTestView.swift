import SwiftUI

struct MarkdownTestView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Test markdown content covering all major features
    private let testMarkdownContent = """
# Markdown Rendering Test

This view tests various markdown formatting features to ensure proper rendering in the GooseChat app.

## Text Formatting

**Bold text** should appear in bold weight.

*Italic text* should appear in italic style.

***Bold and italic*** should combine both styles.

## Code Formatting

Here's some `inline code` that should appear with monospace font and background highlighting.

### Code Blocks

```swift
func testFunction() {
    print("This is a code block")
    let variable = "with syntax highlighting"
    return variable
}
```

```python
def python_example():
    # This is a Python code block
    items = [1, 2, 3, 4, 5]
    return [x * 2 for x in items]
```

## Links

Here's a [link to Apple](https://apple.com) that should be clickable and styled.

Visit [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui) for more information.

## Headings

# Heading 1 - Largest
## Heading 2 - Large  
### Heading 3 - Medium
#### Heading 4 - Small
##### Heading 5 - Smaller
###### Heading 6 - Smallest

## Lists

### Unordered List
• First item
• Second item  
• Third item with **bold** text
• Fourth item with `inline code`

### Mixed Content
This paragraph contains **bold text**, *italic text*, `inline code`, and a [link](https://github.com).

## Special Characters

Testing special characters: & < > " ' 

## Line Breaks

This is the first line.

This is after a blank line.

## Complex Example

Here's a complex example combining multiple features:

**Project Setup:**
1. Clone the repository
2. Install dependencies with `npm install`
3. Run the development server using `npm start`
4. Visit [localhost:3000](http://localhost:3000) to see the app

*Note: Make sure you have Node.js installed before running these commands.*

```bash
git clone https://github.com/example/project.git
cd project
npm install
npm start
```

That's it! Your markdown rendering should handle all these cases properly.
"""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Markdown Rendering Test")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("This view tests the markdown rendering capabilities of the GooseChat app. Scroll through to verify all formatting works correctly.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom)
                    
                    Divider()
                    
                    // Test content using the same MarkdownText view used in messages
                    VStack(alignment: .leading, spacing: 12) {
                        MarkdownText(text: testMarkdownContent)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Divider()
                    
                    // Interactive test section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Interactive Test")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("The content above should demonstrate:")
                            .font(.subheadline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ChecklistItem(text: "Bold text formatting (**text**)")
                            ChecklistItem(text: "Italic text formatting (*text*)")
                            ChecklistItem(text: "Inline code formatting (`code`)")
                            ChecklistItem(text: "Code blocks with proper background")
                            ChecklistItem(text: "Different heading sizes (H1-H6)")
                            ChecklistItem(text: "Clickable links with proper styling")
                            ChecklistItem(text: "List items with bullet points")
                            ChecklistItem(text: "Mixed formatting within text")
                            ChecklistItem(text: "Proper line breaks and spacing")
                        }
                        .padding(.leading)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .padding()
            }
            .navigationTitle("Markdown Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ChecklistItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
                .padding(.top, 2)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    MarkdownTestView()
}
