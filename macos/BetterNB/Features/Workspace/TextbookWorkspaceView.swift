import PDFKit
import SwiftUI

private struct TextbookSelection {
    let text: String
    let page: Int
}

private struct TextbookExchange: Identifiable {
    let id = UUID()
    let question: String
    let answer: GroundedCourseAnswer
}

private enum TextbookTool: String, CaseIterable, Identifiable {
    case home, chat, summary, flashcards, quiz

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .home: "square.grid.2x2"
        case .chat: "bubble.left"
        case .summary: "doc.text"
        case .flashcards: "square.stack.3d.up"
        case .quiz: "questionmark.circle"
        }
    }
    var tint: Color {
        switch self {
        case .home: LemmaColors.accent
        case .chat: LemmaColors.toolChat
        case .summary: LemmaColors.toolSummary
        case .flashcards: LemmaColors.toolFlashcards
        case .quiz: LemmaColors.toolQuiz
        }
    }
    var subtitle: String {
        switch self {
        case .home: "Your source workspace"
        case .chat: "Ask about a passage"
        case .summary: "Key ideas from a source"
        case .flashcards: "Recall important concepts"
        case .quiz: "Check your understanding"
        }
    }
}

struct TextbookWorkspaceView: View {
    @Bindable var sources: CourseSourceStore
    @Bindable var scratchpad: TextbookScratchpadStore
    let onManageSources: () -> Void

    @State private var selectedSourceID: String?
    @State private var document: PDFDocument?
    @State private var selection: TextbookSelection?
    @State private var documentError: String?
    @State private var isReading = false
    @State private var exchanges: [TextbookExchange] = []
    @State private var activeTool: TextbookTool = .home
    @Environment(\.workspaceZoom) private var zoom

    private var selectedSource: CourseSourceRecord? {
        sources.sources.first { $0.id == selectedSourceID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(LemmaColors.divider).frame(height: 1)
            HSplitView {
                sourcePane.frame(minWidth: 290, idealWidth: 540)
                scratchpadPane.frame(minWidth: 340, idealWidth: 580)
            }
        }
        .background(Color.clear)
        .task {
            await sources.refresh()
            if selectedSourceID == nil, let first = sources.sources.first { await open(first.id) }
        }
        .onChange(of: sources.sources) { _, updated in
            if selectedSourceID == nil, let first = updated.first { Task { await open(first.id) } }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Textbook").font(LemmaTypography.pageTitle(zoom))
                    .foregroundStyle(LemmaColors.textPrimary)
                Text("Read beside your thinking.")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }
            Spacer()
            Button(action: onManageSources) {
                Label("Sources", systemImage: "books.vertical")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, LemmaSpacing.page)
        .padding(.vertical, 18)
    }

