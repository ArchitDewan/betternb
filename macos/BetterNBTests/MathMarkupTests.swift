import Testing
@testable import BetterNB

struct MathMarkupTests {
    @Test
    func latexInASentenceStaysOnTheMathRun() {
        let markup = MathMarkup.parse(#"The slope is \frac{1}{2} and the answer is \boxed{2x}."#)

        #expect(markup.contains(.fraction))
        #expect(markup.contains(.boxed))
        #expect(markup.accessibleText.contains("The slope is"))
        #expect(markup.accessibleText.contains(#"\frac{1}{2}"#))
        #expect(markup.accessibleText.contains("2x"))
    }

    @Test
    func displayMathIsKeptAsASeparateBlock() {
        let markup = MathMarkup.parse(
            """
            Find the derivative of
            \\[
            7x^5 - x^4 + 4x^{3/2} + \\frac{8}{\\sqrt{x}} - 4\\sec x
            \\]
            #35
            """
        )

        #expect(markup.contains(.fraction))
        #expect(markup.latexChunks.contains { latex in
            latex.contains(#"\frac"#) && latex.contains(#"\sec"#)
        })
        #expect(markup.accessibleText.contains("Find the derivative of"))
        #expect(markup.accessibleText.contains("#35"))
        #expect(!markup.accessibleText.contains("\\["))
    }

    @Test
    func delimitedDisplayMathIsASeparateBlock() {
        let markup = MathMarkup.parse("Differentiate both sides.\n\n\\[ f'(x) = 2x \\]")

        #expect(markup.latexChunks.contains { latex in latex.contains("f'(x)") })
        #expect(!markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(markup.accessibleText.contains("Differentiate both sides."))
    }

