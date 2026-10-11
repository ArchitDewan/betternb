import SwiftUI

struct ReviewRoadmapEditor: View {
    @State var units: [ReviewUnit]
    let replacing: Bool
    let onSave: ([ReviewUnit]) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var confirmSave = false
    @State private var removal: Removal?
    @State private var error: String?
    private struct Removal: Identifiable { let id = UUID(); let unit: UUID; let topic: UUID? }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Edit roadmap").font(.title2.bold())
                    Text("Arrange units and topics in the order you want to learn.").foregroundStyle(.secondary)
                }
                Spacer(); Button("Cancel") { dismiss() }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach($units) { $unit in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                TextField("Unit title", text: $unit.title).font(.headline).lemmaInput()
                                Button { moveUnit(unit.id, offset: -1) } label: { Image(systemName: "arrow.up") }.help("Move unit up")
                                Button { moveUnit(unit.id, offset: 1) } label: { Image(systemName: "arrow.down") }.help("Move unit down")
                                Button(role: .destructive) { removal = Removal(unit: unit.id, topic: nil) } label: { Image(systemName: "trash") }.help("Remove unit")
                            }
                            ForEach($unit.topics) { $topic in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        TextField("Topic title", text: $topic.title).lemmaInput()
                                        Button { moveTopic(topic.id, in: unit.id, offset: -1) } label: { Image(systemName: "arrow.up") }.help("Move topic up")
                                        Button { moveTopic(topic.id, in: unit.id, offset: 1) } label: { Image(systemName: "arrow.down") }.help("Move topic down")
                                        Menu {
                                            ForEach(units.filter { $0.id != unit.id }) { destination in
                                                Button(destination.title) { transfer(topic.id, from: unit.id, to: destination.id) }
                                            }
                                        } label: { Image(systemName: "folder") }.lemmaMenu().help("Move topic to another unit")
                                        Button(role: .destructive) { removal = Removal(unit: unit.id, topic: topic.id) } label: { Image(systemName: "trash") }.help("Remove topic")
                                    }
                                    TextField("What will you learn?", text: $topic.description, axis: .vertical).lineLimit(2...4).foregroundStyle(.secondary).lemmaInput()
                                }.padding(12).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                            }
                            Button("Add topic") { unit.topics.append(ReviewTopic(title: "New topic", description: "")) }
                        }.padding(14).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Add unit") { units.append(ReviewUnit(title: "New unit", topics: [ReviewTopic(title: "New topic", description: "")])) }
                Spacer()
                Button("Save roadmap") { if replacing { confirmSave = true } else { save() } }
                    .buttonStyle(LemmaButtonStyle(kind: .primary)).disabled(!CourseReviewStore.valid(units))
            }
        }.buttonStyle(LemmaButtonStyle()).padding(22).frame(width: 690, height: 540).background(LemmaColors.surface)
        .alert("Save roadmap changes?", isPresented: $confirmSave) {
            Button("Cancel", role: .cancel) { }
            Button("Save") { save() }
        } message: { Text("Removed topics will be detached from saved cards and problems. Your study material and practice history will be kept.") }
        .alert("Remove from roadmap?", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } })) {
            Button("Cancel", role: .cancel) { removal = nil }
            Button("Remove", role: .destructive) {
                if let item = removal {
                    if let topic = item.topic, let i = units.firstIndex(where: { $0.id == item.unit }) { units[i].topics.removeAll { $0.id == topic } }
                    else { units.removeAll { $0.id == item.unit } }
                }
                removal = nil
            }
        } message: { Text("This changes the draft only. Existing study material is kept when you save.") }
    }
    private func save() {
        if onSave(units) { dismiss() } else { error = "The roadmap could not be saved. Check the titles and local storage, then try again." }
    }
    private func moveUnit(_ id: UUID, offset: Int) {
        guard let i = units.firstIndex(where: { $0.id == id }), units.indices.contains(i + offset) else { return }
        units.swapAt(i, i + offset)
    }
    private func moveTopic(_ id: UUID, in unitID: UUID, offset: Int) {
        guard let i = units.firstIndex(where: { $0.id == unitID }), let j = units[i].topics.firstIndex(where: { $0.id == id }), units[i].topics.indices.contains(j + offset) else { return }
        units[i].topics.swapAt(j, j + offset)
    }
    private func transfer(_ id: UUID, from: UUID, to: UUID) {
        guard let i = units.firstIndex(where: { $0.id == from }), let j = units.firstIndex(where: { $0.id == to }), let topic = units[i].topics.first(where: { $0.id == id }) else { return }
        units[i].topics.removeAll { $0.id == id }; units[j].topics.append(topic)
    }
}

