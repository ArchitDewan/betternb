from betternb_tutor.contracts import TutorAction, TutorTurnRequest, VerificationStatus
from betternb_tutor.knowledge import KnowledgeChunk, SearchResult
from betternb_tutor.orchestrator import TutorOrchestrator
from betternb_tutor.providers import ModelAssessment
from betternb_tutor.verification import VerificationResult


class StubKnowledgeRepository:
    def search(self, query: str, limit: int = 3) -> list[SearchResult]:
        return [
            SearchResult(
                chunk=KnowledgeChunk(
                    source_id="calc.derivatives.chain-rule",
                    title="Chain rule",
                    section="Method",
                    topic="derivatives",
                    content="Differentiate the outside, then multiply by the inside derivative.",
                ),
                score=0.91,
            )
        ]


class StubVerifier:
    def supports(self, problem: str) -> bool:
        return "Differentiate" in problem

    def verify(self, problem: str, step: str) -> VerificationResult:
        return VerificationResult(
            status=VerificationStatus.VERIFIED,
            is_correct=False,
            detail="The inner derivative is missing.",
        )


class StubModelGateway:
    def assess(self, request, context, verification) -> ModelAssessment:
        return ModelAssessment(
            assessment="incorrect",
            message="You differentiated the outside, but the inner derivative is still needed.",
            error_category="conceptual",
        )

    def transcribe(self, data: bytes, media_type: str) -> str:
        return "f(x) = (x^2 + 1)^3"


class CorrectVerifier:
    def supports(self, problem: str) -> bool:
        return True

    def verify(self, problem: str, step: str) -> VerificationResult:
        return VerificationResult(
            status=VerificationStatus.VERIFIED,
            is_correct=True,
            detail="The expressions are equivalent.",
        )


def make_orchestrator() -> TutorOrchestrator:
    return TutorOrchestrator(
        model=StubModelGateway(),
        knowledge=StubKnowledgeRepository(),
        verifier=StubVerifier(),
    )


def test_verified_status_comes_from_the_math_tool_and_includes_sources() -> None:
    response = make_orchestrator().respond(
        TutorTurnRequest(
            session_id="session-1",
            problem="Differentiate f(x) = (x^2 + 1)^3",
            attempt_steps=["f'(x) = 3*(x^2 + 1)^2"],
            action=TutorAction.CHECK_STEP,
            hint_level=0,
            solution_revealed=False,
        )
    )

    assert response.verification_status is VerificationStatus.VERIFIED
    assert response.assessment == "incorrect"
    assert response.sources[0].source_id == "calc.derivatives.chain-rule"


def test_model_cannot_override_the_deterministic_assessment() -> None:
    response = TutorOrchestrator(
        model=StubModelGateway(),
        knowledge=StubKnowledgeRepository(),
        verifier=CorrectVerifier(),
    ).respond(
        TutorTurnRequest(
            session_id="session-1",
            problem="Differentiate f(x) = x^2",
            attempt_steps=["f'(x) = 2x"],
            action=TutorAction.CHECK_STEP,
            hint_level=0,
            solution_revealed=False,
        )
    )

    assert response.verification_status is VerificationStatus.VERIFIED
    assert response.assessment == "correct"


def test_hint_levels_must_progress_one_at_a_time() -> None:
    orchestrator = make_orchestrator()

    response = orchestrator.respond(
        TutorTurnRequest(
            session_id="session-1",
            problem="Differentiate f(x) = x^2",
            attempt_steps=[],
            action=TutorAction.REQUEST_HINT,
            hint_level=2,
            solution_revealed=False,
        )
    )

    assert response.action_accepted is False
    assert response.next_hint_level == 1
    assert "one level" in response.message.lower()


def test_full_solution_requires_explicit_reveal_action() -> None:
    orchestrator = make_orchestrator()

    hint = orchestrator.respond(
        TutorTurnRequest(
            session_id="session-1",
            problem="Differentiate f(x) = x^2",
            attempt_steps=[],
            action=TutorAction.REQUEST_HINT,
            hint_level=1,
            solution_revealed=False,
        )
    )
    reveal = orchestrator.respond(
        TutorTurnRequest(
            session_id="session-1",
            problem="Differentiate f(x) = x^2",
            attempt_steps=[],
            action=TutorAction.REVEAL_SOLUTION,
            hint_level=3,
            solution_revealed=True,
        )
    )

    assert hint.next_action == "request_hint"
    assert reveal.next_action == "continue_practice"


class RecordingKnowledgeRepository:
    def __init__(self) -> None:
        self.queries: list[str] = []

    def search(self, query: str, limit: int = 3) -> list[SearchResult]:
        self.queries.append(query)
        return []


def test_retrieval_query_uses_the_problem_not_student_steps() -> None:
    knowledge = RecordingKnowledgeRepository()
    response = TutorOrchestrator(
        model=StubModelGateway(),
        knowledge=knowledge,
        verifier=StubVerifier(),
    ).respond(
        TutorTurnRequest(
            session_id="session-1",
            problem="Differentiate f(x) = x^2",
            attempt_steps=["I tried the chain rule", "f'(x) = x"],
            action=TutorAction.CHECK_STEP,
            hint_level=0,
            solution_revealed=False,
        )
    )

    assert knowledge.queries == ["Differentiate f(x) = x^2"]
    assert response.sources == []


def test_informal_help_request_is_conversation_not_a_solver_check() -> None:
    response = make_orchestrator().respond(
        TutorTurnRequest(
            session_id="session-1",
            problem="can you help me differentiate 7x^2 + 4x?",
            attempt_steps=["hmmm i think i take derivatives individually?"],
            action=TutorAction.CHECK_STEP,
            hint_level=0,
            solution_revealed=False,
        )
    )

    assert response.assessment == "not_assessed"
    assert response.verification_status is VerificationStatus.INCONCLUSIVE
    assert response.action_accepted is True


def test_chat_action_does_not_claim_verification() -> None:
    response = make_orchestrator().respond(
        TutorTurnRequest(
            session_id="session-1",
            problem="can you help me differentiate 7x^2 + 4x?",
            attempt_steps=[],
            action=TutorAction.CHAT,
            hint_level=0,
            solution_revealed=False,
        )
    )

    assert response.assessment == "not_assessed"
    assert response.verification_status is VerificationStatus.INCONCLUSIVE


def test_unsupported_subject_does_not_receive_irrelevant_derivative_sources() -> None:
    response = make_orchestrator().respond(
        TutorTurnRequest(
            session_id="session-1",
            problem="Prove every compact subset of R is closed",
            attempt_steps=["Let K be compact"],
            action=TutorAction.CHECK_STEP,
            hint_level=0,
            solution_revealed=False,
        )
    )

    assert response.capability == "general.university-math"
    assert response.verification_status is VerificationStatus.INCONCLUSIVE
    assert response.assessment == "not_assessed"
    assert response.sources == []