    private var sourcePane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text").foregroundStyle(LemmaColors.textSecondary)
                if sources.sources.isEmpty {
                    Text("No course PDF yet").foregroundStyle(LemmaColors.textSecondary)
                } else {
                    Picker("Source", selection: Binding(
                        get: { selectedSourceID ?? sources.sources[0].id },
                        set: { id in Task { await open(id) } }
                    )) {
                        ForEach(sources.sources) { source in
                            Text(source.filename).tag(source.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let source = selectedSource {
                    Text("\(source.pageCount) pages")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textTertiary)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 50)
            Rectangle().fill(LemmaColors.divider).frame(height: 1)

            Group {
                if let document {
                    TextbookPDFReader(document: document) { text, page in
                        selection = TextbookSelection(text: text, page: page)
                    }
                } else if isReading {
                    ProgressView("Opening PDF…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        documentError ?? "Bring your course material here",
                        systemImage: "book.closed",
                        description: Text(documentError == nil
                            ? "Add a PDF to read it beside your notes and questions."
                            : "Open Sources to check the PDF or try again.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.clear)

            if let selection, let source = selectedSource {
                HStack(spacing: 12) {
                    Text("Page \(selection.page) · \(selection.text)")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Quote in chat") {
                        scratchpad.quote(sourceID: source.id, title: source.filename,
                                         page: selection.page, text: selection.text)
                        activeTool = .chat
                        self.selection = nil
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Pin excerpt") {
                        scratchpad.pin(sourceID: source.id, title: source.filename,
                                       page: selection.page, text: selection.text)
                        self.selection = nil
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
                .lemmaComposerGlass(cornerRadius: LemmaRadius.card)
            }
        }
    }

    private var scratchpadPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolBar
            Rectangle().fill(LemmaColors.divider).frame(height: 1)
            switch activeTool {
            case .home:
                homePane
            case .chat:
                chatPane
            case .summary, .flashcards, .quiz:
                previewPane(for: activeTool)
            }
        }
        .background(Color.clear)
    }

    private var toolBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(TextbookTool.allCases) { tool in
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) { activeTool = tool }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: tool.symbol)
                                .foregroundStyle(tool.tint)
                            Text(tool.title)
                                .foregroundStyle(activeTool == tool
                                    ? LemmaColors.textPrimary : LemmaColors.textSecondary)
                        }
                        .font(.system(size: 12 * zoom, weight: activeTool == tool ? .semibold : .medium))
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(activeTool == tool ? LemmaColors.selectionWash : Color.clear,
                                    in: RoundedRectangle(cornerRadius: LemmaRadius.control))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(activeTool == tool ? .isSelected : [])
                }
            }
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
        .frame(height: 50)
    }

    private var homePane: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("FROM YOUR TEXTBOOK")
                        Text("Study this source")
                            .font(LemmaTypography.sectionTitle(zoom))
                            .foregroundStyle(LemmaColors.textPrimary)
                        Text("Keep the page open while you explore an idea.")
                            .font(LemmaTypography.caption(zoom))
                            .foregroundStyle(LemmaColors.textSecondary)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                        ForEach([TextbookTool.chat, .summary, .flashcards, .quiz]) { tool in
                            Button { activeTool = tool } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: tool.symbol)
                                        .font(.system(size: 18 * zoom, weight: .medium))
                                        .foregroundStyle(tool.tint)
                                        .frame(width: 42, height: 42)
                                        .background(tool.tint.opacity(0.14),
                                                    in: RoundedRectangle(cornerRadius: 11))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tool.title)
                                            .font(LemmaTypography.ui(zoom).weight(.semibold))
                                            .foregroundStyle(LemmaColors.textPrimary)
                                        Text(tool.subtitle)
                                            .font(LemmaTypography.caption(zoom))
                                            .foregroundStyle(LemmaColors.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(LemmaColors.hoverWash,
                                            in: RoundedRectangle(cornerRadius: LemmaRadius.card))
                                .overlay(RoundedRectangle(cornerRadius: LemmaRadius.card)
                                    .stroke(LemmaColors.hairline, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(22)
            }
            Rectangle().fill(LemmaColors.divider).frame(height: 1)
            composerFooter
        }
    }

    private var chatPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if exchanges.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("ASK LEMMA")
                            Text("Ask about what you’re reading")
                                .font(LemmaTypography.sectionTitle(zoom))
                            Text("Select a passage on the left and quote it here, or ask a question about the source.")
                                .font(LemmaTypography.caption(zoom))
                                .foregroundStyle(LemmaColors.textSecondary)
                        }
                    }
                    pinsSection
                    ForEach(exchanges) { exchange in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(exchange.question)
                                .font(LemmaTypography.sectionTitle(zoom))
                            TutorMathText(source: exchange.answer.answer, fontSize: 15 * zoom)
                            if !exchange.answer.sources.isEmpty {
                                Text(exchange.answer.sources.map { "\($0.title) · \($0.section)" }
                                    .joined(separator: "  •  "))
                                    .font(LemmaTypography.caption(zoom))
                                    .foregroundStyle(LemmaColors.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: 700, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(22)
            }
            Rectangle().fill(LemmaColors.divider).frame(height: 1)
            composerFooter
        }
    }

    private var composerFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            chatComposer
            if let error = sources.errorMessage, !error.isEmpty {
                Text(error)
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.error)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private var pinsSection: some View {
        if !scratchpad.pins.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("EQUATION BIN · PINNED EXCERPTS")
                Text("Choose excerpts to include with your next question.")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
                ForEach(scratchpad.pins) { pin in
                    HStack(alignment: .top, spacing: 10) {
                        Toggle("Use", isOn: Binding(
                            get: { pin.isIncluded },
                            set: { _ in scratchpad.toggleIncluded(pin.id) }
                        ))
                        .labelsHidden()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pin.text).lineLimit(3).font(LemmaTypography.ui(zoom))
                            Text("\(pin.title) · page \(pin.page)")
                                .font(LemmaTypography.caption(zoom))
                                .foregroundStyle(LemmaColors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Button { scratchpad.remove(pin.id) } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove pinned excerpt")
                    }
                    .padding(12)
                    .lemmaComposerGlass(cornerRadius: LemmaRadius.card)
                }
            }
        }
    }

    private var chatComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let quote = scratchpad.activeQuote {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LemmaColors.toolChat).frame(width: 3, height: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(quote.title) · page \(quote.page)")
                            .font(LemmaTypography.caption(zoom).weight(.semibold))
                            .foregroundStyle(LemmaColors.toolChat)
                        Text(quote.text)
                            .font(LemmaTypography.caption(zoom))
                            .lineLimit(3)
                    }
                    Spacer(minLength: 0)
                    Button { scratchpad.clearQuote() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove quoted passage")
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask anything about this textbook…", text: $scratchpad.question, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(LemmaTypography.ui(zoom))
                    .onSubmit { Task { await ask() } }
                Button { Task { await ask() } } label: { Image(systemName: "arrow.up") }
                    .buttonStyle(.borderedProminent)
                    .disabled(scratchpad.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || sources.isAnswering || sources.sources.isEmpty)
            }
            Rectangle().fill(LemmaColors.divider).frame(height: 1)
            HStack(spacing: 6) {
                Image(systemName: "books.vertical")
                    .foregroundStyle(LemmaColors.toolChat)
                Text("All course sources")
                    .foregroundStyle(LemmaColors.textSecondary)
                Spacer()
                Text("Ask Lemma")
                    .foregroundStyle(LemmaColors.textTertiary)
            }
            .font(LemmaTypography.caption(zoom))
        }
        .padding(14)
        .lemmaComposerGlass(cornerRadius: LemmaRadius.composer)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, sources.errorMessage == nil ? 18 : 4)
    }

    private func previewPane(for tool: TextbookTool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: tool.symbol)
                .font(.system(size: 25 * zoom))
                .foregroundStyle(tool.tint)
                .frame(width: 56, height: 56)
                .background(tool.tint.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: LemmaRadius.card))
            Text(tool.title).font(LemmaTypography.pageTitle(zoom))
            Text(tool.subtitle)
                .font(LemmaTypography.body(zoom))
                .foregroundStyle(LemmaColors.textSecondary)
            Text("Preview · this study tool is not available yet.")
                .font(LemmaTypography.caption(zoom))
                .foregroundStyle(LemmaColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(28)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 11 * zoom, weight: .semibold, design: .rounded))
            .tracking(1.2).foregroundStyle(LemmaColors.textSecondary)
    }

    private func open(_ sourceID: String) async {
        selectedSourceID = sourceID
        document = nil
        selection = nil
        documentError = nil
        isReading = true
        defer { isReading = false }
        do {
            let data = try await sources.document(for: sourceID)
            guard selectedSourceID == sourceID else { return }
            guard let loaded = PDFDocument(data: data) else {
                documentError = "This PDF could not be opened."
                return
            }
            document = loaded
        } catch {
            guard selectedSourceID == sourceID else { return }
            documentError = "This PDF is unavailable."
        }
    }

    private func ask() async {
        let question = scratchpad.question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        activeTool = .chat
        scratchpad.question = ""
        if let answer = await sources.answer(scratchpad.questionWithContext(question)) {
            exchanges.append(TextbookExchange(question: question, answer: answer))
            scratchpad.finishQuestion()
        } else {
            scratchpad.question = question
        }
    }
}

private struct TextbookPDFReader: NSViewRepresentable {
    let document: PDFDocument
    let onSelection: (String, Int) -> Void

    func makeNSView(context: Context) -> SelectionPDFView {
        let view = SelectionPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.onSelection = onSelection
        return view
    }

    func updateNSView(_ view: SelectionPDFView, context: Context) {
        if view.document !== document { view.document = document }
        view.onSelection = onSelection
    }
}

private final class SelectionPDFView: PDFView {
    var onSelection: ((String, Int) -> Void)?

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        publishSelection()
    }

    override func keyUp(with event: NSEvent) {
        super.keyUp(with: event)
        publishSelection()
    }

    private func publishSelection() {
        guard let selected = currentSelection,
              let text = selected.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              let page = selected.pages.first,
              let index = document?.index(for: page), index >= 0
        else { return }
        onSelection?(text, index + 1)
    }
}
