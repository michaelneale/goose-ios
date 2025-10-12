//
//  ThemeManager.swift
//  Goose
//
//  Created by Thomas Petersen on 10/9/25.
//

import SwiftUI

class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    static let shared = ThemeManager()
    
    init() {
        // Check if isDarkMode has been set before
        if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
            // First launch - default to dark mode
            self.isDarkMode = true
            UserDefaults.standard.set(true, forKey: "isDarkMode")
        } else {
            self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        }
    }
    
    var colorScheme: ColorScheme {
        isDarkMode ? .dark : .light
    }
    
    // Background colors
    var backgroundColor: Color {
        isDarkMode ? .black : Color(.systemBackground)
    }
    
    var secondaryBackgroundColor: Color {
        isDarkMode ? Color(red: 0.13, green: 0.13, blue: 0.13) : Color(red: 0.98, green: 0.98, blue: 0.98)
    }
    
    // Text colors
    var primaryTextColor: Color {
        isDarkMode ? .white : .black
    }
    
    var secondaryTextColor: Color {
        isDarkMode ? Color(red: 0.35, green: 0.35, blue: 0.35) : Color(.secondaryLabel)
    }
    
    // Border colors
    var borderColor: Color {
        isDarkMode ? Color(red: 0.35, green: 0.35, blue: 0.35) : Color(red: 0.91, green: 0.91, blue: 0.91)
    }
    
    // Input field colors
    var inputBackgroundColor: Color {
        isDarkMode ? Color(red: 0.13, green: 0.13, blue: 0.13) : Color(red: 0.98, green: 0.98, blue: 0.98)
    }
    
    var inputBorderColor: Color {
        isDarkMode ? Color(red: 0.35, green: 0.35, blue: 0.35) : Color(red: 0.91, green: 0.91, blue: 0.91)
    }
    
    var inputPlaceholderColor: Color {
        isDarkMode ? Color(red: 0.35, green: 0.35, blue: 0.35) : Color(red: 0.40, green: 0.40, blue: 0.40)
    }
    
    // Chat input box colors
    var chatInputBackgroundColor: Color {
        isDarkMode ? Color(red: 0.10, green: 0.10, blue: 0.13) : Color(red: 0.97, green: 0.97, blue: 0.97)
    }
    
    var chatInputBorderColor: Color {
        isDarkMode ? Color(red: 0.14, green: 0.14, blue: 0.17) : Color(red: 0.88, green: 0.88, blue: 0.88)
    }
    
    var chatInputButtonBorderColor: Color {
        isDarkMode ? Color(red: 0.18, green: 0.18, blue: 0.20) : Color(red: 0.82, green: 0.82, blue: 0.82)
    }
    
    var chatInputIconColor: Color {
        isDarkMode ? Color(red: 0.85, green: 0.85, blue: 0.85) : Color(red: 0.40, green: 0.40, blue: 0.40)
    }
    
    var chatInputTextColor: Color {
        isDarkMode ? Color(red: 0.98, green: 0.98, blue: 0.98) : Color(red: 0.15, green: 0.15, blue: 0.15)
    }
}

