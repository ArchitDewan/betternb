from fastapi.testclient import TestClient

from betternb_tutor.api import create_app
from betternb_tutor.contracts import VerificationStatus
from betternb_tutor.knowledge import KnowledgeChunk, SearchResult
from betternb_tutor.orchestrator import TutorOrchestrator
from betternb_tutor.providers import ModelAssessment
from betternb_tutor.verification import VerificationResult


class StubKnowledgeRepository:
    def search(self, query: str, limit: int = 3) -> list[SearchResult]:
        return [
            SearchResult(
                chunk=KnowledgeChunk(
                    source_id="calc.derivatives.power-rule",
                    title="Power rule",
                    section="Method",
                    topic="derivatives",
                    content="Multiply by the exponent and reduce it by one.",
                ),
                score=1.0,
            )
        ]


class StubVerifier:
    def supports(self, problem: str) -> bool:
        return True

    def verify(self, problem: str, step: str) -> VerificationResult:
        return VerificationResult(VerificationStatus.VERIFIED, True, "Equivalent derivative.")


class StubModel:
    def assess(self, request, context, verification) -> ModelAssessment:
        return ModelAssessment("correct", "That step is correct.", None)

    def transcribe(self, data: bytes, media_type: str) -> str:
        return "Differentiate f(x) = x^2"


def client() -> TestClient:
    orchestrator = TutorOrchestrator(StubModel(), StubKnowledgeRepository(), StubVerifier())
    return TestClient(create_app(orchestrator))


def test_health_and_tutor_turn_contract() -> None:
    test_client = client()

    assert test_client.get("/healthz").text == "ok\n"
    response = test_client.post(
        "/v1/tutor/turns",
        json={
            "session_id": "session-1",
            "problem": "Differentiate f(x) = x^2",
            "attempt_steps": ["f'(x) = 2*x"],
            "action": "check_step",
            "hint_level": 0,
            "solution_revealed": False,
        },
    )

    assert response.status_code == 200
    assert response.json()["verification_status"] == "verified"
    assert response.json()["sources"][0]["source_id"] == "calc.derivatives.power-rule"


def test_conversation_history_is_accepted() -> None:
    response = client().post(
        "/v1/tutor/turns",
        json={
            "session_id": "session-1",
            "problem": "Differentiate f(x) = x^2",
            "attempt_steps": [],
            "conversation": [
                {"role": "student", "kind": "problem", "text": "Differentiate f(x) = x^2"},
                {"role": "tutor", "kind": "message", "text": "Start with the first term."},
            ],
            "action": "chat",
            "hint_level": 0,
            "solution_revealed": False,
        },
    )

    assert response.status_code == 200
    assert response.json()["assessment"] == "not_assessed"


def test_chat_turn_is_accepted_without_a_step() -> None:
    response = client().post(
        "/v1/tutor/turns",
        json={
            "session_id": "session-1",
            "problem": "can you help me differentiate 7x^2 + 4x?",
            "attempt_steps": [],
            "action": "chat",
            "hint_level": 0,
            "solution_revealed": False,
        },
    )

    assert response.status_code == 200
    assert response.json()["assessment"] == "not_assessed"


def test_transcription_rejects_pdf_and_marks_image_for_confirmation() -> None:
    test_client = client()

    unsupported = test_client.post(
        "/v1/math/transcriptions",
        files={"image": ("notes.pdf", b"%PDF", "application/pdf")},
    )
    spoofed = test_client.post(
        "/v1/math/transcriptions",
        files={"image": ("problem.png", b"not an image", "image/png")},
    )
    accepted = test_client.post(
        "/v1/math/transcriptions",
        files={"image": ("problem.png", b"\x89PNG\r\n\x1a\n", "image/png")},
    )

    assert unsupported.status_code == 415
    assert spoofed.status_code == 415
    assert accepted.status_code == 200
    assert accepted.json()["requires_confirmation"] is True
    assert accepted.json()["transcription"] == "Differentiate f(x) = x^2"
