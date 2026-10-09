import SwiftUI

struct TextbookQuizView: View {
    @Bindable var quiz: TextbookQuizStore
    @Bindable var sources: CourseSourceStore
    let selectedSource: CourseSourceRecord?
    let onManageSources: () -> Void
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24 * zoom) {
                heading
                if let generated = quiz.quiz {
                    questions(generated)
                } else {
                    setup
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
            Image(systemName: "questionmark.circle")
                .font(.system(size: 23 * zoom))
                .foregroundStyle(LemmaColors.toolQuiz)
                .frame(width: 48 * zoom, height: 48 * zoom)
                .background(LemmaColors.toolQuiz.opacity(0.13),
                            in: RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
            VStack(alignment: .leading, spacing: 5 * zoom) {
                Text("Quiz")
                    .font(LemmaTypography.pageTitle(zoom))
                    .foregroundStyle(LemmaColors.textPrimary)
                Text("Check what you understand from your course material.")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }
            Spacer(minLength: 0)
            if quiz.quiz != nil {
                Button("New quiz") { quiz.reset() }
                    .buttonStyle(.plain)
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.accent)
            }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 26 * zoom) {
            VStack(alignment: .leading, spacing: 7 * zoom) {
                Text("Make a quiz")
                    .font(LemmaTypography.sectionTitle(zoom))
                    .foregroundStyle(LemmaColors.textPrimary)
                Text("Choose how you want to practice. Lemma will build questions from your material.")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
            }

            sourceStatus

            VStack(alignment: .leading, spacing: 12 * zoom) {
                setupLabel("Difficulty", detail: "How deeply should questions test you?")
                HStack(spacing: 8 * zoom) {
                    ForEach(QuizDifficulty.allCases) { difficulty in
                        difficultyChoice(difficulty)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12 * zoom) {
                setupLabel("Length", detail: "Pick a quick check or a longer session.")
                HStack(spacing: 8 * zoom) {
                    ForEach([3, 5, 10], id: \.self) { count in
                        lengthChoice(count)
                    }
                }
            }

            Toggle(isOn: $quiz.revealAfterSelection) {
                VStack(alignment: .leading, spacing: 4 * zoom) {
                    Text("Reveal answers as I go")
                        .font(LemmaTypography.ui(zoom).weight(.medium))
                        .foregroundStyle(LemmaColors.textPrimary)
                    Text(quiz.revealAfterSelection
                         ? "See the answer and explanation after each choice."
                         : "See all answers after finishing; change choices until then.")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                }
            }
            .toggleStyle(.switch)
            .tint(LemmaColors.toolQuiz)
            .disabled(sources.isGeneratingQuiz)

            if let error = sources.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.error)
            }

            Button {
                Task {
                    if let generated = await sources.generateQuiz(
                        sourceID: selectedSource?.id, count: quiz.questionCount,
                        difficulty: quiz.difficulty
                    ) {
                        quiz.load(generated)
                    }
                }
            } label: {
                HStack(spacing: 8 * zoom) {
                    if sources.isGeneratingQuiz {
                        ProgressView().controlSize(.small)
                        Text("Creating quiz…")
                    } else {
                        Text("Create quiz")
                        Image(systemName: "arrow.right")
                    }
                }
                .font(LemmaTypography.ui(zoom).weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 36 * zoom)
            }
            .buttonStyle(.borderedProminent)
            .tint(LemmaColors.toolQuiz)
            .disabled(sources.sources.isEmpty || sources.isGeneratingQuiz)
            .accessibilityHint("Generates a quiz using your course sources")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sourceStatus: some View {
        HStack(spacing: 10 * zoom) {
            Image(systemName: sources.sources.isEmpty ? "doc.badge.plus" : "doc.text")
                .font(.system(size: 16 * zoom))
                .foregroundStyle(LemmaColors.toolQuiz)
                .frame(width: 28 * zoom)
            VStack(alignment: .leading, spacing: 3 * zoom) {
                Text(sources.sources.isEmpty ? "No PDF added yet" : "Questions from")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
                Text(sources.sources.isEmpty
                     ? "Add a readable source to create a quiz"
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
    }

    private func setupLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3 * zoom) {
            Text(title)
                .font(LemmaTypography.ui(zoom).weight(.semibold))
                .foregroundStyle(LemmaColors.textPrimary)
            Text(detail)
                .font(LemmaTypography.caption(zoom))
                .foregroundStyle(LemmaColors.textSecondary)
        }
    }

    private func difficultyChoice(_ difficulty: QuizDifficulty) -> some View {
        let isSelected = quiz.difficulty == difficulty
        let subtitle: String = switch difficulty {
        case .easy: "Core ideas"
        case .standard: "Apply ideas"
        case .challenging: "Go deeper"
        }
        return Button {
            quiz.difficulty = difficulty
        } label: {
            VStack(alignment: .leading, spacing: 7 * zoom) {
                Text(difficulty.title)
                    .font(LemmaTypography.ui(zoom).weight(.semibold))
                    .foregroundStyle(isSelected ? LemmaColors.toolQuiz : LemmaColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 49 * zoom, alignment: .leading)
            .padding(12 * zoom)
            .background(isSelected ? LemmaColors.toolQuiz.opacity(0.12) : LemmaColors.hoverWash,
                        in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
            .overlay(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom)
                .stroke(isSelected ? LemmaColors.toolQuiz.opacity(0.6) : LemmaColors.hairline,
                        lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
        }
        .buttonStyle(.plain)
        .disabled(sources.isGeneratingQuiz)
        .accessibilityLabel("\(difficulty.title) difficulty, \(subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func lengthChoice(_ count: Int) -> some View {
        let isSelected = quiz.questionCount == count
        return Button {
            quiz.questionCount = count
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 5 * zoom) {
                Text("\(count)")
                    .font(LemmaTypography.sectionTitle(zoom))
                    .foregroundStyle(isSelected ? LemmaColors.toolQuiz : LemmaColors.textPrimary)
                Text("questions")
                    .font(LemmaTypography.caption(zoom))
                    .foregroundStyle(LemmaColors.textSecondary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 29 * zoom)
            .padding(10 * zoom)
            .background(isSelected ? LemmaColors.toolQuiz.opacity(0.12) : LemmaColors.hoverWash,
                        in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
            .overlay(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom)
                .stroke(isSelected ? LemmaColors.toolQuiz.opacity(0.6) : LemmaColors.hairline,
                        lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
        }
        .buttonStyle(.plain)
        .disabled(sources.isGeneratingQuiz)
        .accessibilityLabel("\(count) questions")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func questions(_ generated: GeneratedTextbookQuiz) -> some View {
        VStack(alignment: .leading, spacing: 22 * zoom) {
            HStack(spacing: 10 * zoom) {
                Text("\(generated.questions.count) questions")
                    .font(LemmaTypography.caption(zoom).weight(.semibold))
                Text("·")
                Text(quiz.difficulty.title)
                Spacer(minLength: 0)
                Text("\(quiz.selectedAnswers.count) answered")
            }
            .foregroundStyle(LemmaColors.textSecondary)
            .font(LemmaTypography.caption(zoom))

            ForEach(Array(generated.questions.enumerated()), id: \.offset) { index, question in
                questionView(question, index: index)
            }

            if quiz.isFinished {
                VStack(alignment: .leading, spacing: 8 * zoom) {
                    Text("Quiz complete")
                        .font(LemmaTypography.sectionTitle(zoom))
                    Text("\(quiz.score) of \(generated.questions.count) correct")
                        .font(LemmaTypography.body(zoom))
                    Text("Answers are generated from your course sources; check important results against the text.")
                        .font(LemmaTypography.caption(zoom))
                        .foregroundStyle(LemmaColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18 * zoom)
                .background(LemmaColors.toolQuiz.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: LemmaRadius.card * zoom))
            } else {
                Button("Finish quiz") { quiz.finish() }
                    .buttonStyle(.borderedProminent)
                    .tint(LemmaColors.toolQuiz)
                    .disabled(!quiz.canFinish)
                    .help(quiz.canFinish ? "Show your score" : "Answer every question to finish")
            }
        }
    }

    private func questionView(_ question: TextbookQuizQuestion, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14 * zoom) {
            Text("QUESTION \(index + 1)")
                .font(.system(size: 11 * zoom, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(LemmaColors.toolQuiz)
            TutorMathText(source: question.prompt, fontSize: 16 * zoom)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8 * zoom) {
                ForEach(question.options.indices, id: \.self) { optionIndex in
                    optionButton(question.options[optionIndex], question: question,
                                 questionIndex: index, optionIndex: optionIndex)
                }
            }

            if quiz.isRevealed(index) {
                VStack(alignment: .leading, spacing: 6 * zoom) {
                    Text(quiz.selectedAnswers[index] == question.correctIndex
                         ? "Correct" : "Answer: \(question.options[question.correctIndex])")
                        .font(LemmaTypography.ui(zoom).weight(.semibold))
                        .foregroundStyle(quiz.selectedAnswers[index] == question.correctIndex
                                         ? LemmaColors.success : LemmaColors.toolQuiz)
                    TutorMathText(source: question.explanation, fontSize: 13 * zoom,
                                  color: LemmaColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 3 * zoom)
            }
        }
        .padding(.vertical, 18 * zoom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LemmaColors.divider).frame(height: 1)
        }
    }

    private func optionButton(
        _ option: String, question: TextbookQuizQuestion, questionIndex: Int, optionIndex: Int
    ) -> some View {
        let selected = quiz.selectedAnswers[questionIndex] == optionIndex
        let revealed = quiz.isRevealed(questionIndex)
        let isCorrect = optionIndex == question.correctIndex
        let tint: Color = revealed && isCorrect ? LemmaColors.success
            : revealed && selected ? LemmaColors.error : LemmaColors.accent

        return Button {
            quiz.select(question: questionIndex, option: optionIndex)
        } label: {
            HStack(alignment: .top, spacing: 10 * zoom) {
                Text(String(UnicodeScalar(65 + optionIndex)!))
                    .font(LemmaTypography.caption(zoom).weight(.semibold))
                    .foregroundStyle(selected || (revealed && isCorrect) ? tint : LemmaColors.textSecondary)
                    .frame(width: 21 * zoom)
                TutorMathText(source: option, fontSize: 14 * zoom)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if revealed && isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(LemmaColors.success)
                } else if revealed && selected {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(LemmaColors.error)
                }
            }
            .padding(11 * zoom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected || (revealed && isCorrect) ? tint.opacity(0.12) : LemmaColors.hoverWash,
                        in: RoundedRectangle(cornerRadius: LemmaRadius.control * zoom))
            .overlay(RoundedRectangle(cornerRadius: LemmaRadius.control * zoom)
                .stroke(selected || (revealed && isCorrect) ? tint.opacity(0.55) : LemmaColors.hairline,
                        lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(quiz.isFinished || (quiz.revealsImmediately && selectedAnswerExists(questionIndex)))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func selectedAnswerExists(_ index: Int) -> Bool {
        quiz.selectedAnswers[index] != nil
    }
}
