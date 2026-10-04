import re

from .contracts import (
    SourceReference,
    TutorAction,
    TutorTurnRequest,
    TutorTurnResponse,
    VerificationStatus,
)
from .knowledge import KnowledgeRepository
from .providers import ModelGateway
from .verification import DerivativeVerifier, VerificationResult

_STEP_NOTATION = re.compile(r"(f\s*['′]\s*\(|dy\s*/\s*dx|d\s*/\s*dx)", re.IGNORECASE)
_CALCULUS_REQUEST = re.compile(
    r"(differentiate|derivative|d\s*/\s*dx|f\s*['′]\s*\()",
    re.IGNORECASE,
)


class TutorOrchestrator:
    def __init__(
        self,
        model: ModelGateway,
        knowledge: KnowledgeRepository,
        verifier: DerivativeVerifier,
    ) -> None:
        self._model = model
        self._knowledge = knowledge
        self._verifier = verifier
        self._hint_levels: dict[str, int] = {}

    def respond(self, request: TutorTurnRequest) -> TutorTurnResponse:
        if request.action is TutorAction.REQUEST_HINT:
            current_level = self._hint_levels.get(request.session_id, 0)
            expected_level = min(current_level + 1, 3)
            if request.hint_level != expected_level:
                return TutorTurnResponse(
                    capability="tutor.policy",
                    assessment="not_assessed",
                    message="Hints must be requested one level at a time.",
                    verification_status=VerificationStatus.INCONCLUSIVE,
                    sources=[],
                    action_accepted=False,
                    next_hint_level=expected_level,
                    next_action="request_hint",
                )
            self._hint_levels[request.session_id] = request.hint_level

        effective = self._effective_request(request)
        supports_problem = self._verifier.supports(effective.problem)
        should_retrieve = supports_problem or _looks_like_calculus_request(effective.problem)
        search_results = self._knowledge.search(effective.problem, limit=3) if should_retrieve else []
        context = [result.chunk for result in search_results]

        verification = self._verification_for(effective, supports_problem)
        capability = "calculus.derivatives" if should_retrieve else "general.university-math"
        assessment = self._model.assess(effective, context, verification)

        if effective.action is not TutorAction.CHECK_STEP or verification.status is VerificationStatus.INCONCLUSIVE:
            if effective.action is TutorAction.CHECK_STEP:
                response_status = VerificationStatus.MODEL_JUDGED
                response_assessment = assessment.assessment
            else:
                response_status = VerificationStatus.INCONCLUSIVE
                response_assessment = "not_assessed"
        else:
            response_status = verification.status
            response_assessment = "correct" if verification.is_correct else "incorrect"

        if request.action is TutorAction.REQUEST_HINT:
            next_hint = request.hint_level + 1 if request.hint_level < 3 else None
            next_action = "request_hint" if next_hint is not None else "reveal_solution"
        elif request.action is TutorAction.REVEAL_SOLUTION:
            next_hint = None
            next_action = "continue_practice"
        else:
            next_hint = max(1, self._hint_levels.get(request.session_id, 0) + 1)
            next_action = "request_hint"

        return TutorTurnResponse(
            capability=capability,
            assessment=response_assessment,
            message=assessment.message,
            error_category=assessment.error_category,
            verification_status=response_status,
            sources=[
                SourceReference(
                    source_id=result.chunk.source_id,
                    title=result.chunk.title,
                    section=result.chunk.section,
                )
                for result in search_results
            ],
            next_hint_level=next_hint,
            next_action=next_action,
        )

    def transcribe(self, data: bytes, media_type: str) -> str:
        return self._model.transcribe(data, media_type)

    def _verification_for(self, request: TutorTurnRequest, supports_problem: bool) -> VerificationResult:
        if supports_problem and request.action is TutorAction.CHECK_STEP and request.attempt_steps:
            return self._verifier.verify(request.problem, request.attempt_steps[-1])
        return VerificationResult(
            status=VerificationStatus.INCONCLUSIVE,
            is_correct=None,
            detail="Conversation only; the solver was not used.",
        )

    @staticmethod
    def _effective_request(request: TutorTurnRequest) -> TutorTurnRequest:
        if request.action is TutorAction.CHECK_STEP and not _looks_like_step(
            request.attempt_steps[-1] if request.attempt_steps else ""
        ):
            return request.model_copy(update={"action": TutorAction.CHAT})
        return request


def _looks_like_step(text: str) -> bool:
    if _STEP_NOTATION.search(text):
        return True
    stripped = text.strip()
    if "?" in stripped or len(stripped) > 200:
        return False
    return bool(re.fullmatch(r"[0-9A-Za-z+\-*/^().\s]+=.+", stripped))


def _looks_like_calculus_request(text: str) -> bool:
    return _CALCULUS_REQUEST.search(text) is not None
