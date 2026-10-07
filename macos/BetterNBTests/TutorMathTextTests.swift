import Testing
@testable import BetterNB

struct TutorMathTextTests {
    @Test
    func mixedTutorSentenceKeepsReadableSpacesAtEveryRendererSeam() {
        let tokens = TutorMathLayoutPlan.flowTokens([
            .prose("You're differentiating "),
            .inline(#"f(x) = (x^2 + 1)^3 \sin 2x"#),
            .prose(". It's a product of two functions, so start with the product rule."),
            .prose("If "),
            .inline(#"u = (x^2 + 1)^3"#),
            .prose(" and "),
            .inline(#"v = \sin 2x"#),
            .prose(", what comes next?"),
        ])
        let signature = signature(tokens)

        #expect(signature.contains("You're differentiating §. It's a product"))
        #expect(signature.contains("product rule. If § and §, what comes next?"))
        #expect(!signature.contains("rule.If"))
        #expect(!signature.contains("§ ,"))
    }

    @Test
    func proseRepairsMissingSpacesAfterSentencePunctuation() {
        let items: [MathRenderItem] = [
            .prose("This is a product of two functions.Let u and v be the factors."),
            .inline(#"f'(x)=u'v+uv'"#),
            .prose(".Both factors need the chain rule."),
        ]
        let tokens = TutorMathLayoutPlan.flowTokens(items)
        let signature = signature(tokens)
        let accessibleText = TutorMathLayoutPlan.accessibleText(for: items)

        #expect(signature.contains("functions. Let u"))
        #expect(signature.contains("§. Both factors"))
        #expect(!signature.contains("functions.Let"))
        #expect(!signature.contains(".Both"))
        #expect(accessibleText.contains("functions. Let u"))
        #expect(accessibleText.contains("uv'. Both factors"))
    }

    @Test
    func shortProblemUsesOneInlineLeftAlignedFlow() {
        let markup = MathMarkup.parse(#"Differentiate f(x) = (x^2 + 1)^3 \sin 2x"#)
        let sections = TutorMathLayoutPlan.sections(for: markup.renderPlan)

        #expect(sections.count == 1)
        guard case .flow(let tokens) = sections.first else {
            Issue.record("The problem must remain an inline flow")
            return
        }
        #expect(signature(tokens) == "Differentiate §")
    }

    @Test
    func generatedAssignmentPromptRendersDelimitedMathInsteadOfRawLatexMarkers() {
        let prompt = #"Find all fourth roots of \(-8+8\sqrt{3}\,i\). Express each root using an argument in \([0,2\pi)\)."#
        let sections = TutorMathLayoutPlan.sections(for: MathMarkup.parse(prompt).renderPlan)
        let accessibleText = TutorMathLayoutPlan.accessibleText(for: MathMarkup.parse(prompt).renderPlan)

        guard case .flow(let tokens) = sections.first else {
            Issue.record("The draft should render as an inline math flow")
            return
        }
        #expect(tokens.filter(\.isMath).count == 2)
        #expect(!accessibleText.contains(#"\("#))
        #expect(!accessibleText.contains(#"\)"#))
    }

    @Test
    func commaSeparatedComposerPreviewUsesOneFormulaRow() {
        let markup = MathMarkup.livePreview(for: #"u = (x^2 + 1)^3, v = \sin 2x"#)
        let sections = TutorMathLayoutPlan.sections(for: markup?.renderPlan ?? [])

        #expect(sections.count == 1)
        guard case .flow(let tokens) = sections.first else {
            Issue.record("The composer preview must remain one inline flow")
            return
        }
        #expect(tokens.filter(\.isMath).count == 1)
    }

    @Test
    func explicitAlignEnvironmentRemainsAStandaloneDisplayBlock() {
        let sections = TutorMathLayoutPlan.sections(for: [
            .display(#"\begin{align} f'(x) &= 2x \\ &= 2x \end{align}"#),
        ])

        #expect(sections.count == 1)
        guard case .display = sections.first else {
            Issue.record("An explicit align environment must remain a display block")
            return
        }
    }

    private func signature(_ tokens: [TutorMathFlowToken]) -> String {
        tokens.map { token in
            switch token {
            case .word(let text): text
            case .space: " "
            case .math: "§"
            }
        }.joined()
    }
}

private extension TutorMathFlowToken {
    var isMath: Bool {
        if case .math = self { return true }
        return false
    }
}
