import SwiftUI

final class WorkspaceAppearance: ObservableObject {
    @Published var factor: CGFloat = WorkspaceZoom.comfortable

    var canZoomIn: Bool { factor < WorkspaceZoom.maximum }
    var canZoomOut: Bool { factor > WorkspaceZoom.minimum }

    func zoomIn() {
        factor = WorkspaceZoom.clamped(factor + WorkspaceZoom.step)
    }

    func zoomOut() {
        factor = WorkspaceZoom.clamped(factor - WorkspaceZoom.step)
    }

    func reset() {
        factor = WorkspaceZoom.comfortable
    }
}

private struct WorkspaceZoomKey: EnvironmentKey {
    static let defaultValue: CGFloat = WorkspaceZoom.comfortable
}

extension EnvironmentValues {
    var workspaceZoom: CGFloat {
        get { self[WorkspaceZoomKey.self] }
        set { self[WorkspaceZoomKey.self] = newValue }
    }
}

extension View {
    func zFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        zoom: CGFloat
    ) -> some View {
        font(.system(size: size * zoom, weight: weight, design: design))
    }
}

struct ZoomCommands: Commands {
    @ObservedObject var appearance: WorkspaceAppearance

    var body: some Commands {
        CommandMenu("View") {
            Button("Zoom In") {
                appearance.zoomIn()
            }
            .keyboardShortcut("+")
            .disabled(!appearance.canZoomIn)

            Button("Zoom Out") {
                appearance.zoomOut()
            }
            .keyboardShortcut("-")
            .disabled(!appearance.canZoomOut)

            Button("Reset Zoom") {
                appearance.reset()
            }
            .keyboardShortcut("0")
        }
    }
}

struct ZoomKeyShortcuts: View {
    @ObservedObject var appearance: WorkspaceAppearance

    var body: some View {
        Button("Zoom In") {
            appearance.zoomIn()
        }
        .keyboardShortcut("=", modifiers: .command)
        .disabled(!appearance.canZoomIn)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
