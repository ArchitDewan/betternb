import SwiftUI

enum AppTheme {
    static let canvas = Color(red: 0.118, green: 0.110, blue: 0.102)
    static let sidebar = Color(red: 0.090, green: 0.084, blue: 0.078)
    static let panel = Color(red: 0.108, green: 0.100, blue: 0.094)
    static let paper = Color(red: 0.155, green: 0.145, blue: 0.132)
    static let elevated = Color(red: 0.175, green: 0.165, blue: 0.150)
    static let elevatedHover = Color(red: 0.210, green: 0.198, blue: 0.180)
    static let stroke = Color.white.opacity(0.07)
    static let primaryText = Color(red: 0.96, green: 0.94, blue: 0.90)
    static let secondaryText = Color(red: 0.78, green: 0.74, blue: 0.68)
    static let tertiaryText = Color(red: 0.55, green: 0.52, blue: 0.47)
    static let ink = Color(red: 0.93, green: 0.76, blue: 0.42)
    static let chalk = Color(red: 0.72, green: 0.84, blue: 0.98)
    static let accent = ink

    static let cornerRadius: CGFloat = 16
    static let compactCornerRadius: CGFloat = 10
    static let pagePadding: CGFloat = 28
    static let sidebarInset: CGFloat = 8
    static let composerMaxWidth: CGFloat = 768
}

extension View {
    func quietRowBackground(isActive: Bool) -> some View {
        background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Color.white.opacity(0.07) : Color.clear)
        }
    }
}
