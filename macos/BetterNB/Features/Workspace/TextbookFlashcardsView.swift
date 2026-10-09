import SwiftUI

struct TextbookFlashcardsView: View {
    @Bindable var flashcards: TextbookFlashcardStore
    @Bindable var sources: CourseSourceStore
    let selectedSource: CourseSourceRecord?
    let onManageSources: () -> Void
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25 * zoom) {
                heading
                if flashcards.cards.isEmpty {
                    setup
                } else {
                    review
                }
            }
            .frame(maxWidth: 700 * zoom, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24 * zoom)
            .padding(.vertical, 28 * zoom)
        }
        .scrollIndicators(.automatic)
    }

    private var heading: some View {
        HStack(alignment: .top, spacing: 14 * zoom) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 23 * zoom))
                .foregroundStyle(LemmaColors.toolFlashcards)
                .frame(width: 48 * zoom, height: 48 * zoom)
                .background(LemmaColors.toolFlashcards.opacity(0.13),
                            in: RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
            VStack(alignment: .leading, spacing: 5 * zoom) {
                Text("Flashcards")
                    .font(LemmaTypography.pageTitle(zoom))
                    .foregroundStyle(LemmaColors.textPrimary)
                Text("Recall the ideas in your course material.")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }
            Spacer(minLength: 0)
            if !flashcards.cards.isEmpty {
                Button("New deck") { flashcards.reset() }
                    .buttonStyle(.plain)
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.accent)
            }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 24 * zoom) {
            VStack(alignment: .leading, spacing: 6 * zoom) {
                Text("Make a deck")
                    .font(LemmaTypography.sectionTitle(zoom))
                    .foregroundStyle(LemmaColors.textPrimary)
                Text("A few focused questions to help you remember what you read.")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }

            HStack(spacing: 10 * zoom) {
                Image(systemName: sources.sources.isEmpty ? "doc.badge.plus" : "doc.text")
                    .foregroundStyle(LemmaColors.toolFlashcards)
                    .frame(width: 25 * zoom)
                VStack(alignment: .leading, spacing: 3 * zoom) {
                    Text(sources.sources.isEmpty ? "No PDF added yet" : "Cards from")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                    Text(sources.sources.isEmpty ? "Add a readable source to begin"
                         : selectedSource?.filename ?? "All course sources")
                        .font(LemmaTypography.ui(zoom).weight(.medium))
                        .foregroundStyle(LemmaColors.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button(sources.sources.isEmpty ? "Add PDF" : "Sources", action: onManageSources)
                    .buttonStyle(.plain)
                    .font(LemmaTypography.caption(zoom).weight(.medium))
                    .foregroundStyle(LemmaColors.accent)
            }
            .padding(13 * zoom)
            .background(LemmaColors.hoverWash,
                        in: RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))

            VStack(alignment: .leading, spacing: 12 * zoom) {
                Text("Deck size")
                    .font(LemmaTypography.ui(zoom).weight(.semibold))
                    .foregroundStyle(LemmaColors.textPrimary)
                HStack(spacing: 8 * zoom) {
                    ForEach([5, 10, 15], id: \.self) { count in
                        sizeChoice(count)
                    }
                }
            }

            if let error = sources.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.error)
            }

            Button {
                Task {
                    if let cards = await sources.generateFlashcards(
                        sourceID: selectedSource?.id, count: flashcards.requestedCount
                    ) {
                        flashcards.load(cards)
                    }
                }
            } label: {
                HStack(spacing: 8 * zoom) {
                    if sources.isGeneratingFlashcards {
                        ProgressView().controlSize(.small)
                        Text("Making flashcards…")
                    } else {
                        Text("Create flashcards")
                        Image(systemName: "arrow.right")
                    }
                }
                .font(LemmaTypography.ui(zoom).weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 36 * zoom)
            }
            .buttonStyle(.borderedProminent)
            .tint(LemmaColors.toolFlashcards)
            .disabled(sources.sources.isEmpty || sources.isGeneratingFlashcards)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sizeChoice(_ count: Int) -> some View {
        let selected = flashcards.requestedCount == count
        return Button { flashcards.requestedCount = count } label: {
            HStack(alignment: .firstTextBaseline, spacing: 5 * zoom) {
                Text("\(count)")
                    .font(LemmaTypography.sectionTitle(zoom))
                    .foregroundStyle(selected ? LemmaColors.toolFlashcards : LemmaColors.textPrimary)
                Text("cards")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 29 * zoom)
            .padding(10 * zoom)
            .background(selected ? LemmaColors.toolFlashcards.opacity(0.12) : LemmaColors.hoverWash,
                        in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
            .overlay(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom)
                .stroke(selected ? LemmaColors.toolFlashcards.opacity(0.6) : LemmaColors.hairline,
                        lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
        }
        .buttonStyle(.plain)
        .disabled(sources.isGeneratingFlashcards)
        .accessibilityLabel("\(count) cards")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 18 * zoom) {
            if flashcards.isComplete {
                HStack(alignment: .center, spacing: 12 * zoom) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LemmaColors.success)
                    VStack(alignment: .leading, spacing: 3 * zoom) {
                        Text("Deck complete")
                            .font(LemmaTypography.ui(zoom).weight(.semibold))
                        Text("\(flashcards.knownCount) of \(flashcards.cards.count) marked Got it")
                            .font(LemmaTypography.caption(zoom))
                            .foregroundStyle(LemmaColors.textSecondary)
                    }
                    Spacer()
                    Button("Study again") { flashcards.restart() }
                        .buttonStyle(.plain)
                        .font(LemmaTypography.caption(zoom).weight(.medium))
                        .foregroundStyle(LemmaColors.accent)
                }
                .padding(14 * zoom)
                .background(LemmaColors.success.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
            }

            HStack {
                Text("CARD \(flashcards.currentIndex + 1) OF \(flashcards.cards.count)")
                    .font(.system(size: 11 * zoom, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(LemmaColors.toolFlashcards)
                Spacer()
                Text("\(flashcards.reviewedCount) reviewed")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }

            FlashcardFlipButton(
                card: flashcards.cards[flashcards.currentIndex],
                isRevealed: flashcards.isRevealed,
                zoom: zoom,
                onFlip: { flashcards.flip() }
            )
            .id(flashcards.currentIndex)

            HStack(spacing: 10 * zoom) {
                if flashcards.canGrade && !flashcards.isComplete {
                    reviewAction("Again", symbol: "arrow.counterclockwise", tint: LemmaColors.textSecondary) {
                        flashcards.mark(.again)
                    }
                    reviewAction("Got it", symbol: "checkmark", tint: LemmaColors.toolFlashcards) {
                        flashcards.mark(.known)
                    }
                } else {
                    Text(flashcards.isComplete ? "Select a card above to revisit it."
                         : "Click anywhere on the card to reveal the answer.")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 38 * zoom)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 5 * zoom) {
                    ForEach(flashcards.cards.indices, id: \.self) { index in
                        Button { flashcards.showCard(index) } label: {
                            Capsule()
                                .fill(index == flashcards.currentIndex
                                      ? LemmaColors.toolFlashcards
                                      : flashcards.grades[index] == .known
                                        ? LemmaColors.success.opacity(0.75)
                                        : flashcards.grades[index] == .again
                                          ? LemmaColors.warning.opacity(0.75)
                                          : LemmaColors.textTertiary.opacity(0.45))
                                .frame(width: index == flashcards.currentIndex ? 22 * zoom : 8 * zoom,
                                       height: 8 * zoom)
                                .frame(minWidth: 17 * zoom, minHeight: 24 * zoom)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Card \(index + 1)")
                        .accessibilityAddTraits(index == flashcards.currentIndex ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func reviewAction(
        _ title: String, symbol: String, tint: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(LemmaTypography.ui(zoom).weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 43 * zoom)
                .background(tint.opacity(0.13),
                            in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
                .contentShape(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
        }
        .buttonStyle(.plain)
    }
}

private struct FlashcardFlipButton: View {
    let card: GeneratedTextbookFlashcard
    let isRevealed: Bool
    let zoom: CGFloat
    let onFlip: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    var body: some View {
        Button(action: onFlip) {
            FlashcardFlipFace(card: card, angle: angle, zoom: zoom)
                .contentShape(RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? "Answer: \(card.back). Flip to question"
                            : "Question: \(card.front). Flip to answer")
        .onAppear { angle = isRevealed ? 180 : 0 }
        .onChange(of: isRevealed) { _, revealed in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.46)) {
                angle = revealed ? 180 : 0
            }
        }
    }
}

/// Switch faces at the edge-on point so neither side appears mirrored during the turn.
private struct FlashcardFlipFace: View, Animatable {
    let card: GeneratedTextbookFlashcard
    var angle: Double
    let zoom: CGFloat

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let showingBack = angle >= 90
        return face(isBack: showingBack)
            .rotation3DEffect(.degrees(showingBack ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.65)
    }

    private func face(isBack: Bool) -> some View {
        let colors = isBack
            ? [LemmaColors.flashcardBackTop, LemmaColors.flashcardBackBottom]
            : [LemmaColors.flashcardFrontTop, LemmaColors.flashcardFrontBottom]
        return VStack(alignment: .leading, spacing: 16 * zoom) {
            HStack(spacing: 8 * zoom) {
                Image(systemName: isBack ? "checkmark.seal" : "square.stack.3d.up")
                Text(isBack ? "ANSWER" : "QUESTION")
                    .tracking(1.5)
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14 * zoom))
                    .opacity(0.8)
            }
            .font(.system(size: 11 * zoom, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.78))

            Spacer(minLength: 8 * zoom)
            TutorMathText(source: isBack ? card.back : card.front,
                          fontSize: 19 * zoom, weight: .medium, color: .white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 8 * zoom)

            if let source = card.sources.first {
                Label("\(source.title) · \(source.section)", systemImage: "doc.text")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .padding(25 * zoom)
        .frame(maxWidth: .infinity, minHeight: 270 * zoom, alignment: .leading)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16 * zoom))
        .overlay(RoundedRectangle(cornerRadius: 16 * zoom)
            .stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: colors[0].opacity(0.18), radius: 14 * zoom, y: 7 * zoom)
    }
}
