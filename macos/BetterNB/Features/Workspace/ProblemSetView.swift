import SwiftUI

struct ProblemSetView: View {
    let store: ProblemSetStore
    let onWork: (CourseProblem) -> Void
    @Environment(\.workspaceZoom) private var zoom
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16 * zoom) {
                    header
                    if store.items.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.items) { item in
                            problemCard(item)
                        }
                    }
                }
                .frame(maxWidth: AppTheme.composerMaxWidth * zoom, alignment: .leading)
                .padding(.horizontal, AppTheme.pagePadding * zoom)
                .padding(.top, 26 * zoom)
                .padding(.bottom, 34 * zoom)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)

            addComposer
        }
        .background(AppTheme.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6 * zoom) {
            Text("Problem set")
                .zFont(15, weight: .medium, zoom: zoom)
                .foregroundStyle(AppTheme.secondaryText)
            Text("Keep assigned problems here. Open one in Practice to check steps, take hints, and reveal only if you ask.")
                .zFont(13, zoom: zoom)
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    private var emptyState: some View {
        Text("Paste a homework prompt below. This list is the set; Practice is the working notebook.")
            .zFont(13, zoom: zoom)
            .foregroundStyle(AppTheme.tertiaryText)
    }

    private func problemCard(_ item: CourseProblem) -> some View {
        VStack(alignment: .leading, spacing: 10 * zoom) {
            TutorMathText(source: item.prompt, fontSize: 15 * zoom)
            HStack {
                Text(item.openedInPractice ? "Opened in Practice" : "Not started")
                    .zFont(11, zoom: zoom)
                    .foregroundStyle(AppTheme.tertiaryText)
                Spacer(minLength: 0)
                Button("Work in Practice") {
                    onWork(item)
                }
                .buttonStyle(.plain)
                .zFont(12, weight: .medium, zoom: zoom)
                .foregroundStyle(AppTheme.primaryText)
            }
        }
        .padding(14 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        }
    }

    private var addComposer: some View {
        VStack(alignment: .leading, spacing: 8 * zoom) {
            if draft.contains("\\") || draft.contains("^") {
                TutorMathText(source: draft, fontSize: 14 * zoom)
                    .padding(10 * zoom)
                    .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 10 * zoom, style: .continuous))
            }

            HStack(spacing: 10 * zoom) {
                TextField("Add a problem from the set", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .zFont(15, zoom: zoom)
                    .lineLimit(1...4)
                    .onSubmit(addDraft)

                Button("Add", action: addDraft)
                    .buttonStyle(.plain)
                    .zFont(13, weight: .medium, zoom: zoom)
                    .foregroundStyle(canAdd ? AppTheme.primaryText : AppTheme.tertiaryText)
                    .disabled(!canAdd)
            }
            .padding(10 * zoom)
            .background(AppTheme.elevated, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            }
        }
        .frame(maxWidth: AppTheme.composerMaxWidth * zoom, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.pagePadding * zoom)
        .padding(.top, 10 * zoom)
        .padding(.bottom, 20 * zoom)
    }

    private var canAdd: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addDraft() {
        guard store.add(draft) != nil else { return }
        draft = ""
    }
}