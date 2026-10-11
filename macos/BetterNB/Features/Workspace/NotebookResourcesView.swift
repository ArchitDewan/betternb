import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ResourcePreviewTarget: Identifiable {
    let sourceID: String
    let title: String
    var page = 1
    var id: String { sourceID + "-" + String(page) }
    init(sourceID: String, title: String, page: Int = 1) {
        self.sourceID = sourceID; self.title = title; self.page = page
    }
    init(reference: TutorSource) {
        let parts = reference.sourceID.components(separatedBy: ".p")
        sourceID = parts[0]; title = reference.title
        page = parts.count > 1 ? Int(parts[1].components(separatedBy: ".")[0]) ?? 1 : 1
    }
}

struct NotebookResourcesView: View {
    let sources: CourseSourceStore
    let review: CourseReviewStore
    let courseTitle: String
    let onRead: (String) -> Void
    @Environment(\.workspaceZoom) private var zoom
    @State private var query = ""
    @State private var category: ResourceCategory?
    @State private var isImporting = false
    @State private var worksheetImport = false
    @State private var uploadCategory: ResourceCategory = .other
    @State private var localError: String?
    @State private var preview: ResourcePreviewTarget?
    var filtered: [CourseSourceRecord] {
        sources.sources.filter { (query.isEmpty || $0.filename.localizedCaseInsensitiveContains(query)) &&
            (category == nil || review.category($0.id) == category) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22 * zoom) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Course materials").font(LemmaTypography.pageTitle(zoom))
                        Text("\(courseTitle) · \(sources.sources.count) files").font(LemmaTypography.caption(zoom)).foregroundStyle(LemmaColors.textSecondary)
                    }
                    Spacer()
                    Menu {
                        ForEach([ResourceCategory.outline, .textbook, .notes, .other]) { kind in
                            Button("Upload \(kind.rawValue.lowercased()) PDF") { uploadCategory = kind; worksheetImport = false; isImporting = true }
                        }
                        Button("Upload scanned worksheet or image") { uploadCategory = .worksheet; worksheetImport = true; isImporting = true }
                    } label: { LemmaMenuLabel(title: "Add material", symbol: "plus", tint: LemmaColors.toolSummary, emphasized: true) }
                    .lemmaMenu()
                    .disabled(sources.isImporting)
                }
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(LemmaColors.textTertiary)
                        TextField("Find a file…", text: $query).textFieldStyle(.plain)
                    }.lemmaInput()
                    Menu {
                        Button("All materials") { category = nil }
                        ForEach(ResourceCategory.allCases) { kind in Button(kind.rawValue) { category = kind } }
                    } label: { LemmaMenuLabel(title: category?.rawValue ?? "All types", symbol: "line.3.horizontal.decrease") }
                    .lemmaMenu()
                }
                if sources.isImporting { ProgressView("Reading resource…") }
                if let error = localError ?? sources.errorMessage ?? review.errorMessage { Text(error).foregroundStyle(.red) }
                if sources.isLoading { ProgressView("Loading resources…") }
                if filtered.isEmpty && !sources.isLoading {
                    ContentUnavailableView(query.isEmpty ? "Add course material" : "No matching resources",
                        systemImage: "books.vertical", description: Text("Add an outline, textbook, lecture notes, or worksheet. Use them throughout this notebook."))
                }
                ForEach(filtered) { source in
                    HStack(spacing: 16) {
                        Image(systemName: source.mediaType == "application/pdf" ? "doc.text" : "photo").font(.title2).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 5) {
                            Button(source.filename) { preview = ResourcePreviewTarget(sourceID: source.id, title: source.filename) }.buttonStyle(.plain)
                            Text("\(source.pageCount) pages").font(.caption).foregroundStyle(.secondary)
                            if !source.unreadablePages.isEmpty { Text("Unreadable pages: " + source.unreadablePages.map(String.init).joined(separator: ", ")).font(.caption).foregroundStyle(.orange) }
                        }
                        Spacer()
                        Menu {
                            ForEach(ResourceCategory.allCases) { kind in Button(kind.rawValue) { review.setCategory(source.id, kind) } }
                        } label: { LemmaMenuLabel(title: review.category(source.id).rawValue) }
                        .lemmaMenu().accessibilityLabel("File type for " + source.filename)
                        if source.mediaType == "application/pdf" { Button { onRead(source.id) } label: { Image(systemName: "arrow.up.right") }.buttonStyle(LemmaButtonStyle(kind: .quiet)).accessibilityLabel("Read " + source.filename) }
                    }.padding(12).reviewSurface(tint: LemmaColors.toolSummary)
                }
            }.buttonStyle(LemmaButtonStyle()).font(LemmaTypography.ui(zoom)).padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24).frame(maxWidth: 1100).frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .task { await sources.refresh() }
        .sheet(item: $preview) { ResourcePreviewView(sources: sources, target: $0) }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: worksheetImport ? [.pdf, .png, .jpeg, .heic] : [.pdf], allowsMultipleSelection: worksheetImport) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            let kind = uploadCategory, useOCR = worksheetImport
            Task {
                do {
                    let attachment = try await Task.detached {
                        if useOCR { return try MessageAttachment.importingWorksheetFiles(urls) }
                        return try MessageAttachment.importingWorksheet(url)
                    }.value
                    if useOCR {
                        if let source = await sources.importWorksheet(attachment) { review.setCategory(source.id, kind) }
                    } else if let source = await sources.importPDFRecord(attachment) {
                        review.setCategory(source.id, kind)
                    }
                    localError = nil
                } catch { localError = "That resource could not be opened. Choose a supported file within the upload limit." }
            }
        }
    }
}

struct ResourcePreviewView: View {
    let sources: CourseSourceStore
    let target: ResourcePreviewTarget
    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    @State private var image: NSImage?
    @State private var error: String?
    var body: some View {
        VStack {
            HStack { Text(target.title).font(.headline); Spacer(); Button("Close") { dismiss() } }.padding()
            if let document { ResourcePDFPreview(document: document, page: target.page) }
            else if let image { Image(nsImage: image).resizable().scaledToFit() }
            else if let error { ContentUnavailableView("Resource unavailable", systemImage: "doc.questionmark", description: Text(error)) }
            else { ProgressView() }
        }.buttonStyle(LemmaButtonStyle()).frame(minWidth: 600, minHeight: 460).frame(idealWidth: 760, idealHeight: 600)
        .task(id: target.id) {
            do {
                let data = try await sources.document(for: target.sourceID)
                document = PDFDocument(data: data)
                if document == nil { image = NSImage(data: data) }
                if document == nil && image == nil { error = "This file could not be displayed." }
            } catch { self.error = "The resource could not be loaded. Check the tutor service and try again." }
        }
    }
}
private struct ResourcePDFPreview: NSViewRepresentable {
    let document: PDFDocument
    let page: Int
    func makeNSView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; return view }
    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
            if let target = document.page(at: max(0, min(page - 1, document.pageCount - 1))) { view.go(to: target) }
        }
    }
}
