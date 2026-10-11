import SwiftUI

struct ReviewTopicView: View {
    let topic: ReviewTopic
    let store: CourseReviewStore
    let sources: CourseSourceStore
    let problems: ProblemSetStore
    let onBack: () -> Void
    let onResources: () -> Void
    let onPractice: (CourseProblem) -> Void
    @Environment(\.workspaceZoom) private var zoom
    @State private var sourcePicker = false
    @State private var preview: ResourcePreviewTarget?
    @State private var cardSet: ReviewCardSet?
    @State private var drafts: StudyMaterialDraft?
    @State private var generating = false
    @State private var task: Task<Void, Never>?
    @State private var error: String?
    @State private var showPractice = false
    private var selectedIDs: [String] {
        let current = store.topics.first { $0.id == topic.id } ?? topic
        return current.resourceIDs.isEmpty ? store.sourceIDs : current.resourceIDs
    }
    private var linkedProblems: [CourseProblem] { problems.items.filter { $0.topicID == topic.id } }
    private var sets: [ReviewCardSet] { store.cardSets.filter { $0.topicID == topic.id } }
    private var activity: [ReviewPracticeActivity] { store.practice.filter { $0.topicID == topic.id } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22 * zoom) {
                Button(action: onBack) { Label("Course roadmap", systemImage: "chevron.left") }.buttonStyle(.plain)
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(topic.title).font(LemmaTypography.pageTitle(zoom))
                        Text(topic.description).font(LemmaTypography.ui(zoom)).foregroundStyle(LemmaColors.textSecondary)
                    }
                    Spacer()
                    ReviewStatusMenu(status: Binding(get: { (store.topics.first { $0.id == topic.id })?.status ?? .notStarted }, set: { store.setStatus(topic.id, $0) }))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 12)], spacing: 12) {
                    ReviewToolTile(title: "Flashcards", detail: "Recall the key ideas", symbol: "square.stack.3d.up", tint: LemmaColors.toolFlashcards) { generate(.cards) }
                        .disabled(generating || selectedIDs.isEmpty)
                    ReviewToolTile(title: "Problems", detail: "Build a practice set", symbol: "function", tint: LemmaColors.toolQuiz) { generate(.problems) }
                        .disabled(generating || selectedIDs.isEmpty)
                    ReviewToolTile(title: "Guided practice", detail: "Work through each step", symbol: "pencil.and.outline", tint: LemmaColors.toolChat) { showPractice = true }
                        .disabled(generating)
                }
                Text("\(sets.reduce(0) { $0 + $1.cards.count }) saved cards · \(activity.count) practice attempts")
                    .font(LemmaTypography.caption(zoom)).foregroundStyle(.secondary)
                if let latest = ([activity.last?.date] + sets.map(\.lastReviewed)).compactMap({ $0 }).max() {
                    Text("Last activity \(latest.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                }
                if generating { HStack { ProgressView("Creating topic material…"); Button("Cancel") { task?.cancel(); generating = false } } }
                if let error = error ?? store.errorMessage { Text(error).foregroundStyle(.red) }
                resourceSection
                if !sets.isEmpty {
                    Text("Flashcard sets").font(LemmaTypography.sectionTitle(zoom))
                    ForEach(sets) { set in
                        HStack(spacing: 12) {
                            ReviewIcon(symbol: "square.stack.3d.up", tint: LemmaColors.toolFlashcards)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(set.title).font(LemmaTypography.ui(zoom).weight(.semibold))
                                Text("\(set.cards.count) cards · \(set.reviewCount) reviews").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Button("Review cards") { cardSet = set }.tint(LemmaColors.toolFlashcards)
                        }.padding(16).reviewSurface(tint: LemmaColors.toolFlashcards)
                    }
                }
                Text("Topic problems").font(LemmaTypography.sectionTitle(zoom))
                if linkedProblems.isEmpty { Text("Create a few problems to put this topic into practice.").foregroundStyle(.secondary) }
                ForEach(linkedProblems) { problem in
                    HStack {
                        TutorMathText(source: problem.prompt, fontSize: 15 * zoom).frame(maxWidth: .infinity, alignment: .leading)
                        Button("New attempt") { onPractice(problem) }
                    }.padding(16).reviewSurface(tint: LemmaColors.toolQuiz)
                }
            }.buttonStyle(LemmaButtonStyle()).font(LemmaTypography.ui(zoom)).foregroundStyle(LemmaColors.textPrimary).padding(LemmaSpacing.page * zoom).frame(maxWidth: 1100).frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $sourcePicker) {
            ReviewSourcePicker(sources: sources.sources, selected: Set(selectedIDs), primary: "", needsPrimary: false) { ids, _ in store.setResources(topic.id, sourceIDs: ids) }
        }
        .sheet(item: $preview) { ResourcePreviewView(sources: sources, target: $0) }
        .sheet(item: $cardSet) { ReviewCardSession(set: $0, store: store) }
        .sheet(item: $drafts) { draft in
            ReviewMaterialEditor(draft: draft, topicTitle: topic.title) { title, cards, questions in
                if !cards.isEmpty { return store.saveCards(ReviewCardSet(title: title, topicID: topic.id, cards: cards)) }
                var first: CourseProblem?
                for question in questions {
                    let item = problems.items.first { $0.prompt == question.prompt && $0.topicID == topic.id }
                        ?? problems.add(question.prompt, sources: question.sources)
                    if let item { problems.linkTopic(item.id, topicID: topic.id); if first == nil { first = item } }
                }
                if draft.kind == .practice, let first { onPractice(first) }
                return first != nil
            }
        }
        .sheet(isPresented: $showPractice) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Practice \(topic.title)").font(.title2.bold())
                Text("Start a fresh guided attempt. Previous attempts remain in Study and Problems.").foregroundStyle(.secondary)
                ScrollView {
                    ForEach(linkedProblems) { problem in
                        Button { showPractice = false; onPractice(problem) } label: {
                            Text(problem.prompt).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        }.buttonStyle(LemmaButtonStyle())
                    }
                }
                HStack {
                    Button("Cancel") { showPractice = false }; Spacer()
                    Button("Generate one problem") { showPractice = false; generate(.practice) }.disabled(selectedIDs.isEmpty).buttonStyle(LemmaButtonStyle(kind: .primary))
                }
                if selectedIDs.isEmpty { Text("Choose topic resources before generating a problem.").font(.caption).foregroundStyle(.secondary) }
            }.buttonStyle(LemmaButtonStyle()).padding(24).frame(width: 570, height: 400)
        }
        .onAppear { store.visit(topic.id) }
        .onDisappear { task?.cancel() }
    }
    private var resourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Source material").font(LemmaTypography.ui(zoom).weight(.semibold)); Spacer(); Button("Choose materials") { sourcePicker = true }; Button("Course materials", action: onResources) }
            if selectedIDs.isEmpty { Text("Choose course resources to generate grounded cards and problems.").foregroundStyle(.secondary) }
            ForEach(sources.sources.filter { selectedIDs.contains($0.id) }) { source in
                Button { preview = ResourcePreviewTarget(sourceID: source.id, title: source.filename) } label: { Label(source.filename, systemImage: "doc.text") }
            }
            ForEach(Array(topic.sources.enumerated()), id: \.offset) { _, ref in
                Button("\(ref.title) · \(ref.section)") { preview = ResourcePreviewTarget(reference: ref) }.font(.caption)
            }
        }.padding(18).reviewSurface(tint: LemmaColors.toolSummary)
    }
    private func generate(_ kind: StudyMaterialDraft.Kind) {
        generating = true; error = nil
        let ids = selectedIDs, focus = String((topic.title + ": " + topic.description).prefix(2000)), courseID = sources.courseID
        let client = AppDependencies.makeCourseStudyClient()
        task?.cancel()
        task = Task {
            do {
                var draft = StudyMaterialDraft(kind: kind)
                if kind == .cards { draft.cards = try await client.generateTopicFlashcards(courseID: courseID, sourceIDs: ids, topic: focus, count: 5) }
                else { draft.problems = try await client.generateTopicProblems(courseID: courseID, sourceIDs: ids, topic: focus, count: kind == .practice ? 1 : 3) }
                guard !Task.isCancelled else { return }
                drafts = draft
            } catch { guard !Task.isCancelled else { return }; self.error = reviewError(error) }
            generating = false
        }
    }
}

