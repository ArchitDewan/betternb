import SwiftUI

struct PromptComposer: View {
    @Binding var draft: String
    var placeholder = "Ask about this step"
    var onSend: () -> Void = {}
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        HStack(alignment: .bottom, spacing: 10 * zoom) {
            Button {
                // Attachment handling is part of the later interaction milestone.
            } label: {
                Image(systemName: "plus")
                    .zFont(15, weight: .medium, zoom: zoom)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 32 * zoom, height: 32 * zoom)
            }
            .buttonStyle(.plain)
            .help("Add image or file")

            TextField(placeholder, text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .zFont(17, zoom: zoom)
                .lineLimit(1...6)
                .foregroundStyle(AppTheme.primaryText)
                .padding(.vertical, 10 * zoom)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .zFont(12, weight: .bold, zoom: zoom)
                    .foregroundStyle(draft.isEmpty ? AppTheme.tertiaryText : AppTheme.canvas)
                    .frame(width: 32 * zoom, height: 32 * zoom)
                    .background(
                        draft.isEmpty ? AppTheme.elevatedHover : AppTheme.ink,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Send")
        }
        .padding(.leading, 10 * zoom)
        .padding(.trailing, 10 * zoom)
        .padding(.vertical, 6 * zoom)
        .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}
