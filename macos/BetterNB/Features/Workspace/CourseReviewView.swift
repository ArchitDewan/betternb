import SwiftUI
import UniformTypeIdentifiers

struct ReviewNotebookOverview: View {
    let notebooks: [CourseNotebook]
    let accountID: String
    let onOpen: (String) -> Void
    @Environment(\.workspaceZoom) private var zoom
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20 * zoom) {
                Text("Review").font(LemmaTypography.pageTitle(zoom))
                Text("Choose a course to review.").foregroundStyle(.secondary)
                ForEach(notebooks) { notebook in
                    Button { onOpen(notebook.id) } label: {
                        HStack(spacing: 16) {
                            ReviewIcon(symbol: "book.closed", tint: LemmaColors.toolSummary)
                            Text(notebook.title).font(LemmaTypography.sectionTitle(zoom))
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }.padding(20 * zoom).reviewSurface(tint: LemmaColors.toolSummary)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.font(LemmaTypography.ui(zoom)).foregroundStyle(LemmaColors.textPrimary)
                .padding(LemmaSpacing.page * zoom).frame(maxWidth: 1080).frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct CourseReviewView: View {
    let title: String
    let store: CourseReviewStore
    let sources: CourseSourceStore
    let problems: ProblemSetStore
    let onBack: () -> Void
    @Environment(\.workspaceZoom) private var zoom
    @State private var isImporting = false
    @State private var uploading = false
    @State private var generating = false
    @State private var refreshing = true
    @State private var generationTask: Task<Void, Never>?
    @State private var error: String?

    private var busy: Bool { uploading || generating || refreshing }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24 * zoom) {
                Button(action: onBack) { Label("All courses", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(title) review").font(LemmaTypography.pageTitle(zoom))
                    Text("Upload your materials, then generate your review. A course outline and lecture slides work best.")
                        .foregroundStyle(LemmaColors.textSecondary)
                }
                VStack(alignment: .leading, spacing: 18) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { actions }
                        VStack(alignment: .leading, spacing: 12) { actions }
                    }
                    if uploading || generating || refreshing {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(uploading ? "Uploading materials…" : generating ? "Generating your review…" : "Loading materials…")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !sources.sources.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(sources.sources.count) material\(sources.sources.count == 1 ? "" : "s")")
                                .font(LemmaTypography.caption(zoom)).foregroundStyle(.secondary)
                            ForEach(sources.sources) { source in
                                Label(source.filename, systemImage: "doc.text")
                                    .font(LemmaTypography.caption(zoom)).foregroundStyle(LemmaColors.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }.padding(20 * zoom).frame(maxWidth: .infinity, alignment: .leading)
                    .reviewSurface(tint: LemmaColors.toolSummary)
                if let error = error ?? store.errorMessage ?? sources.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                ForEach(Array(store.units.enumerated()), id: \.element.id) { index, unit in
                    let tint = [LemmaColors.toolChat, LemmaColors.toolSummary, LemmaColors.toolQuiz][index % 3]
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(.system(size: 13 * zoom, weight: .semibold, design: .monospaced))
                                .foregroundStyle(tint).frame(width: 36, height: 36)
                                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                            Text(unit.title).font(LemmaTypography.sectionTitle(zoom))
                        }
                        ForEach(unit.topics) { topic in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(topic.title).font(LemmaTypography.ui(zoom).weight(.semibold))
                                Text(topic.description).foregroundStyle(LemmaColors.textSecondary)
                                    .textSelection(.enabled)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(20 * zoom).reviewSurface(tint: tint)
                }
            }.font(LemmaTypography.ui(zoom)).foregroundStyle(LemmaColors.textPrimary)
                .padding(LemmaSpacing.page * zoom).frame(maxWidth: 1100).frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task { await sources.refresh(); refreshing = false }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): upload(urls)
            case .failure: error = "The files could not be opened. Try uploading them again."
            }
        }
        .onDisappear { generationTask?.cancel() }
    }

    @ViewBuilder private var actions: some View {
        Button { isImporting = true } label: { Label("Upload materials", systemImage: "plus") }
            .buttonStyle(LemmaButtonStyle()).disabled(busy)
        Button(action: generate) { Label("Generate review", systemImage: "sparkles") }
            .buttonStyle(LemmaButtonStyle(kind: .primary))
            .disabled(busy || sources.sources.isEmpty)
    }

    private func upload(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard urls.count + sources.sources.count <= 20 else {
            error = "A review supports up to 20 PDF materials. Choose fewer files."; return
        }
        uploading = true; error = nil
        Task {
            var failed: [String] = []
            for url in urls {
                do {
                    let attachment = try await Task.detached { try MessageAttachment.importingWorksheet(url) }.value
                    if await sources.importPDFRecord(attachment) == nil { failed.append(url.lastPathComponent) }
                } catch { failed.append(url.lastPathComponent) }
            }
            if !failed.isEmpty { error = "Could not upload: \(failed.joined(separator: ", ")). Use readable PDFs under 25 MB each and try again." }
            uploading = false
        }
    }

    private func generate() {
        let materials = sources.sources
        guard let primary = materials.first(where: {
            store.category($0.id) == .outline || $0.filename.localizedCaseInsensitiveContains("outline") || $0.filename.localizedCaseInsensitiveContains("syllabus")
        }) ?? materials.first else { return }
        guard materials.count <= 20 else { error = "A review supports up to 20 PDF materials."; return }
        let ids = [primary.id] + materials.filter { $0.id != primary.id }.map(\.id)
        generating = true; error = nil
        generationTask?.cancel()
        let client = AppDependencies.makeCourseStudyClient(), courseID = sources.courseID
        generationTask = Task {
            do {
                let result = try await client.generateRoadmap(courseID: courseID, sourceIDs: ids, primarySourceID: primary.id)
                guard !Task.isCancelled else { generating = false; return }
                let units = result.editableUnits
                if store.approve(units, sourceIDs: ids) {
                    problems.detachTopics(except: Set(units.flatMap(\.topics).map(\.id)))
                }
            } catch {
                if !Task.isCancelled { self.error = reviewError(error) }
            }
            generating = false
        }
    }
}

func reviewError(_ error: Error) -> String {
    if case TutorServiceError.rejected(let message) = error { return message }
    return "This could not be generated. Check the tutor service and your materials, then try again."
}
