from enum import StrEnum
from typing import Literal

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


class ConversationTurn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    role: str = Field(min_length=1, max_length=16)
    text: str = Field(min_length=1, max_length=20_000)
    kind: str = "message"


class TutorTurnRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    session_id: str = Field(min_length=1, max_length=128)
    problem: str = Field(min_length=1, max_length=20_000)
    attempt_steps: list[str] = Field(default_factory=list, max_length=100)
    conversation: list[ConversationTurn] = Field(default_factory=list, max_length=24)
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
    summary: str | None = None
    error_category: str | None = None
    verification_status: VerificationStatus
    sources: list[SourceReference]
    action_accepted: bool = True
    next_hint_level: int | None = None
    next_action: str


class TranscriptionResponse(BaseModel):
    transcription: str
    requires_confirmation: bool = True


class CourseSourceResponse(BaseModel):
    source_id: str
    filename: str
    page_count: int
    chunk_count: int
    media_type: str = "application/pdf"
    unreadable_pages: list[int] = Field(default_factory=list)


class CourseQuestionImage(BaseModel):
    model_config = ConfigDict(extra="forbid")

    media_type: str
    data: str


class CourseQuestionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    question: str = Field(min_length=1, max_length=20_000)
    image: CourseQuestionImage | None = None


class CourseAnswerResponse(BaseModel):
    answer: str
    sources: list[SourceReference]


class GenerateProblemsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    count: int = Field(default=3, ge=1, le=8)
    source_id: str | None = None


class GeneratedProblemResponse(BaseModel):
    prompt: str
    sources: list[SourceReference]


class GeneratedProblemsResponse(BaseModel):
    problems: list[GeneratedProblemResponse]


class GenerateQuizRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    count: Literal[3, 5, 10] = 5
    difficulty: Literal["easy", "standard", "challenging"] = "standard"
    source_id: str | None = None


class QuizQuestionResponse(BaseModel):
    prompt: str
    options: list[str]
    correct_index: int
    explanation: str


class GeneratedQuizResponse(BaseModel):
    questions: list[QuizQuestionResponse]
    sources: list[SourceReference]


class GenerateFlashcardsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    count: int = Field(default=5, ge=1, le=15)
    source_id: str | None = Field(default=None, min_length=1, max_length=128)


class GeneratedFlashcardResponse(BaseModel):
    front: str
    back: str
    sources: list[SourceReference]


class GeneratedFlashcardsResponse(BaseModel):
    cards: list[GeneratedFlashcardResponse]


class GenerateSummaryRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source_id: str = Field(min_length=1, max_length=128)


class SummaryIdeaResponse(BaseModel):
    heading: str
    explanation: str
    sources: list[SourceReference]


class GeneratedSummaryResponse(BaseModel):
    overview: str
    ideas: list[SummaryIdeaResponse]
