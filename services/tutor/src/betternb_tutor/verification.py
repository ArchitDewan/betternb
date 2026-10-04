import re
from dataclasses import dataclass

import sympy

from .contracts import VerificationStatus


@dataclass(frozen=True)
class VerificationResult:
    status: VerificationStatus
    is_correct: bool | None
    detail: str


class DerivativeVerifier:
    """Verifies the final derivative expression for a deliberately narrow v1 grammar."""

    _allowed_names = {"x", "sin", "cos", "tan", "exp", "log", "ln", "sqrt"}
    _allowed_characters = re.compile(r"^[0-9A-Za-z+\-*/^().\s]+$")
    _problem_pattern = re.compile(r"f\s*\(\s*x\s*\)\s*=\s*(.+)$", re.IGNORECASE)
    _step_pattern = re.compile(r"f\s*['′]\s*\(\s*x\s*\)\s*=\s*(.+)$", re.IGNORECASE)

    def __init__(self) -> None:
        self._x = sympy.Symbol("x", real=True)
        self._locals = {
            "x": self._x,
            "sin": sympy.sin,
            "cos": sympy.cos,
            "tan": sympy.tan,
            "exp": sympy.exp,
            "log": sympy.log,
            "ln": sympy.log,
            "sqrt": sympy.sqrt,
        }

    def supports(self, problem: str) -> bool:
        problem_expression = self._extract(self._problem_pattern, problem)
        if problem_expression is None:
            return False
        try:
            self._safe_parse(problem_expression)
        except (TypeError, ValueError, SyntaxError, sympy.SympifyError):
            return False
        return True

    def verify(self, problem: str, step: str) -> VerificationResult:
        problem_expression = self._extract(self._problem_pattern, problem)
        step_expression = self._extract(self._step_pattern, step)
        if problem_expression is None or step_expression is None:
            return self._inconclusive("This verifier currently supports f(x) and f'(x) expressions.")

        try:
            original = self._safe_parse(problem_expression)
            proposed = self._safe_parse(step_expression)
            expected = sympy.diff(original, self._x)
            difference = sympy.simplify(expected - proposed)
        except (TypeError, ValueError, SyntaxError, sympy.SympifyError):
            return self._inconclusive("The expression is outside the supported derivative grammar.")

        if difference == 0:
            return VerificationResult(
                status=VerificationStatus.VERIFIED,
                is_correct=True,
                detail="The proposed derivative is symbolically equivalent to the expected derivative.",
            )
        return VerificationResult(
            status=VerificationStatus.VERIFIED,
            is_correct=False,
            detail="The proposed derivative is not symbolically equivalent to the expected derivative.",
        )

    def _safe_parse(self, expression: str) -> sympy.Expr:
        normalized = expression.strip().replace("^", "**").replace("×", "*").replace("÷", "/")
        if len(normalized) > 1_000 or not self._allowed_characters.fullmatch(normalized):
            raise ValueError("unsupported expression")
        names = set(re.findall(r"[A-Za-z]+", normalized))
        if not names.issubset(self._allowed_names):
            raise ValueError("unsupported symbol or function")
        normalized = re.sub(r"(?<=\d)(?=[A-Za-z(])", "*", normalized)
        normalized = re.sub(r"(?<=x)(?=\()", "*", normalized)
        normalized = re.sub(r"(?<=\))(?=[x\d(])", "*", normalized)
        parsed = sympy.sympify(normalized, locals=self._locals, evaluate=True)
        if not isinstance(parsed, sympy.Expr) or parsed.free_symbols - {self._x}:
            raise ValueError("unsupported expression")
        return parsed

    @staticmethod
    def _extract(pattern: re.Pattern[str], text: str) -> str | None:
        match = pattern.search(text.strip())
        return match.group(1).strip() if match else None

    @staticmethod
    def _inconclusive(detail: str) -> VerificationResult:
        return VerificationResult(VerificationStatus.INCONCLUSIVE, None, detail)
