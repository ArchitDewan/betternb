import AppKit
import SwiftUI

enum LemmaColors {
    // Cursor Dark Anysphere / glass UI: editor and sidebar are #181818, chrome is #141414,
    // text is #F0F0F0, and the accent is #599CE7. Elevated bubbles and the composer sit at #2C2C2C.
    static let background = adaptive(light: 0xFCFCFC, dark: 0x181818)
    static let sidebar = adaptive(light: 0xF3F3F3, dark: 0x181818)
    static let topBar = adaptive(light: 0xF3F3F3, dark: 0x181818)
    static let surface = adaptive(light: 0xFCFCFC, dark: 0x181818)
    static let surfaceElevated = adaptive(light: 0xFFFFFF, dark: 0x2C2C2C)
    static let surfaceHover = adaptive(light: 0xE8E8E8, dark: 0x242424)
    static let selection = adaptive(light: 0xE4E4E4, dark: 0x2C2C2C)
    static let divider = adaptive(light: 0xE5E5E5, dark: 0x2B2B2B)
    static let textPrimary = adaptive(light: 0x141414, dark: 0xF0F0F0)
    static let textSecondary = adaptive(light: 0x5C5C5C, dark: 0xB8B8B8)
    static let textTertiary = adaptive(light: 0x8A8A8A, dark: 0x8A8A8A)
    static let border = adaptive(light: 0xD6D6D6, dark: 0x3A3A3A)
    static let borderStrong = adaptive(light: 0xBDBDBD, dark: 0x4A4A4A)
    static let accent = adaptive(light: 0x2778C1, dark: 0x599CE7)
    static let accentMuted = adaptive(light: 0xE7F1FA, dark: 0x1E2A36)
    static let success = adaptive(light: 0x3F765B, dark: 0x3FA266)
    static let warning = adaptive(light: 0x9A6B2D, dark: 0xF1B467)
    static let error = adaptive(light: 0xA64743, dark: 0xFC6B83)
    static let onAccent = adaptive(light: 0xFCFCFC, dark: 0x141414)
    static let onInk = adaptive(light: 0xFCFCFC, dark: 0x141414)

    /// Soft selection wash. A solid gray pill reads as a flat chip; Cursor’s row is a translucent lift on the glass.
    static let selectionWash = Color.primary.opacity(0.12)
    static let hoverWash = Color.primary.opacity(0.06)
    static let hairline = Color.primary.opacity(0.10)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

enum LemmaSpacing {
    static let page: CGFloat = 28
    static let section: CGFloat = 22
    static let card: CGFloat = 20
    static let row: CGFloat = 8
}

enum LemmaRadius {
    static let card: CGFloat = 12
    static let control: CGFloat = 8
    static let composer: CGFloat = 12
}

enum LemmaTypography {
    // Sidebar stays at Cursor’s 13px. The main pane is one step larger so it does not sit tiny in the window.
    static func pageTitle(_ zoom: CGFloat) -> Font { .system(size: 22 * zoom, weight: .semibold) }
    static func sectionTitle(_ zoom: CGFloat) -> Font { .system(size: 16 * zoom, weight: .semibold) }
    static func conceptTitle(_ zoom: CGFloat) -> Font { .system(size: 20 * zoom, weight: .semibold) }
    static func body(_ zoom: CGFloat) -> Font { .system(size: 16 * zoom) }
    static func ui(_ zoom: CGFloat) -> Font { .system(size: 14 * zoom) }
    static func caption(_ zoom: CGFloat) -> Font { .system(size: 13 * zoom) }
}

enum AppTheme {
    // Compatibility aliases while existing surfaces adopt the shared Lemma tokens.
    static let canvas = LemmaColors.background
    static let sidebar = LemmaColors.sidebar
    static let panel = LemmaColors.surface
    static let paper = LemmaColors.surface
    static let elevated = LemmaColors.surfaceElevated
    static let elevatedHover = LemmaColors.surfaceHover
    static let selection = LemmaColors.selection
    static let stroke = LemmaColors.border
    static let strongStroke = LemmaColors.borderStrong
    static let primaryText = LemmaColors.textPrimary
    static let secondaryText = LemmaColors.textSecondary
    static let tertiaryText = LemmaColors.textTertiary
    static let inverseText = LemmaColors.onInk
    static let critical = LemmaColors.error
    static let verified = LemmaColors.success
    static let caution = LemmaColors.warning
    static let coach = LemmaColors.accent
    static let coachFill = LemmaColors.accentMuted
    static let ink = LemmaColors.textPrimary
    static let chalk = LemmaColors.textSecondary
    static let accent = LemmaColors.accent

    static let cornerRadius = LemmaRadius.card
    static let compactCornerRadius = LemmaRadius.control
    static let pagePadding = LemmaSpacing.page
    static let sidebarInset: CGFloat = 10
    static let composerMaxWidth: CGFloat = 800
    static let practiceMeasure: CGFloat = 880
}

/// Behind-window vibrancy. The view must sit on a non-opaque window or it collapses into a flat fill.
struct LemmaVibrancy: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configure(view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        configure(view)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
    }
}

extension View {
    /// Dark smoked glass. The black wash keeps Cursor’s neutral darkness without painting an opaque slab.
    func lemmaGlass(material: NSVisualEffectView.Material = .hudWindow) -> some View {
        background {
            ZStack {
                LemmaVibrancy(material: material)
                Color.black.opacity(0.22)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    func lemmaComposerGlass(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background {
                LemmaVibrancy(material: .hudWindow, blendingMode: .withinWindow)
                    .clipShape(shape)
            }
        }
    }
}
