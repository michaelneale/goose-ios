import SwiftUI
import MarkdownUI

/// Custom markdown theme optimized for chat interface
struct ChatMarkdownTheme: MarkdownTheme {
    var text: Text.Style {
        TextStyle(fontSize: .em(1.0), fontWeight: nil)
    }
    
    var link: Link.Style {
        LinkStyle(foregroundColor: .blue, underline: true)
    }
    
    var code: CodeStyle {
        CodeStyle(
            backgroundColor: Color(.systemGray5).opacity(0.7),
            cornerRadius: 4,
            fontSize: .em(0.9),
            fontFamilyVariant: .monospaced,
            padding: .vertical(2) + .horizontal(4)
        )
    }
    
    var strong: Text.Style {
        TextStyle(fontWeight: .bold)
    }
    
    var emphasis: Text.Style {
        TextStyle(fontStyle: .italic)
    }
    
    var heading1: Text.Style {
        TextStyle(fontSize: .em(1.6), fontWeight: .bold)
    }
    
    var heading2: Text.Style {
        TextStyle(fontSize: .em(1.4), fontWeight: .bold)
    }
    
    var heading3: Text.Style {
        TextStyle(fontSize: .em(1.2), fontWeight: .semibold)
    }
    
    var paragraph: BlockStyle {
        ParagraphBlockStyle()
    }
    
    var blockquote: BlockStyle {
        BlockquoteStyle()
    }
    
    var codeBlock: BlockStyle {
        CodeBlockStyle()
    }
    
    var listItem: BlockStyle {
        ListItemStyle()
    }
    
    var unorderedList: BlockStyle {
        UnorderedListStyle()
    }
    
    var orderedList: BlockStyle {
        OrderedListStyle()
    }
    
    var thematicBreak: BlockStyle {
        ThematicBreakStyle()
    }
}

// MARK: - Custom Block Styles

struct ParagraphBlockStyle: BlockStyle {
    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 2) {
                configuration.label
                    .lineSpacing(4)
            }
        )
    }
}

struct BlockquoteStyle: BlockStyle {
    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 3)
                
                configuration.label
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
        )
    }
}

struct CodeBlockStyle: BlockStyle {
    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(
            configuration.label
                .font(.system(size: 12, design: .monospaced))
                .padding(12)
                .background(Color(.systemGray5).opacity(0.8))
                .cornerRadius(8)
        )
    }
}

struct ListItemStyle: BlockStyle {
    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(
            HStack(alignment: .top, spacing: 10) {
                Text("•")
                    .frame(width: 14, alignment: .leading)
                    .font(.system(size: 16, weight: .semibold))
                
                configuration.label
                    .lineSpacing(2)
            }
        )
    }
}

struct UnorderedListStyle: BlockStyle {
    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                configuration.label
            }
            .padding(.vertical, 4)
        )
    }
}

struct OrderedListStyle: BlockStyle {
    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                configuration.label
            }
            .padding(.vertical, 4)
        )
    }
}

struct ThematicBreakStyle: BlockStyle {
    func makeBody(configuration: Configuration) -> AnyView {
        AnyView(
            Divider()
                .padding(.vertical, 8)
        )
    }
}
