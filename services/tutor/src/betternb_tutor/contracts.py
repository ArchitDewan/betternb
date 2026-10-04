from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, model_validator


class TutorAction(StrEnum):
    CHAT = "chat"
    CHECK_STEP = "check_step"
    REQUEST_HINT = "request_hint"
    REVEAL_SOLUTION = "reveal_solution"


class VerificationStatus(StrEnum):
    VERIFIED = "verified"
    MODEL_JUDGED = "model_judged"
    INCONCLUSIVE = "inconclusive"


class TutorTurnRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    session_id: str = Field(min_length=1, max_length=128)
    problem: str = Field(min_length=1, max_length=20_000)
    attempt_steps: list[str] = Field(default_factory=list, max_length=100)
    action: TutorAction
    hint_level: int = Field(default=0, ge=0, le=3)
    solution_revealed: bool = False

    @model_validator(mode="after")
    def validate_action_payload(self) -> "TutorTurnRequest":
        if self.action is TutorAction.CHECK_STEP and not self.attempt_steps:
            raise ValueError("check_step requires at least one attempt step")
        if self.action is TutorAction.REQUEST_HINT and self.hint_level == 0:
            raise ValueError("request_hint requires hint_level 1, 2, or 3")
        return self


class SourceReference(BaseModel):
    source_id: str
    title: str
    section: str


class TutorTurnResponse(BaseModel):
    capability: str
    assessment: str
    message: str
    error_category: str | None = None
    verification_status: VerificationStatus
    sources: list[SourceReference]
    action_accepted: bool = True
    next_hint_level: int | None = None
    next_action: str


class TranscriptionResponse(BaseModel):
    transcription: str
    requires_confirmation: bool = True
