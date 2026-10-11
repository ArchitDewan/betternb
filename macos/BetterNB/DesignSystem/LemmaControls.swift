import SwiftUI

/// The default application action treatment. Native OS dialogs retain system controls.
struct LemmaButtonStyle: ButtonStyle {
    enum Kind { case secondary, primary, quiet }
    var kind: Kind = .secondary
    var tint: Color = LemmaColors.toolSummary
    func makeBody(configuration: Configuration) -> some View {
        ActionBody(configuration: configuration, kind: kind, tint: tint)
    }
    private struct ActionBody: View {
        let configuration: Configuration
        let kind: Kind
        let tint: Color
        @Environment(\.isEnabled) private var enabled
        @Environment(\.workspaceZoom) private var zoom
        @State private var hovered = false
        var body: some View {
            configuration.label
                .font(LemmaTypography.ui(zoom).weight(.medium))
                .foregroundStyle(kind == .primary ? LemmaColors.onAccent : LemmaColors.textPrimary)
                .padding(.horizontal, kind == .quiet ? 8 : 13)
                .padding(.vertical, 8)
                .background(background, in: RoundedRectangle(cornerRadius: LemmaRadius.control))
                .overlay(RoundedRectangle(cornerRadius: LemmaRadius.control)
                    .stroke(kind == .secondary ? LemmaColors.hairline : .clear, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: LemmaRadius.control))
                .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
                .onHover { hovered = $0 }
        }
        private var background: Color {
            if kind == .primary { return tint.opacity(hovered ? 0.85 : 1) }
            return hovered ? LemmaColors.selectionWash : (kind == .quiet ? .clear : LemmaColors.hoverWash)
        }
    }
}

struct LemmaMenuLabel: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = LemmaColors.textSecondary
    var emphasized = false
    @Environment(\.workspaceZoom) private var zoom
    var body: some View {
        HStack(spacing: 7) {
            if let symbol { Image(systemName: symbol) }
            Text(title).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
        }
        .font(LemmaTypography.ui(zoom).weight(.medium))
        .foregroundStyle(emphasized ? tint : LemmaColors.textSecondary)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background((emphasized ? tint : LemmaColors.textSecondary).opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke((emphasized ? tint : LemmaColors.textSecondary).opacity(0.18), lineWidth: 1))
        .fixedSize()
    }
}

extension View {
    func lemmaMenu() -> some View {
        menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    }
    func lemmaInput() -> some View {
        textFieldStyle(.plain).padding(.horizontal, 12).padding(.vertical, 10)
            .background(LemmaColors.hoverWash, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(LemmaColors.hairline, lineWidth: 1))
    }
}