struct StudyMaterialDraft: Identifiable {
    enum Kind { case cards, problems, practice }
    let id = UUID()
    let kind: Kind
    var cards: [GeneratedTextbookFlashcard] = []
    var problems: [GeneratedCourseProblem] = []
}

struct ReviewMaterialEditor: View {
    struct Row: Identifiable {
        let id = UUID()
        var front: String
        var back: String
        let sources: [TutorSource]
        var selected = true
    }
    let draft: StudyMaterialDraft
    let onSave: (String, [GeneratedTextbookFlashcard], [GeneratedCourseProblem]) -> Bool
    @State private var title: String
    @State private var rows: [Row]
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    init(draft: StudyMaterialDraft, topicTitle: String, onSave: @escaping (String, [GeneratedTextbookFlashcard], [GeneratedCourseProblem]) -> Bool) {
        self.draft = draft; self.onSave = onSave
        _title = State(initialValue: topicTitle + (draft.kind == .cards ? " flashcards" : " problems"))
        _rows = State(initialValue: draft.kind == .cards ? draft.cards.map { Row(front: $0.front, back: $0.back, sources: $0.sources) } : draft.problems.map { Row(front: $0.prompt, back: "", sources: $0.sources) })
    }
    private var selected: [Row] { rows.filter { $0.selected } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Review generated material").font(.title2.bold()); Spacer(); Button("Cancel") { dismiss() } }
            if draft.kind == .cards { TextField("Set name", text: $title).lemmaInput() }
            Text("Edit and select what to keep. Nothing is saved until you approve it.").foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 14) {
                    ForEach($rows) { $row in
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Keep", isOn: $row.selected)
                            TextField(draft.kind == .cards ? "Question" : "Problem", text: $row.front, axis: .vertical).lineLimit(2...5).lemmaInput()
                            if draft.kind == .cards { TextField("Answer", text: $row.back, axis: .vertical).lineLimit(2...5).lemmaInput() }
                            Text(row.sources.map { "\($0.title) · \($0.section)" }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                        }.padding(14).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(draft.kind == .practice ? "Save and start practice" : "Save selected") {
                    let cards = draft.kind == .cards ? selected.map { GeneratedTextbookFlashcard(front: $0.front, back: $0.back, sources: $0.sources) } : []
                    let questions = draft.kind == .cards ? [] : selected.map { GeneratedCourseProblem(prompt: $0.front, sources: $0.sources) }
                    if onSave(title, cards, questions) { dismiss() } else { error = "The selected material could not be saved. Your draft is still here." }
                }.buttonStyle(LemmaButtonStyle(kind: .primary)).disabled(selected.isEmpty || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected.contains { $0.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (draft.kind == .cards && $0.back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) })
            }
        }.buttonStyle(LemmaButtonStyle()).padding(24).frame(width: 650, height: 510)
    }
}

