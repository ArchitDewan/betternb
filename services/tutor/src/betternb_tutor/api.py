from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import PlainTextResponse

from .contracts import (
    CourseAnswerResponse,
    CourseQuestionRequest,
    CourseSourceResponse,
    GeneratedProblemResponse,
    GeneratedProblemsResponse,
    GenerateProblemsRequest,
    TranscriptionResponse,
    TutorTurnRequest,
    TutorTurnResponse,
)
from .course_study import CourseStudyService
from .orchestrator import TutorOrchestrator


MAXIMUM_IMAGE_BYTES = 10 * 1_024 * 1_024
MAXIMUM_PDF_BYTES = 25 * 1_024 * 1_024
SUPPORTED_IMAGE_TYPES = {"image/png", "image/jpeg"}


def create_app(
    orchestrator: TutorOrchestrator,
    course_study: CourseStudyService | None = None,
) -> FastAPI:
    app = FastAPI(title="Lemma Tutor", version="1.0.0")

    @app.middleware("http")
    async def security_headers(request, call_next):
        response = await call_next(request)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        return response

    @app.get("/healthz", response_class=PlainTextResponse)
    def health() -> str:
        return "ok\n"

    @app.post("/v1/tutor/turns", response_model=TutorTurnResponse)
    def tutor_turn(request: TutorTurnRequest) -> TutorTurnResponse:
        try:
            return orchestrator.respond(request)
        except Exception as error:
            raise HTTPException(status_code=502, detail="The tutor is temporarily unavailable.") from error

    @app.post("/v1/math/transcriptions", response_model=TranscriptionResponse)
    async def transcribe(image: UploadFile = File(...)) -> TranscriptionResponse:
        if image.content_type not in SUPPORTED_IMAGE_TYPES:
            raise HTTPException(status_code=415, detail="Choose a PNG or JPEG image.")
        data = await image.read(MAXIMUM_IMAGE_BYTES + 1)
        if len(data) > MAXIMUM_IMAGE_BYTES:
            raise HTTPException(status_code=413, detail="Choose an image that is 10 MiB or smaller.")
        if not data:
            raise HTTPException(status_code=400, detail="The image is empty.")
        if not _has_valid_signature(data, image.content_type):
            raise HTTPException(status_code=415, detail="The file content is not a valid PNG or JPEG image.")
        try:
            transcription = orchestrator.transcribe(data, image.content_type)
        except Exception as error:
            raise HTTPException(status_code=502, detail="The image could not be transcribed.") from error
        return TranscriptionResponse(transcription=transcription)

    if course_study is not None:
        @app.get("/v1/courses/{course_id}/sources", response_model=list[CourseSourceResponse])
        def list_course_sources(course_id: str) -> list[CourseSourceResponse]:
            return [CourseSourceResponse(**source.__dict__) for source in course_study.sources.list_sources(course_id)]

        @app.post("/v1/courses/{course_id}/sources", response_model=CourseSourceResponse)
        async def import_course_source(course_id: str, document: UploadFile = File(...)) -> CourseSourceResponse:
            if document.content_type != "application/pdf":
                raise HTTPException(status_code=415, detail="Choose a PDF file.")
            data = await document.read(MAXIMUM_PDF_BYTES + 1)
            if len(data) > MAXIMUM_PDF_BYTES:
                raise HTTPException(status_code=413, detail="Choose a PDF that is 25 MiB or smaller.")
            try:
                source = course_study.sources.import_pdf(course_id, document.filename or "Course source.pdf", data)
            except ValueError as error:
                raise HTTPException(status_code=422, detail=str(error)) from error
            return CourseSourceResponse(**source.__dict__)

        @app.post("/v1/courses/{course_id}/answers", response_model=CourseAnswerResponse)
        def answer_course_question(course_id: str, request: CourseQuestionRequest) -> CourseAnswerResponse:
            try:
                answer = course_study.answer(course_id, request.question)
            except LookupError as error:
                raise HTTPException(status_code=409, detail=str(error)) from error
            except Exception as error:
                raise HTTPException(status_code=502, detail="The grounded answer could not be generated.") from error
            return CourseAnswerResponse(answer=answer.text, sources=answer.sources)

        @app.post("/v1/courses/{course_id}/problems", response_model=GeneratedProblemsResponse)
        def generate_course_problems(
            course_id: str,
            request: GenerateProblemsRequest,
        ) -> GeneratedProblemsResponse:
            try:
                problems = course_study.generate_problems(course_id, request.count)
            except LookupError as error:
                raise HTTPException(status_code=409, detail=str(error)) from error
            except Exception as error:
                raise HTTPException(status_code=502, detail="Course problems could not be generated.") from error
            return GeneratedProblemsResponse(
                problems=[
                    GeneratedProblemResponse(prompt=problem.prompt, sources=problem.sources)
                    for problem in problems
                ]
            )

    return app


def _has_valid_signature(data: bytes, media_type: str) -> bool:
    if media_type == "image/png":
        return data.startswith(b"\x89PNG\r\n\x1a\n")
    if media_type == "image/jpeg":
        return data.startswith(b"\xff\xd8\xff")
    return False