struct ReviewSourcePicker: View {
    let sources: [CourseSourceRecord]
    @State var selected: Set<String>
    @State var primary: String
    let needsPrimary: Bool
    let onChoose: ([String], String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.workspaceZoom) private var zoom
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                ReviewIcon(symbol: "map", tint: LemmaColors.toolSummary)
                VStack(alignment: .leading, spacing: 5) {
                    Text(needsPrimary ? "Build your roadmap" : "Topic material").font(LemmaTypography.sectionTitle(zoom))
                    Text(needsPrimary ? "Choose up to four files. Your primary file sets the order." : "Choose up to four files to study from.")
                        .font(LemmaTypography.caption(zoom)).foregroundStyle(LemmaColors.textSecondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(LemmaButtonStyle(kind: .quiet)).accessibilityLabel("Close source selection")
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(sources) { source in
                        HStack(spacing: 10) {
                            Button { toggle(source.id) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selected.contains(source.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 19)).foregroundStyle(selected.contains(source.id) ? LemmaColors.toolSummary : LemmaColors.textTertiary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(source.filename).font(LemmaTypography.ui(zoom).weight(.medium)).lineLimit(2)
                                        Text("\(source.pageCount) pages" + (source.unreadablePages.isEmpty ? "" : " · Some pages unreadable"))
                                            .font(LemmaTypography.caption(zoom)).foregroundStyle(LemmaColors.textTertiary)
                                    }
                                    Spacer(minLength: 0)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(!selected.contains(source.id) && selected.count >= 4)
                                .accessibilityLabel((selected.contains(source.id) ? "Deselect " : "Select ") + source.filename)
                            if needsPrimary && selected.contains(source.id) {
                                Button { primary = source.id } label: {
                                    Label(primary == source.id ? "Primary" : "Make primary", systemImage: primary == source.id ? "star.fill" : "star")
                                        .font(LemmaTypography.caption(zoom)).foregroundStyle(primary == source.id ? LemmaColors.toolQuiz : LemmaColors.textTertiary)
                                }.buttonStyle(LemmaButtonStyle(kind: .quiet)).fixedSize()
                            }
                        }.padding(12).reviewSurface(tint: selected.contains(source.id) ? LemmaColors.toolSummary : LemmaColors.textTertiary)
                    }
                    if sources.isEmpty { Text("Add a course outline, textbook, or notes in Course materials first.").foregroundStyle(LemmaColors.textSecondary).padding(20) }
                }
            }.frame(height: min(300, max(76, CGFloat(sources.count) * 78)))
            HStack {
                Text("\(selected.count) selected").font(LemmaTypography.caption(zoom)).foregroundStyle(LemmaColors.textTertiary)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(LemmaButtonStyle(kind: .quiet))
                Button(needsPrimary ? "Generate roadmap" : "Use selected") {
                    onChoose(selected.sorted(), primary); dismiss()
                }.buttonStyle(LemmaButtonStyle(kind: .primary))
                    .disabled(selected.isEmpty || selected.count > 4 || (needsPrimary && !selected.contains(primary)))
            }
        }.padding(24).frame(width: 620).background(LemmaColors.surface)
    }
    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        if !selected.contains(primary) { primary = sources.first(where: { selected.contains($0.id) })?.id ?? "" }
    }
}
