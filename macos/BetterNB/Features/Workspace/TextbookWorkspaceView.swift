import PDFKit
import SwiftUI
import UniformTypeIdentifiers

private struct TextbookSelection {
    let text: String
    let page: Int
    let anchor: CGPoint
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
    let onPracticeSelection: (String) -> Void

    @State private var selectedSourceID: String?
    @State private var document: PDFDocument?
    @State private var selection: TextbookSelection?
    @State private var documentError: String?
    @State private var isReading = false
    @State private var activeTool: TextbookTool = .home
    @State private var flashcards = TextbookFlashcardStore()
    @State private var composerFocusRequest: UUID?
    @State private var composerBlurRequest: UUID?
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
        .onTapGesture { composerBlurRequest = UUID() }
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
                    TextbookPDFReader(document: document) { updatedSelection in
                        selection = updatedSelection
                        composerBlurRequest = UUID()
                    }
                    .overlay(alignment: .topLeading) {
                        GeometryReader { geometry in
                            if let selection, let source = selectedSource {
                                selectionToolbar(selection, source: source)
                                    .position(
                                        x: min(max(selection.anchor.x, 145 * zoom),
                                               max(geometry.size.width - 145 * zoom, 145 * zoom)),
                                        y: min(max(selection.anchor.y > 65 * zoom
                                            ? selection.anchor.y - 38 * zoom
                                            : selection.anchor.y + 38 * zoom, 24 * zoom),
                                               geometry.size.height - 24 * zoom)
                                    )
                            }
                        }
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

        }
    }

    private func selectionToolbar(_ selection: TextbookSelection, source: CourseSourceRecord) -> some View {
        HStack(spacing: 0) {
            selectionAction("Copy", symbol: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(selection.text, forType: .string)
                self.selection = nil
            }
            selectionDivider
            selectionAction("Add to Chat", symbol: "bubble.left") {
                scratchpad.quote(sourceID: source.id, title: source.filename,
                                 page: selection.page, text: selection.text)
                self.selection = nil
                if activeTool != .home && activeTool != .chat { activeTool = .home }
                composerFocusRequest = UUID()
            }
            selectionDivider
            selectionAction("Practice", symbol: "function") {
                self.selection = nil
                onPracticeSelection(selection.text)
            }
        }
        .padding(.horizontal, 5 * zoom)
        .frame(height: 38 * zoom)
        .background(LemmaColors.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
        .overlay(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom)
            .stroke(LemmaColors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 9 * zoom, y: 4 * zoom)
    }

    private func selectionAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(LemmaTypography.caption(zoom))
                .foregroundStyle(LemmaColors.textPrimary)
                .padding(.horizontal, 9 * zoom)
                .frame(height: 30 * zoom)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var selectionDivider: some View {
        Rectangle()
            .fill(LemmaColors.divider)
            .frame(width: 1, height: 17 * zoom)
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
            case .flashcards:
                TextbookFlashcardsView(flashcards: flashcards, sources: sources,
                                       selectedSource: selectedSource, onManageSources: onManageSources)
            case .summary, .quiz:
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
        .onTapGesture { composerBlurRequest = UUID() }
    }

    private var homePane: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 26 * zoom) {
                        homeContent
                        pinsSection
                        if let latest = scratchpad.exchanges.last {
                            VStack(alignment: .leading, spacing: 16 * zoom) {
                                HStack {
                                    sectionLabel("RECENT CONVERSATION")
                                    Spacer()
                                    Button("Open full chat") { activeTool = .chat }
                                        .buttonStyle(.plain)
                                        .font(LemmaTypography.caption(zoom))
                                        .foregroundStyle(LemmaColors.toolChat)
                                }
                                ScrollView {
                                    exchangeView(latest)
                                        .padding(.trailing, 8 * zoom)
                                }
                                .frame(height: 250 * zoom)
                                .scrollIndicators(.automatic)
                                .id(latest.id)
                            }
                            .id("latestExchange")
                        }
                    }
                    .frame(maxWidth: 700, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 24 * zoom)
                    .padding(.vertical, 28 * zoom)
                }
                .contentShape(Rectangle())
                .onTapGesture { composerBlurRequest = UUID() }
                .onChange(of: scratchpad.exchanges) { _, updated in
                    guard !updated.isEmpty else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("latestExchange", anchor: .bottom)
                    }
                }
            }
            Rectangle().fill(LemmaColors.divider).frame(height: 1)
            composerFooter
        }
    }

    private var chatPane: some View {
        VStack(spacing: 0) {
            conversationScrollView
            Rectangle().fill(LemmaColors.divider).frame(height: 1)
            composerFooter
        }
    }

    private var conversationScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if scratchpad.exchanges.isEmpty {
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
                    ForEach(scratchpad.exchanges) { exchange in
                        exchangeView(exchange).id(exchange.id)
                    }
                }
                .frame(maxWidth: 840, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 24 * zoom)
                .padding(.vertical, 28 * zoom)
            }
            .contentShape(Rectangle())
            .onTapGesture { composerBlurRequest = UUID() }
            .onChange(of: scratchpad.exchanges) { _, updated in
                guard let last = updated.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: activeTool) { _, _ in
                guard let last = scratchpad.exchanges.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 24) {
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
    }

    private func exchangeView(_ exchange: TextbookExchange) -> some View {
        VStack(alignment: .leading, spacing: 20 * zoom) {
            HStack {
                Spacer(minLength: 36 * zoom)
                VStack(alignment: .trailing, spacing: 8 * zoom) {
                    if let attachment = exchange.attachment,
                       let image = NSImage(data: attachment.data) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 220 * zoom, maxHeight: 150 * zoom)
                            .clipShape(RoundedRectangle(cornerRadius: 9 * zoom))
                            .accessibilityLabel("Attached image: \(attachment.filename)")
                    }
                    Text(exchange.question)
                        .font(LemmaTypography.ui(zoom))
                        .foregroundStyle(LemmaColors.textPrimary)
                        .lineSpacing(4 * zoom)
                }
                .padding(.horizontal, 15 * zoom)
                .padding(.vertical, 12 * zoom)
                .background(LemmaColors.surfaceElevated,
                            in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
                .overlay(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom)
                    .stroke(LemmaColors.border, lineWidth: 1))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You")

            if let answer = exchange.answer {
                VStack(alignment: .leading, spacing: 10 * zoom) {
                    sectionLabel("LEMMA")
                    TutorMathText(source: answer.answer, fontSize: 15 * zoom)
                    if !answer.sources.isEmpty {
                        TextbookSourcesControl(sources: answer.sources)
                            .padding(.top, 4 * zoom)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error = exchange.errorMessage {
                HStack(spacing: 8 * zoom) {
                    Image(systemName: "exclamationmark.circle")
                    Text(error)
                }
                .font(LemmaTypography.caption(zoom))
                .foregroundStyle(LemmaColors.error)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 10 * zoom) {
                    ProgressView().controlSize(.small)
                    Text("Lemma is thinking…")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Lemma is thinking")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composerFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            chatComposer
            if let error = sources.errorMessage, !error.isEmpty,
               scratchpad.exchanges.last?.errorMessage != error {
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
            PromptComposer(
                draft: $scratchpad.question,
                attachment: $scratchpad.attachment,
                placeholder: "Ask anything about this textbook…",
                allowedContentTypes: [.png, .jpeg],
                attachmentDescription: "a PNG or JPEG image",
                focusRequest: composerFocusRequest,
                blurRequest: composerBlurRequest,
                onSend: { Task { await ask() } }
            )
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
        .padding(.horizontal, 14)
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
        guard !sources.isAnswering, let submitted = scratchpad.submitQuestion() else { return }
        if let answer = await sources.answer(submitted.prompt, attachment: submitted.attachment) {
            scratchpad.completeQuestion(submitted.id, answer: answer)
        } else {
            scratchpad.failQuestion(submitted.id,
                                    message: sources.errorMessage ?? "A grounded answer couldn’t be generated.")
        }
    }
}

private struct TextbookSourcesControl: View {
    let sources: [TutorSource]
    @State private var showsSources = false
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        Button { showsSources.toggle() } label: {
            Label("\(sources.count) \(sources.count == 1 ? "source" : "sources")", systemImage: "doc.text")
                .font(LemmaTypography.caption(zoom))
                .foregroundStyle(LemmaColors.textSecondary)
        }
        .buttonStyle(.plain)
        .help(sources.map { "\($0.title) · \($0.section)" }.joined(separator: "\n"))
        .popover(isPresented: $showsSources, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8 * zoom) {
                Text("Sources")
                    .font(LemmaTypography.caption(zoom).weight(.semibold))
                ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                    Text("\(source.title) · \(source.section)")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                }
            }
            .padding(14 * zoom)
            .frame(maxWidth: 300 * zoom, alignment: .leading)
        }
    }
}

private struct TextbookPDFReader: NSViewRepresentable {
    let document: PDFDocument
    let onSelection: (TextbookSelection?) -> Void

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
    var onSelection: ((TextbookSelection?) -> Void)?
    private var pendingSelectionUpdate: DispatchWorkItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        observeSelectionChanges()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeSelectionChanges()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func observeSelectionChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: .PDFViewSelectionChanged,
            object: self
        )
    }

    @objc private func selectionDidChange(_ notification: Notification) {
        // PDFKit's document view handles the drag, so PDFView.mouseUp is not
        // guaranteed to run. Publish after the selection settles instead.
        pendingSelectionUpdate?.cancel()
        let update = DispatchWorkItem { [weak self] in self?.publishSelection() }
        pendingSelectionUpdate = update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: update)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        publishSelection(at: convert(event.locationInWindow, from: nil))
    }

    override func keyUp(with event: NSEvent) {
        super.keyUp(with: event)
        publishSelection()
    }

    override func scrollWheel(with event: NSEvent) {
        pendingSelectionUpdate?.cancel()
        onSelection?(nil)
        super.scrollWheel(with: event)
    }

    private func publishSelection(at point: NSPoint? = nil) {
        guard let selected = currentSelection,
              let text = selected.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              let page = selected.pages.first,
              let index = document?.index(for: page), index >= 0
        else {
            onSelection?(nil)
            return
        }
        let localAnchor: NSPoint
        if let point {
            localAnchor = point
        } else {
            let rect = convert(selected.bounds(for: page), from: page)
            localAnchor = NSPoint(x: rect.midX, y: rect.maxY)
        }
        let topDownY = isFlipped ? localAnchor.y : bounds.height - localAnchor.y
        onSelection?(TextbookSelection(text: text, page: index + 1,
                                      anchor: CGPoint(x: localAnchor.x, y: topDownY)))
    }
}
