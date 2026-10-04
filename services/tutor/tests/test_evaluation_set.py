import json
from pathlib import Path

import pytest

from betternb_tutor.contracts import VerificationStatus
from betternb_tutor.verification import DerivativeVerifier


EVALUATION_PATH = Path(__file__).parents[1] / "evals/derivative_cases.json"
CASES = json.loads(EVALUATION_PATH.read_text(encoding="utf-8"))


@pytest.mark.parametrize("case", CASES, ids=[case["id"] for case in CASES])
def test_reviewed_derivative_case(case: dict[str, object]) -> None:
    result = DerivativeVerifier().verify(str(case["problem"]), str(case["step"]))

    assert result.status is VerificationStatus.VERIFIED
    assert result.is_correct is case["correct"]
