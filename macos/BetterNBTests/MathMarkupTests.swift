import Testing
@testable import BetterNB

struct MathMarkupTests {
    @Test
    func fractionAndBoxCommandsBecomeStructuredMath() {
        let markup = MathMarkup.parse(#"The slope is \frac{1}{2} and the answer is \boxed{2x}."#)

        #expect(markup.contains(.fraction))
        #expect(markup.contains(.boxed))
        #expect(!markup.accessibleText.contains("\\frac"))
        #expect(!markup.accessibleText.contains("\\boxed"))
        #expect(markup.accessibleText.contains("1/2"))
        #expect(markup.accessibleText.contains("2x"))
    }

    @Test
    func extractedProblemPreviewRendersDisplayMathInsteadOfRawTeX() {
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
        #expect(markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(!markup.accessibleText.contains("\\frac"))
        #expect(!markup.accessibleText.contains("\\sqrt"))
        #expect(!markup.accessibleText.contains("\\sec"))
        #expect(!markup.accessibleText.contains("\\["))
        #expect(markup.accessibleText.contains("8/√(x)"))
        #expect(markup.accessibleText.contains("sec"))
        #expect(markup.accessibleText.contains("#35"))
    }

    @Test
    func delimitedDisplayMathIsASeparateBlock() {
        let markup = MathMarkup.parse("Differentiate both sides.\n\n\\[ f'(x) = 2x \\]")

        #expect(markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(!markup.accessibleText.contains("\\["))
        #expect(markup.accessibleText.contains("f'(x) = 2x"))
    }

    @Test
    func inlineDelimitersAndSuperscriptsRenderAsMath() {
        let markup = MathMarkup.parse(#"Start from \( x^{2} \) and apply the power rule."#)

        #expect(markup.contains(.superscript))
        #expect(!markup.accessibleText.contains("\\("))
        #expect(markup.accessibleText.contains("x^2"))
    }

    @Test
    func alignEnvironmentsBecomeDisplayMath() {
        let markup = MathMarkup.parse(#"\begin{align} f'(x) &= 2x \\ &= 2x \end{align}"#)

        #expect(markup.blocks.contains { block in
            if case .display = block { return true }
            return false
        })
        #expect(!markup.accessibleText.contains("\\begin"))
        #expect(!markup.accessibleText.contains("&"))
        #expect(!markup.accessibleText.contains("begin"))
    }

    @Test
    func alignedInsideDisplayDoesNotLeakTeX() {
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
        #expect(!markup.accessibleText.contains("end"))
        #expect(!markup.accessibleText.contains("&"))
        #expect(markup.accessibleText.contains("14x + 4") || markup.accessibleText.contains("14x+4"))
    }

    @Test
    func sentenceInsideDisplayKeepsReadableSpacing() {
        let markup = MathMarkup.parse(
            #"\[ For #35, you're finding the derivative of 7x^{5}. \]"#
        )

        #expect(markup.accessibleText.contains("For #35"))
        #expect(markup.accessibleText.contains("finding the derivative"))
        #expect(!markup.accessibleText.contains("For#35"))
        #expect(!markup.accessibleText.contains("findingthe"))
    }

    @Test
    func liveRevealMessageRendersWithoutRawCommands() {
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
        #expect(!markup.accessibleText.contains("\\frac"))
        #expect(!markup.accessibleText.contains("\\boxed"))
        #expect(!markup.accessibleText.contains("\\["))
        #expect(markup.accessibleText.contains("d/dx"))
        #expect(markup.accessibleText.contains("f'(x) = 2x"))
    }

    @Test
    func operatorsAndFunctionsGetReadableSpacing() {
        let markup = MathMarkup.parse(#"\[ \frac{8}{\sqrt{x}}=8x^{-1/2}. \]"#)

        #expect(markup.accessibleText.contains(" = "))
        #expect(!markup.accessibleText.contains(")=8"))
        #expect(!markup.accessibleText.contains("x)=8"))
    }

    @Test
    func trigProductsKeepAGapAfterEachFunction() {
        let markup = MathMarkup.parse(#"\[ -4\sec x\tan x \]"#)

        #expect(markup.accessibleText.contains("sec x"))
        #expect(markup.accessibleText.contains("tan x"))
        #expect(!markup.accessibleText.contains("secxtan"))
        #expect(!markup.accessibleText.contains("secx"))
        #expect(!markup.accessibleText.contains("tanx"))
        #expect(markup.accessibleText.contains("-4"))
        #expect(!markup.accessibleText.contains("- 4"))
    }

    @Test
    func binaryMinusIsSpacedAndUnaryMinusStaysTight() {
        let binary = MathMarkup.parse(#"\[ 7x^5-x^4 \]"#)
        #expect(binary.accessibleText.contains("7x^5 - x^4"))

        let unary = MathMarkup.parse(#"\[ -4x \]"#)
        #expect(unary.accessibleText.contains("-4x"))
        #expect(!unary.accessibleText.contains("- 4"))
    }

    @Test
    func shortEquationStaysOnOneLineWithOperatorSpaces() {
        let markup = MathMarkup.parse(#"\[ f'(x)=2x \]"#)

        #expect(markup.accessibleText.contains("f'(x) = 2x"))
        #expect(!markup.accessibleText.contains("\n"))
        #expect(markup.blocks.contains { block in
            if case .display(.lines) = block { return false }
            if case .display = block { return true }
            return false
        })
    }

    @Test
    func longDisplayEquationBreaksAtEquals() {
        let markup = MathMarkup.parse(
            #"\[ \frac{d}{dx}(7x^5-x^4+4x^{3/2}+8x^{-1/2}-4\sec x)=35x^4-4x^3+6x^{1/2}-4x^{-3/2}-4\sec x\tan x \]"#
        )

        #expect(markup.blocks.contains { block in
            if case .display(.lines) = block { return true }
            return false
        })
        #expect(markup.accessibleText.contains("\n="))
        #expect(markup.accessibleText.components(separatedBy: "\n").count >= 4)
        #expect(markup.accessibleText.contains("sec x"))
        #expect(markup.accessibleText.contains("tan x"))
        #expect(!markup.accessibleText.contains("secxtan"))
    }

    @Test
    func boxedLongAnswerStacksTerms() {
        let markup = MathMarkup.parse(
            #"\[ \boxed{35x^4-4x^3+6x^{1/2}-4x^{-3/2}-4\sec x\tan x} \]"#
        )

        #expect(markup.contains(.boxed))
        #expect(markup.accessibleText.components(separatedBy: "\n").count >= 3)
        #expect(markup.accessibleText.contains("sec x"))
        #expect(!markup.accessibleText.contains("secxtan"))
    }

    @Test
    func plainProseKeepsWordSpacing() {
        let source = "can you help me differentiate 7x^2 + 4x?"
        let markup = MathMarkup.parse(source)

        #expect(markup.isPlainProse)
        #expect(markup.accessibleText == source)
        #expect(markup.accessibleText.contains("help me differentiate"))
    }

    @Test
    func plainProseIsUnchanged() {
        let markup = MathMarkup.parse("Start with what you have tried.")

        #expect(markup.blocks == [.paragraph([.text("Start with what you have tried.")])])
        #expect(markup.accessibleText == "Start with what you have tried.")
        #expect(markup.isPlainProse)
    }
}