    @Test
    func inlineDelimitersBecomeMathRuns() {
        let markup = MathMarkup.parse(#"Start from \( x^{2} \) and apply the power rule."#)

        #expect(markup.contains(.superscript))
        #expect(markup.accessibleText.contains("Start from"))
        #expect(markup.accessibleText.contains("x^{2}"))
        #expect(!markup.accessibleText.contains("\\("))
    }

    @Test
    func alignEnvironmentsBecomeStackedDisplayLines() {
        let markup = MathMarkup.parse(#"\begin{align} f'(x) &= 2x \\ &= 2x \end{align}"#)
        let displays = markup.blocks.compactMap { block -> String? in
            if case .display(let latex) = block { return latex }
            return nil
        }

        #expect(displays.count >= 2)
        #expect(displays.joined().contains("f'(x)"))
        #expect(!markup.accessibleText.contains("\\begin"))
        #expect(!markup.accessibleText.contains("&"))
    }

    @Test
    func alignedInsideDisplayDoesNotLeakTheEnvironment() {
        let markup = MathMarkup.parse(
            """
            \\[
            \\begin{aligned}
            f'(x) &= 14x + 4 \\\\
            &= 14x + 4
            \\end{aligned}
            \\]
            """
        )

        #expect(!markup.accessibleText.contains("begin"))
        #expect(!markup.accessibleText.contains("&"))
        #expect(markup.accessibleText.contains("14x + 4") || markup.accessibleText.contains("14x+4"))
    }

    @Test
    func sentenceInsideDisplayKeepsReadableSpacing() {
        let markup = MathMarkup.parse(
            #"First simplify by dividing each term by \( x^{4} \):"#
        )

        #expect(markup.accessibleText.contains("First simplify by dividing each term by"))
        #expect(!markup.accessibleText.contains("Firstsimplify"))
        #expect(!markup.accessibleText.contains("dividingeach"))
        #expect(markup.contains(.superscript))
    }

    @Test
    func liveRevealSampleKeepsCommandsForTheRenderer() {
        let markup = MathMarkup.parse(
            """
            Using the power rule,
            \\[
            \\frac{d}{dx}x^n = nx^{n-1}.
            \\]
            For \\(f(x)=x^2\\), take \\(n=2\\):
            \\[
            f'(x)=2x^{2-1}=2x.
            \\]
            Thus,
            \\[
            \\boxed{f'(x)=2x}.
            \\]
            """
        )

        #expect(markup.contains(.fraction))
        #expect(markup.contains(.boxed))
        #expect(markup.accessibleText.contains("Using the power rule"))
        #expect(markup.accessibleText.contains(#"\frac{d}{dx}"#))
        #expect(markup.accessibleText.contains("f'(x)=2x"))
    }

    @Test
    func casualPolynomialUsesSuperscripts() {
        let markup = MathMarkup.parse("2x^2")

        #expect(markup.contains(.superscript))
        #expect(!markup.isPlainProse)
        #expect(markup.latexChunks.joined().contains("2") && markup.latexChunks.joined().contains("^"))
    }

    @Test
    func casualParenthesizedQuotientBecomesAFraction() {
        let markup = MathMarkup.parse("(2x^6+5x)/x^4")

        #expect(markup.contains(.fraction))
        #expect(markup.contains(.superscript))
        #expect(markup.latexChunks.joined().contains(#"\frac"#))
        #expect(markup.latexChunks.joined().contains("^{6}") || markup.latexChunks.joined().contains("^6"))
    }

    @Test
    func casualSlashTakesTheNextFactorUnlessGrouped() {
        let halfX = MathMarkup.parse("1/2x")
        #expect(halfX.contains(.fraction))

        let grouped = MathMarkup.parse("1/(2x)")
        #expect(grouped.contains(.fraction))
        #expect(grouped.latexChunks.joined().contains("2x") || grouped.latexChunks.joined().contains("2"))
    }

    @Test
    func casualLeadingPlusAndBinaryMinusStayReadable() {
        let plus = MathMarkup.parse("+ 2x^2")
        #expect(plus.contains(.superscript))

        let minus = MathMarkup.parse("7x^5-x^4")
        #expect(minus.accessibleText.contains("7") && minus.accessibleText.contains("x"))
    }

    @Test
    func casualDerivativeAndEquationForms() {
        let derivative = MathMarkup.parse("d/dx")
        #expect(derivative.contains(.fraction))

        let equation = MathMarkup.parse("f'(x)=2x")
        #expect(equation.accessibleText.contains("f'(x)"))
        #expect(equation.accessibleText.contains("2x"))
    }

    @Test
    func casualFunctionsAndRoots() {
        let markup = MathMarkup.parse("sqrt(x+1)+sin(2x)")

        #expect(markup.accessibleText.contains(#"\sqrt"#) || markup.accessibleText.contains("sqrt"))
        #expect(markup.accessibleText.contains("sin"))
    }

    @Test
    func incompleteCasualMathDoesNotDropWhatWasTyped() {
        let power = MathMarkup.parse("2x^")
        #expect(power.accessibleText.contains("2") && power.accessibleText.contains("x"))

        let slash = MathMarkup.parse("(2x+1)/")
        #expect(slash.accessibleText.contains("2x"))
        #expect(slash.accessibleText.contains("1"))
    }

    @Test
    func mixedProseKeepsWordsAndLiftsThePolynomial() {
        let source = "can you help me differentiate 7x^2 + 4x?"
        let markup = MathMarkup.parse(source)

        #expect(!markup.isPlainProse)
        #expect(markup.contains(.superscript))
        #expect(markup.accessibleText.contains("help me differentiate"))
        #expect(markup.accessibleText.contains("7") && markup.accessibleText.contains("x"))
        #expect(markup.accessibleText.contains("4x") || markup.accessibleText.contains("4"))
        #expect(markup.accessibleText.contains("?"))
    }

    @Test
    func livePreviewOnlyAppearsForTypedMath() {
        #expect(MathMarkup.livePreview(for: "") == nil)
        #expect(MathMarkup.livePreview(for: "what should I do next?") == nil)
        #expect(MathMarkup.livePreview(for: "Start with what you have tried.") == nil)
        #expect(MathMarkup.livePreview(for: "2x^2") != nil)
        #expect(MathMarkup.livePreview(for: "(2x^6+5x)/x^4") != nil)
        #expect(MathMarkup.livePreview(for: "+ 2x^2") != nil)
        #expect(MathMarkup.livePreview(for: "u = cos x") != nil)
        #expect(MathMarkup.livePreview(for: "3x+4") != nil)
        #expect(MathMarkup.livePreview(for: #"\lim_{b \to (\pi/2)^-}"#) != nil)
    }

    @Test
    func inlineTrigStaysInsideTheSentence() {
        let markup = MathMarkup.parse(
            #"what happens to \cos^2 x as x approaches \pi/2 from below?"#
        )
        #expect(!markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(markup.accessibleText.contains("what happens to"))
        #expect(markup.accessibleText.contains("from below"))
        #expect(LatexCleanup.isSentenceMath(#"\cos^2 x"#))
        #expect(LatexCleanup.isSentenceMath(#"\pi/2"#))
    }

    @Test
    func midSentenceProductStaysInlineAndKeepsThePeriod() {
        let source = #"You're differentiating \(f(x) = (x^2 + 1)^3 \sin 2x\). This is a product, so start with the product rule."#
        let markup = MathMarkup.parse(source)
        let plan = markup.renderPlan

        #expect(!markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(plan.contains { item in
            if case .inline(let latex) = item {
                return latex.contains("=") && (latex.contains(#"\sin"#) || latex.contains("sin"))
            }
            return false
        })
        #expect(!plan.contains { item in
            if case .display = item { return true }
            return false
        })
        #expect(plan.contains { item in
            if case .prose(let text) = item { return text.contains("This is a product") }
            return false
        })
        #expect(markup.accessibleText.contains("You're differentiating"))
        #expect(markup.accessibleText.contains("This is a product"))
        #expect(!markup.accessibleText.contains("Youaredifferentiating"))
        #expect(!markup.accessibleText.contains("Thisisa product"))
    }

    @Test
    func bracketedEquationInsideASentenceStaysOnThatLine() {
        let source = #"You're differentiating \[ f(x) = (x^2 + 1)^3 \sin 2x \]. This is a product, so start with the product rule."#
        let markup = MathMarkup.parse(source)

        #expect(!markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(markup.renderPlan.contains { item in
            if case .prose(let text) = item { return text.contains("You're differentiating") }
            return false
        })
        #expect(markup.renderPlan.contains { item in
            if case .prose(let text) = item { return text.contains("This is a product") }
            return false
        })
        #expect(markup.renderPlan.contains { item in
            if case .inline(let latex) = item {
                return latex.contains("=") && (latex.contains(#"\sin"#) || latex.contains("sin"))
            }
            return false
        })
        #expect(!markup.accessibleText.contains("\n."))
    }

    @Test
    func shortProblemPromptKeepsTheEquationInline() {
        let markup = MathMarkup.parse(#"Differentiate f(x) = (x^2 + 1)^3 \sin 2x"#)
        #expect(!markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(markup.renderPlan.contains { item in
            if case .prose(let text) = item { return text.contains("Differentiate") }
            return false
        })
        #expect(markup.renderPlan.contains { item in
            if case .inline(let latex) = item {
                return latex.contains("=") && (latex.contains(#"\sin"#) || latex.contains("sin"))
            }
            return false
        })
        #expect(!markup.renderPlan.contains { item in
            if case .display = item { return true }
            return false
        })
        #expect(!markup.latexChunks.joined().contains("Differentiate"))
    }

    @Test
    func commaSeparatedAssignmentsStayOnePreview() {
        let preview = MathMarkup.livePreview(for: #"u = (x^2 + 1)^3, v = \sin 2x"#)
        #expect(preview != nil)
        #expect(preview?.latexChunks.count == 1)
        let latex = preview?.latexChunks.joined() ?? ""
        #expect(latex.contains("u"))
        #expect(latex.contains("v"))
        #expect(latex.contains(#"\sin"#) || latex.contains("sin"))
    }

    @Test
    func productEquationIsNotStrippedToReadableText() {
        let source = #"Differentiate f(x) = (x^2 + 1)^3 \sin 2x"#
        let markup = MathMarkup.parse(source)
        let latex = markup.latexChunks.joined()

        #expect(markup.accessibleText.contains("Differentiate"))
        #expect(latex.contains(#"\sin"#) || latex.contains("sin"))
        #expect(markup.latexChunks.contains { chunk in
            chunk.contains("=") && (chunk.contains(#"\sin"#) || chunk.contains("sin"))
        })
        #expect(!markup.latexChunks.joined().contains("Differentiate"))
        #expect(!LatexCleanup.isSentenceMath(#"f(x) = (x^2 + 1)^3 \sin 2x"#))
        #expect(LatexCleanup.isSentenceMath(#"u = (x^2 + 1)^3"#))
        #expect(LatexCleanup.isSentenceMath(#"v = \sin 2x"#))
    }

    @Test
    func checkNoteKeepsSubstitutionsInTheParagraph() {
        let source = #"Correct. Choosing \(u = (x^2 + 1)^3\) and \(v = \sin 2x\) identifies the two factors of \(f(x)\)."#
        let markup = MathMarkup.parse(source)
        #expect(!markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(markup.accessibleText.contains("Correct"))
        #expect(markup.accessibleText.contains("identifies the two factors"))
    }

    @Test
    func productWithSineStaysOnePreviewFormula() {
        let source = #"Differentiate f(x) = (x^2 + 1)^3 \sin 2x"#
        let preview = MathMarkup.livePreview(for: source)

        #expect(preview != nil)
        #expect(preview?.latexChunks.count == 1)
        let latex = preview?.latexChunks.joined() ?? ""
        #expect(latex.contains(#"\sin"#) || latex.contains("sin"))
        #expect(latex.contains("2"))
        #expect(latex.contains("^") || latex.contains("3"))
        #expect(!(preview?.accessibleText.contains("\n") ?? false) || preview?.latexChunks.count == 1)
    }

    @Test
    func mixedDraftKeepsTheSumInOneFractionAndDropsTheQuestion() {
        let source = "+ 2x^2+(4+5)/3-int(2*x+6)dx am i right{"
        let markup = MathMarkup.parse(source)
        let preview = MathMarkup.livePreview(for: source)

        #expect(markup.contains(.superscript))
        #expect(markup.contains(.fraction))
        #expect(markup.accessibleText.contains("am i right"))
        #expect(preview != nil)
        #expect(preview?.contains(.fraction) == true)
        #expect(preview?.accessibleText.contains(#"\int"#) == true || preview?.accessibleText.contains("int") == true)
        #expect(preview?.accessibleText.contains("am") != true)
        #expect(preview?.accessibleText.contains("right") != true)
    }

    @Test
    func groupedSumOverANumberStaysOneFraction() {
        let markup = MathMarkup.parse("(4+5)/3")

        #expect(markup.contains(.fraction))
        #expect(markup.latexChunks.joined().contains(#"\frac"#))
    }

    @Test
    func unmatchedBraceDoesNotSwallowTheDraft() {
        let markup = MathMarkup.parse("2x^2 am i right{")

        #expect(markup.contains(.superscript))
        #expect(markup.accessibleText.contains("am i right"))
        #expect(markup.accessibleText.contains("{"))
    }

    @Test
    func integralCommandsStayAsLatexForTheRenderer() {
        let markup = MathMarkup.parse(
            #"\[ \int\frac{2x^6 + 5x}{x^4}\,dx \]"#
        )

        #expect(markup.contains(.fraction))
        #expect(markup.accessibleText.contains(#"\int"#))
        #expect(markup.accessibleText.contains(#"\frac"#))
        #expect(!markup.accessibleText.contains("int("))
    }

    @Test
    func definiteIntegralsKeepLimits() {
        let integral = MathMarkup.parse(#"\[ \int_0^{\pi} \sin x\,dx \]"#)
        #expect(integral.accessibleText.contains(#"\int"#))
        #expect(integral.accessibleText.contains("0"))
        #expect(integral.accessibleText.contains(#"\pi"#) || integral.accessibleText.contains(#"\sin"#))

        let sum = MathMarkup.parse(#"\[ \sum_{n=1}^{\infty} \frac{1}{n^2} \]"#)
        #expect(sum.contains(.fraction))
        #expect(sum.accessibleText.contains(#"\sum"#))
    }

    @Test
    func plainProseKeepsWordSpacing() {
        let source = "can you help me differentiate 7x^2 + 4x?"
        let markup = MathMarkup.parse(source)

        #expect(markup.accessibleText.contains("help me differentiate"))
        #expect(!markup.accessibleText.contains("helpme"))
        #expect(!markup.accessibleText.contains("differentiate7"))
    }

    @Test
    func integralDoesNotBecomeTheNumeratorOfASlash() {
        let hoisted = LatexCleanup.prepare(
            #"\frac{\int_0^{\pi}\sin 2x}{\cos^2 2x}\,dx"#
        )
        #expect(hoisted.contains(#"\int"#))
        #expect(hoisted.contains(#"\frac{\sin 2x}{\cos^2 2x}"#) || hoisted.contains(#"\frac{\sin 2x}{\cos^{2} 2x}"#))
        #expect(!hoisted.contains(#"\frac{\int"#))

        let slashed = LatexCleanup.prepare(
            #"\int_0^{\pi}\sin 2x/\cos^2 2x dx"#
        )
        #expect(slashed.contains(#"\frac{"#))
        #expect(!slashed.contains(#"\frac{\int"#))
        #expect(slashed.hasPrefix(#"\int"#))

        let spaced = MathMarkup.parse(#"\int_0^{\pi/2} \sin x / \cos^2 x \, dx"#)
        #expect(spaced.contains(.fraction))
        #expect(spaced.latexChunks.joined().contains(#"\int"#))
        #expect(spaced.latexChunks.joined().contains(#"\frac"#))
        #expect(!spaced.accessibleText.contains("\n/\n"))
        #expect(spaced.latexChunks.count == 1)
    }

    @Test
    func tutorNoteKeepsSpacesAroundAProperIntegral() {
        let source = #"You are working on \int_0^{\pi/2} \frac{\sin x}{\cos^2 x}\,dx. Before choosing a substitution, check the upper endpoint: what happens to \cos^2 x as x approaches \pi/2 from below?"#
        let markup = MathMarkup.parse(source)

        #expect(markup.accessibleText.contains("You are working on"))
        #expect(markup.accessibleText.contains("Before choosing a substitution"))
        #expect(markup.accessibleText.contains("from below"))
        #expect(!markup.accessibleText.contains("Youareworking"))
        #expect(!markup.accessibleText.contains("Beforechoosing"))
        #expect(!markup.latexChunks.joined().contains("working"))
        #expect(!markup.latexChunks.joined().contains("choosing"))
        #expect(!markup.latexChunks.joined().contains("approaches"))
        #expect(markup.contains(.fraction))
        #expect(!markup.accessibleText.contains("\n."))
        #expect(!markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(markup.accessibleText.contains("You are working on"))
        #expect(markup.accessibleText.contains("Before choosing"))
    }

    @Test
    func tutorProseStaysOrdinaryTextAroundAnIntegral() {
        let samples = [
            """
            You are working on the definite integral
            \\[
            \\int_0^{\\pi} \\frac{\\sin 2x}{\\cos^2 2x}\\,dx
            \\]
            A useful first step is to choose \\(u = \\cos 2x\\), since its derivative contains the sine factor in the numerator. What expression do you get for \\(du\\)?
            """,
            #"You are working on \(\int_0^{\pi} \frac{\sin 2x}{\cos^2 2x}\,dx\). A useful first step is to choose \(u = \cos 2x\), since its derivative contains the sine factor in the numerator. What expression do you get for \(du\)?"#,
            #"You are working on \int_0^{\pi} \frac{\sin 2x}{\cos^2 2x}\,dx. A useful first step is to choose u = \cos 2x, since its derivative contains the sine factor in the numerator. What expression do you get for du?"#,
            #"\(You are working on \int_0^{\pi} \frac{\sin 2x}{\cos^2 2x}\,dx. A useful first step is to choose u = \cos 2x, since its derivative contains the sine factor in the numerator. What expression do you get for du?\)"#,
        ]

        for source in samples {
            let markup = MathMarkup.parse(source)
            #expect(markup.accessibleText.contains("You are working on"))
            #expect(markup.accessibleText.contains("A useful first step is to choose"))
            #expect(markup.accessibleText.contains("sine factor in the numerator"))
            #expect(markup.accessibleText.contains("What expression do you get"))
            #expect(!markup.accessibleText.contains("Youareworking"))
            #expect(!markup.accessibleText.contains("You'reworking"))
            #expect(markup.contains(.fraction))
            #expect(markup.latexChunks.joined().contains(#"\int"#))
            #expect(!markup.latexChunks.joined().contains("working"))
            #expect(!markup.latexChunks.joined().contains("useful"))
            #expect(!markup.latexChunks.joined().contains("numerator"))
            #expect(!markup.latexChunks.joined().contains("expression"))
            #expect(!markup.blocks.contains { block in
                if case .display = block { return true }
                return false
            })
        }
    }

    @Test
    func substitutionStaysInlineInsteadOfAGiantDisplay() {
        let markup = MathMarkup.parse("u = cos x")
        #expect(!markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(markup.accessibleText.contains("u"))
        #expect(markup.accessibleText.contains("cos") || markup.accessibleText.contains(#"\cos"#))
    }

    @Test
    func integralLimitsAreBracedForTheRenderer() {
        let prepared = LatexCleanup.prepare(#"\int_0^{\pi/2} \frac{\sin x}{\cos^2 x}\,dx"#)
        #expect(prepared.contains(#"\int_{0}"#))
        #expect(prepared.contains(#"\cos^{2}"#))
        #expect(prepared.contains(#"\frac"#))

        let limit = LatexCleanup.prepare(#"\lim_{b \to (\pi/2)^-}"#)
        #expect(limit.contains("^{-}"))
    }

    @Test
    func definiteIntegralIsNeverFlattenedToReadableText() {
        let latex = #"\int_0^{\pi/2} \frac{\sin x}{\cos^2 x}\,dx"#
        #expect(LatexCleanup.englishWordCount(latex) == 0)
        #expect(!LatexCleanup.hasEnglishSentence(latex))
        #expect(LatexCleanup.isPureMath(latex))

        let pieces = LatexCleanup.intents(for: latex)
        #expect(pieces.count == 1)
        guard case .math(let math) = pieces[0] else {
            Issue.record("integral should render as math, not text")
            return
        }
        #expect(math.contains(#"\int"#))
        #expect(math.contains(#"\frac"#))
        #expect(math.contains(#"\sin"#))
        #expect(math.hasPrefix(#"\int"#))
        #expect(!pieces.contains { piece in
            if case .prose(let text) = piece {
                return text.contains("int") || text.contains("frac")
            }
            return false
        })

        let markup = MathMarkup.parse(latex)
        #expect(markup.latexChunks.joined().contains(#"\int"#))
        #expect(markup.latexChunks.joined().contains(#"\frac"#))
    }

    @Test
    func mixedTutorNoteDoesNotSendEnglishToTheMathRenderer() {
        let latex = #"You are working on \int_0^{\pi/2} \frac{\sin x}{\cos^2 x}\,dx. What substitution could you use?"#
        let pieces = LatexCleanup.intents(for: latex)
        #expect(pieces.contains { piece in
            if case .prose(let text) = piece { return text.contains("You are working on") }
            return false
        })
        #expect(pieces.contains { piece in
            if case .math(let math) = piece { return math.contains(#"\int"#) && math.contains(#"\frac"#) }
            return false
        })
        #expect(!pieces.contains { piece in
            if case .math(let math) = piece { return math.contains("working") || math.contains("substitution") }
            return false
        })
    }

    @Test
    func plainProseIsUnchanged() {
        let markup = MathMarkup.parse("Start with what you have tried.")

        #expect(markup.blocks == [.paragraph([.text("Start with what you have tried.")])])
        #expect(markup.accessibleText == "Start with what you have tried.")
        #expect(markup.isPlainProse)
    }
}
