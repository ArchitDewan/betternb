import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.067, green: 0.067, blue: 0.067)
    static let sidebar = Color(red: 0.047, green: 0.047, blue: 0.047)
    static let panel = Color(red: 0.082, green: 0.082, blue: 0.082)
    static let paper = Color(red: 0.110, green: 0.110, blue: 0.110)
    static let elevated = Color(red: 0.137, green: 0.137, blue: 0.137)
    static let elevatedHover = Color(red: 0.176, green: 0.176, blue: 0.176)
    static let selection = Color.white.opacity(0.10)
    static let stroke = Color.white.opacity(0.08)
    static let strongStroke = Color.white.opacity(0.18)
    static let primaryText = Color(red: 0.94, green: 0.94, blue: 0.94)
    static let secondaryText = Color(red: 0.69, green: 0.69, blue: 0.69)
    static let tertiaryText = Color(red: 0.46, green: 0.46, blue: 0.46)
    static let inverseText = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let critical = Color(red: 0.95, green: 0.42, blue: 0.42)
    static let verified = Color(red: 0.42, green: 0.78, blue: 0.56)
    static let caution = Color(red: 0.93, green: 0.72, blue: 0.34)

    // Compatibility names for study-specific emphasis. The shell remains monochrome.
    static let ink = primaryText
    static let chalk = secondaryText
    static let accent = primaryText

    static let cornerRadius: CGFloat = 16
    static let compactCornerRadius: CGFloat = 10
    static let pagePadding: CGFloat = 28
    static let sidebarInset: CGFloat = 8
    static let composerMaxWidth: CGFloat = 768
}