struct ReviewCardSession: View {
    let set: ReviewCardSet
    let store: CourseReviewStore
    @State private var session = TextbookFlashcardStore()
    @State private var recorded = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Text(set.title).font(.title2.bold()); Spacer(); Button("Close") { dismiss() } }
            if session.isComplete {
                Text("Review complete").font(.title.bold())
                Text("\(session.knownCount) of \(session.cards.count) cards marked known. Topic status stays under your control.").foregroundStyle(.secondary)
                if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
                Button("Review again") { recorded = false; session.restart() }
            } else if session.cards.indices.contains(session.currentIndex) {
                let card = session.cards[session.currentIndex]
                Text("Card \(session.currentIndex + 1) of \(session.cards.count)").foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        TutorMathText(source: card.front, fontSize: 20, color: .white)
                        if session.isRevealed { Divider(); TutorMathText(source: card.back, fontSize: 18, color: .white) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(22)
                .background(LinearGradient(colors: session.isRevealed
                    ? [LemmaColors.flashcardBackTop, LemmaColors.flashcardBackBottom]
                    : [LemmaColors.flashcardFrontTop, LemmaColors.flashcardFrontBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
                Text(card.sources.map { "\($0.title) · \($0.section)" }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                HStack {
                    if session.isRevealed {
                        Button("Again") { grade(.again) }; Button("Known") { grade(.known) }.buttonStyle(LemmaButtonStyle(kind: .primary))
                    } else { Button("Reveal answer") { session.reveal() }.buttonStyle(LemmaButtonStyle(kind: .primary)) }
                }
            }
            Spacer(minLength: 0)
        }.buttonStyle(LemmaButtonStyle()).padding(28).frame(width: 650, height: 470).onAppear { session.load(set.cards) }
    }
    private func grade(_ grade: FlashcardGrade) {
        session.mark(grade)
        if session.isComplete && !recorded {
            store.recordCardReview(set.id, known: session.knownCount, total: session.cards.count); recorded = true
        }
    }
}
