//
//  MarkdownTestView.swift
//  Goose
//
//  Test view to verify markdown rendering
//

import SwiftUI

struct MarkdownTestView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let testMarkdown = """
# Heading 1
## Heading 2
### Heading 3

This is a paragraph with **bold text**, *italic text*, and `inline code`.

Here's a [link to example](https://example.com).

## Lists

### Unordered List
- First item
- Second item
- Third item with more text to test wrapping behavior

### Ordered List
1. First numbered item
2. Second numbered item
3. Third numbered item

## Code Block

```swift
func example() {
    print("Hello, World!")
}
```

## Table

| Name | Age | City |
|------|----:|------|
| Alice | 30 | New York |
| Bob | 25 | San Francisco |
| Charlie | 35 | Los Angeles |

## Wide Table (Test Scrolling)

| Sunday | Monday | Tuesday | Wednesday | Thursday | Friday | Saturday |
|:------:|:------:|:-------:|:---------:|:--------:|:------:|:--------:|
| | | | | | 1 | 2 |
| 3 | 4 | 5 | 6 | 7 | 8 | 9 |
| 10 | 11 | 12 | 13 | 14 | 15 | 16 |
| 17 | 18 | 19 | 20 | 21 | 22 | 23 |
| 24 | 25 | 26 | 27 | 28 | 29 | 30 |
| 31 | | | | | | |

## Mixed Content

This paragraph comes **before** a table.

| Feature | Status |
|---------|--------|
| Bold | ✅ |
| Italic | ✅ |
| Code | ✅ |

And this paragraph comes **after** the table.

## Edge Cases

Empty cells in table:

| A | B | C |
|---|---|---|
| 1 | | 3 |
| | 2 | |

Very long text in a cell to test wrapping:

| Short | Very Long Text Column |
|-------|----------------------|
| A | This is a very long piece of text that should demonstrate how the table handles content that extends beyond normal cell width |
| B | Another long piece of text to ensure consistent behavior across multiple rows |
"""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Test in assistant message context
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assistant Message Context")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack(alignment: .top, spacing: 0) {
                            VStack(alignment: .leading, spacing: 8) {
                                MarkdownText(text: testMarkdown)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                        .padding(.bottom, 8)
                        .padding(.top, 8)
                    }
                    .background(Color(.systemBackground))
                    
                    Divider()
                    
                    // Test in user message context
                    VStack(alignment: .leading, spacing: 8) {
                        Text("User Message Context")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Spacer()
                            MarkdownText(text: "**User message** with *markdown*", isUserMessage: true)
                                .padding(12)
                                .background(Color.blue)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Markdown Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if DEBUG
struct MarkdownTestView_Previews: PreviewProvider {
    static var previews: some View {
        MarkdownTestView()
    }
}
#endif
