import Collaboration
import SwiftUI

struct SidebarView: View {
    @Binding var selection: WorkspaceDestination
    let recentThreads: [StudyThreadSummary]
    let totalThreadCount: Int
    let activeThreadID: UUID?
    let onOpenStudyDesk: () -> Void
    let onOpenThread: (UUID) -> Void
    let onShowAllThreads: () -> Void
    @EnvironmentObject private var authentication: AuthenticationSession
    @State private var calculusExpanded = true
    private let zoom: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 14 * zoom) {
                    VStack(alignment: .leading, spacing: 1 * zoom) {
                        ForEach(WorkspaceDestination.primary) { destination in
                            LemmaSidebarRow(
                                title: destination.title,
                                systemImage: destination.systemImage,
                                isSelected: selection == destination
                            ) { selection = destination }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2 * zoom) {
                        groupLabel("COURSES")
                        Button {
                            withAnimation(.easeInOut(duration: 0.17)) { calculusExpanded.toggle() }
                        } label: {
                            HStack(spacing: 8 * zoom) {
                                Image(systemName: "folder")
                                    .font(.system(size: 16 * zoom, weight: .regular))
                                    .foregroundStyle(LemmaColors.textSecondary)
                                    .frame(width: 18 * zoom)
                                Text("Calculus I")
                                    .font(.system(size: 13 * zoom))
                                    .foregroundStyle(LemmaColors.textPrimary)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9 * zoom, weight: .semibold))
                                    .foregroundStyle(LemmaColors.textTertiary)
                                    .rotationEffect(.degrees(calculusExpanded ? 90 : 0))
                            }
                            .padding(.horizontal, 10 * zoom)
                            .frame(height: 32 * zoom)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Calculus I")
                        .accessibilityValue(calculusExpanded ? "Expanded" : "Collapsed")

                        if calculusExpanded {
                            VStack(alignment: .leading, spacing: 1 * zoom) {
                                ForEach(WorkspaceDestination.courseTools) { destination in
                                    LemmaSidebarRow(
                                        title: destination.title,
                                        systemImage: destination.systemImage,
                                        isSelected: selection == destination && (destination != .study || activeThreadID == nil),
                                        indentationLevel: 1
                                    ) {
                                        if destination == .study {
                                            onOpenStudyDesk()
                                        } else {
                                            selection = destination
                                        }
                                    }
                                    if destination == .study && !recentThreads.isEmpty {
                                        ForEach(recentThreads) { thread in
                                            LemmaSidebarRow(
                                                title: thread.title,
                                                systemImage: "circle.fill",
                                                isMarker: true,
                                                isSelected: selection == .study && activeThreadID == thread.id,
                                                indentationLevel: 2
                                            ) { onOpenThread(thread.id) }
                                        }
                                        if totalThreadCount > recentThreads.count {
                                            LemmaSidebarRow(
                                                title: "All threads",
                                                systemImage: "ellipsis",
                                                isMarker: true,
                                                isSelected: false,
                                                indentationLevel: 2,
                                                action: onShowAllThreads
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        HStack(spacing: 8 * zoom) {
                            Image(systemName: "folder")
                                .font(.system(size: 16 * zoom))
                                .frame(width: 18 * zoom)
                            Text("Linear Algebra")
                                .font(.system(size: 13 * zoom))
                            Spacer(minLength: 0)
                            Text("Soon")
                                .font(.system(size: 11 * zoom))
                        }
                        .foregroundStyle(LemmaColors.textTertiary)
                        .padding(.horizontal, 10 * zoom)
                        .frame(height: 32 * zoom)
                        .accessibilityElement(children: .combine)
                    }

                    VStack(alignment: .leading, spacing: 1 * zoom) {
                        groupLabel("STUDY TOOLS")
                        ForEach(WorkspaceDestination.studyTools) { destination in
                            LemmaSidebarRow(
                                title: destination.title,
                                systemImage: destination.systemImage,
                                isSelected: selection == destination
                            ) { selection = destination }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6 * zoom)
                .padding(.top, 2 * zoom)
                .padding(.bottom, 8 * zoom)
            }
            .scrollIndicators(.hidden)

            accountFooter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lemmaGlass(material: .sidebar)
        .environment(\.workspaceZoom, 1)
        .navigationSplitViewColumnWidth(min: 248, ideal: 288, max: 320)
    }

    private func groupLabel(_ title: String) -> some View {
        Text(title.capitalized)
            .font(.system(size: 11 * zoom, weight: .medium))
            .foregroundStyle(LemmaColors.textTertiary)
            .padding(.leading, 8 * zoom)
            .padding(.bottom, 2 * zoom)
            .padding(.top, 2 * zoom)
    }

    private var brandHeader: some View {
        HStack(spacing: 8 * zoom) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 16 * zoom, weight: .regular))
                .foregroundStyle(LemmaColors.textSecondary)
                .frame(width: 18 * zoom)
            Text("Lemma")
                .font(.system(size: 13 * zoom, weight: .medium))
                .foregroundStyle(LemmaColors.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14 * zoom)
        .frame(height: 36 * zoom)
    }

    private var accountFooter: some View {
        HStack(spacing: 10 * zoom) {
            AccountProfilePicture(diameter: 28 * zoom)
            Text(MacAccountProfile.name)
                .font(.system(size: 13 * zoom))
                .foregroundStyle(LemmaColors.textPrimary)
                .lineLimit(1)
            if case .offlineAuthenticated = authentication.state {
                Text("Offline")
                    .font(.system(size: 11 * zoom))
                    .foregroundStyle(LemmaColors.textTertiary)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Sign Out", role: .destructive) {
                    Task { await authentication.signOut() }
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15 * zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
                    .frame(width: 28 * zoom, height: 28 * zoom)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12 * zoom)
        .frame(maxWidth: .infinity)
        .frame(height: 52 * zoom)
        .clipped()
        .overlay(alignment: .top) {
            Rectangle().fill(LemmaColors.hairline).frame(height: 1).opacity(0.7)
        }
    }
}

private enum MacAccountProfile {
    static var name: String {
        let parts = NSFullUserName().split(whereSeparator: \.isWhitespace).map(String.init)
        let cleaned = parts.map { part in
            part == part.lowercased() ? part.capitalized : part
        }
        let fullName = cleaned.joined(separator: " ")
        return fullName.isEmpty ? NSUserName() : fullName
    }

    static var image: NSImage? {
        CBIdentity(name: NSUserName(), authority: .default())?.image
    }

    static func circularImage(diameter: CGFloat) -> NSImage? {
        guard let source = image, diameter > 0 else { return nil }
        let size = NSSize(width: diameter, height: diameter)
        let thumbnail = NSImage(size: size, flipped: false) { rect in
            let sourceSize = source.size
            guard sourceSize.width > 0, sourceSize.height > 0 else { return false }
            NSGraphicsContext.current?.imageInterpolation = .high
            let scale = max(rect.width / sourceSize.width, rect.height / sourceSize.height)
            let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            let origin = NSPoint(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2)
            NSBezierPath(ovalIn: rect).addClip()
            source.draw(
                in: NSRect(origin: origin, size: drawSize),
                from: .zero,
                operation: .copy,
                fraction: 1
            )
            return true
        }
        thumbnail.isTemplate = false
        return thumbnail
    }
}

private struct AccountProfilePicture: View {
    let diameter: CGFloat

    var body: some View {
        Group {
            if let image = MacAccountProfile.circularImage(diameter: diameter) {
                Image(nsImage: image)
                    .interpolation(.high)
            } else {
                Text(initials)
                    .font(.system(size: diameter * 0.36, weight: .semibold))
                    .foregroundStyle(LemmaColors.textPrimary)
                    .frame(width: diameter, height: diameter)
                    .background(LemmaColors.accent.opacity(0.85))
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .accessibilityLabel("Account photo")
    }

    private var initials: String {
        let parts = MacAccountProfile.name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "L" : String(letters).uppercased()
    }
}

struct LemmaSidebarRow: View {
    let title: String
    let systemImage: String
    var isMarker = false
    let isSelected: Bool
    var indentationLevel = 0
    let action: () -> Void
    @Environment(\.workspaceZoom) private var zoom
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8 * zoom) {
                Group {
                    if isMarker {
                        Circle()
                            .fill(isSelected ? LemmaColors.textSecondary : LemmaColors.textTertiary)
                            .frame(width: 6 * zoom, height: 6 * zoom)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 16 * zoom, weight: .regular))
                            .foregroundStyle(isSelected ? LemmaColors.textPrimary : LemmaColors.textSecondary)
                    }
                }
                .frame(width: 18 * zoom)
                Text(title)
                    .font(.system(size: 13 * zoom, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? LemmaColors.textPrimary : LemmaColors.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(10 + 16 * indentationLevel) * zoom)
            .padding(.trailing, 10 * zoom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 32 * zoom)
            .background(
                isSelected ? LemmaColors.selectionWash : (isHovering ? LemmaColors.hoverWash : Color.clear),
                in: RoundedRectangle(cornerRadius: 6 * zoom, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(title)
        .help(title)
    }
}
