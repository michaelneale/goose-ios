# MarkdownUI Customization Guide

## Overview
MarkdownUI is a powerful Swift Package Manager library for rendering Markdown in SwiftUI with extensive customization options.

**Repository**: https://github.com/gonzalezreal/swift-markdown-ui

## Key Customization Options

### 1. Built-in Themes
MarkdownUI comes with predefined themes:
```swift
Markdown(markdownString)
  .markdownTheme(.gitHub)
```

Available themes:
- `.gitHub` - GitHub markdown style
- `.docC` - Apple DocC style
- Custom themes can be created

### 2. Text Style Customization
Override specific text element styles:
```swift
.markdownTextStyle(\.code) {
  FontFamilyVariant(.monospaced)
  FontSize(.em(0.85))
  ForegroundColor(.purple)
  BackgroundColor(.purple.opacity(0.25))
}

.markdownTextStyle(\.strong) {
  FontWeight(.bold)
}

.markdownTextStyle(\.emphasis) {
  FontStyle(.italic)
}
```

### 3. Block Style Customization
Control how block elements (lists, quotes, etc.) are rendered:
```swift
.markdownBlockStyle(\.blockquote) { configuration in
  configuration.label
    .padding()
    .overlay(alignment: .leading) {
      Rectangle()
        .fill(Color.teal)
        .frame(width: 4)
    }
    .background(Color.teal.opacity(0.5))
}

.markdownBlockStyle(\.listItem) { configuration in
  HStack(alignment: .top, spacing: 8) {
    Text("•")
      .frame(width: 12, alignment: .center)
    configuration.label
  }
}

.markdownBlockStyle(\.unorderedList) { configuration in
  VStack(alignment: .leading, spacing: 8) {
    configuration.label
  }
}

.markdownBlockStyle(\.orderedList) { configuration in
  VStack(alignment: .leading, spacing: 8) {
    configuration.label
  }
}
```

### 4. Commonly Customized Elements
- `\.heading1`, `\.heading2`, etc. - Heading styles
- `\.paragraph` - Paragraph formatting
- `\.code` - Inline code styling
- `\.codeBlock` - Code block containers
- `\.blockquote` - Quote blocks
- `\.thematicBreak` - Horizontal lines
- `\.listItem` - Individual list items
- `\.unorderedList` - Bullet lists
- `\.orderedList` - Numbered lists

### 5. Line Spacing & Spacing Control
```swift
.markdownBlockStyle(\.paragraph) { configuration in
  VStack(alignment: .leading, spacing: 4) {
    configuration.label
      .lineSpacing(6)
  }
}
```

## Benefits Over Plain Text Rendering
✅ Proper bullet indentation (text wraps under bullet)
✅ Professional list formatting
✅ Clean spacing control
✅ Custom styling for all markdown elements
✅ Theme support
✅ Better code block handling
✅ Quote styling
✅ Heading hierarchy

## Implementation Strategy
1. Add MarkdownUI to pbxproj (already done in current setup)
2. Replace Text() rendering with Markdown() component
3. Apply custom block styles for lists to ensure proper indentation
4. Use themes or custom styling for consistency

## Next Steps
- Implement MarkdownUI rendering in MarkdownText component
- Create custom theme or style rules for bullet points
- Test with complex markdown content
- Ensure consistent styling across chat
