import SwiftUI

struct TextbookSummaryView: View {
    @Bindable var sources: CourseSourceStore
    let selectedSource: CourseSourceRecord?
    let onManageSources: () -> Void

    @State private var summary: GeneratedTextbookSummary?
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26 * zoom) {
                heading
                if let selectedSource {
                    if let summary {
                        summaryContent(summary, source: selectedSource)
                    } else {
                        setup(source: selectedSource)
                    }
                } else {
                    ContentUnavailableView(
                        "No readable PDF yet", systemImage: "doc.badge.plus",
                        description: Text("Add a course source to make a summary.")
                    )
                    Button("Open Sources", action: onManageSources)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: 620 * zoom, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24 * zoom)
            .padding(.vertical, 28 * zoom)
        }
        .scrollIndicators(.automatic)
    }

    private var heading: some View {
        HStack(alignment: .top, spacing: 14 * zoom) {
            Image(systemName: "doc.text")
                .font(.system(size: 23 * zoom))
                .foregroundStyle(LemmaColors.toolSummary)
                .frame(width: 48 * zoom, height: 48 * zoom)
                .background(LemmaColors.toolSummary.opacity(0.13),
                            in: RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
            VStack(alignment: .leading, spacing: 5 * zoom) {
                Text("Summary")
                    .font(LemmaTypography.pageTitle(zoom))
                    .foregroundStyle(LemmaColors.textPrimary)
                Text("A focused map of the ideas in your source.")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func setup(source: CourseSourceRecord) -> some View {
        VStack(alignment: .leading, spacing: 22 * zoom) {
            HStack(alignment: .top, spacing: 11 * zoom) {
                Image(systemName: "doc.text")
                    .font(.system(size: 16 * zoom))
                    .foregroundStyle(LemmaColors.toolSummary)
                    .frame(width: 30 * zoom, height: 30 * zoom)
                    .background(LemmaColors.toolSummary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 7 * zoom))
                VStack(alignment: .leading, spacing: 3 * zoom) {
                    Text(source.filename)
                        .font(LemmaTypography.ui(zoom).weight(.semibold))
                        .foregroundStyle(LemmaColors.textPrimary)
                        .lineLimit(2)
                    Text("\(source.pageCount) pages · Selected PDF")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            Rectangle().fill(LemmaColors.divider).frame(height: 1)
            VStack(alignment: .leading, spacing: 7 * zoom) {
                sectionLabel("READING GUIDE")
                Text("Find the ideas worth understanding")
                    .font(LemmaTypography.sectionTitle(zoom))
                    .foregroundStyle(LemmaColors.textPrimary)
                Text("A concise overview and key ideas, each linked to its place in the PDF.")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = sources.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.error)
            }
            Button {
                Task { await generate(for: source) }
            } label: {
                HStack(spacing: 9 * zoom) {
                    if sources.isGeneratingSummary {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(sources.isGeneratingSummary ? "Creating summary…" : "Create summary")
                    if !sources.isGeneratingSummary {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11 * zoom, weight: .semibold))
                    }
                }
                .font(LemmaTypography.ui(zoom).weight(.semibold))
                .foregroundStyle(LemmaColors.toolSummary)
                .padding(.horizontal, 15 * zoom)
                .frame(height: 38 * zoom)
                .background(LemmaColors.toolSummary.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
            }
            .buttonStyle(.plain)
            .disabled(sources.isGeneratingSummary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryContent(_ summary: GeneratedTextbookSummary,
                                source: CourseSourceRecord) -> some View {
        VStack(alignment: .leading, spacing: 26 * zoom) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5 * zoom) {
                    Text(source.filename)
                        .font(LemmaTypography.sectionTitle(zoom))
                        .foregroundStyle(LemmaColors.textPrimary)
                    Text("Based on selected excerpts · \(source.pageCount) pages in source")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                }
                Spacer()
                Button("Regenerate") { Task { await generate(for: source) } }
                    .buttonStyle(.plain)
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.toolSummary)
                    .disabled(sources.isGeneratingSummary)
            }
            if sources.isGeneratingSummary { ProgressView("Refreshing summary…") }
            VStack(alignment: .leading, spacing: 12 * zoom) {
                sectionLabel("OVERVIEW")
                TutorMathText(source: summary.overview, fontSize: 16 * zoom)
            }
            Rectangle().fill(LemmaColors.divider).frame(height: 1)
            VStack(alignment: .leading, spacing: 23 * zoom) {
                sectionLabel("KEY IDEAS")
                ForEach(Array(summary.ideas.enumerated()), id: \.offset) { index, idea in
                    HStack(alignment: .top, spacing: 16 * zoom) {
                        Text(String(format: "%02d", index + 1))
                            .font(LemmaTypography.caption(zoom).weight(.semibold))
                            .foregroundStyle(LemmaColors.toolSummary)
                            .frame(width: 28 * zoom, alignment: .leading)
                        VStack(alignment: .leading, spacing: 8 * zoom) {
                            Text(idea.heading)
                                .font(LemmaTypography.ui(zoom).weight(.semibold))
                                .foregroundStyle(LemmaColors.textPrimary)
                            TutorMathText(source: idea.explanation, fontSize: 15 * zoom)
                            TextbookSourcesControl(sources: idea.sources)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11 * zoom, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(LemmaColors.textSecondary)
    }

    private func generate(for source: CourseSourceRecord) async {
        if let generated = await sources.generateSummary(sourceID: source.id) {
            summary = generated
        }
    }
}
