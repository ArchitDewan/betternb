import base64
import binascii

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import PlainTextResponse, Response
from starlette.concurrency import run_in_threadpool

from .contracts import (
    CourseAnswerResponse,
    CourseQuestionRequest,
    CourseSourceResponse,
    GeneratedProblemResponse,
    GeneratedProblemsResponse,
    GeneratedQuizResponse,
    GenerateQuizRequest,
    QuizQuestionResponse,
    GenerateProblemsRequest,
    GeneratedFlashcardResponse,
    GeneratedFlashcardsResponse,
    GenerateFlashcardsRequest,
    GenerateSummaryRequest,
    GeneratedSummaryResponse,
    SummaryIdeaResponse,
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

        @app.get("/v1/courses/{course_id}/sources/{source_id}/document")
        def read_course_source(course_id: str, source_id: str) -> Response:
            document = course_study.sources.get_document(course_id, source_id)
            if document is None:
                raise HTTPException(status_code=404, detail="Course source not found.")
            source = course_study.sources.source(course_id, source_id)
            return Response(content=document, media_type=source.media_type if source else "application/octet-stream")

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

        @app.post("/v1/courses/{course_id}/worksheets", response_model=CourseSourceResponse)
        async def import_worksheet(course_id: str, document: UploadFile = File(...)) -> CourseSourceResponse:
            if document.content_type not in {"application/pdf", *SUPPORTED_IMAGE_TYPES}:
                raise HTTPException(status_code=415, detail="Choose a PDF, PNG, or JPEG worksheet.")
            limit = MAXIMUM_PDF_BYTES if document.content_type == "application/pdf" else MAXIMUM_IMAGE_BYTES
            data = await document.read(limit + 1)
            if not data or len(data) > limit:
                raise HTTPException(status_code=413, detail="The worksheet is empty or too large.")
            if document.content_type == "application/pdf" and not data.startswith(b"%PDF"):
                raise HTTPException(status_code=415, detail="The file is not a valid PDF.")
            if document.content_type in SUPPORTED_IMAGE_TYPES and not _has_valid_signature(data, document.content_type):
                raise HTTPException(status_code=415, detail="The file is not a valid PNG or JPEG image.")
            try:
                source = await run_in_threadpool(
                    course_study.import_worksheet,
                    course_id, document.filename or "Worksheet", data, document.content_type,
                )
            except ValueError as error:
                raise HTTPException(status_code=422, detail=str(error)) from error
            except Exception as error:
                raise HTTPException(status_code=502, detail="The worksheet could not be read.") from error
            return CourseSourceResponse(**source.__dict__)

        @app.post("/v1/courses/{course_id}/sources/{source_id}/problems/extract",
                  response_model=GeneratedProblemsResponse)
        def extract_course_problems(course_id: str, source_id: str) -> GeneratedProblemsResponse:
            try:
                problems = course_study.extract_problems(course_id, source_id)
            except LookupError as error:
                raise HTTPException(status_code=404, detail=str(error)) from error
            except Exception as error:
                raise HTTPException(status_code=502, detail="Questions could not be extracted.") from error
            return GeneratedProblemsResponse(problems=[
                GeneratedProblemResponse(prompt=item.prompt, sources=item.sources) for item in problems
            ])

        @app.post("/v1/courses/{course_id}/answers", response_model=CourseAnswerResponse)
        def answer_course_question(course_id: str, request: CourseQuestionRequest) -> CourseAnswerResponse:
            image = None
            if request.image is not None:
                if request.image.media_type not in SUPPORTED_IMAGE_TYPES:
                    raise HTTPException(status_code=415, detail="Choose a PNG or JPEG image.")
                try:
                    data = base64.b64decode(request.image.data, validate=True)
                except binascii.Error as error:
                    raise HTTPException(status_code=400, detail="The image data is invalid.") from error
                if not data or not _has_valid_signature(data, request.image.media_type):
                    raise HTTPException(status_code=415, detail="The file content is not a valid PNG or JPEG image.")
                if len(data) > MAXIMUM_IMAGE_BYTES:
                    raise HTTPException(status_code=413, detail="Choose an image that is 10 MiB or smaller.")
                image = (data, request.image.media_type)
            try:
                answer = course_study.answer(course_id, request.question, image=image)
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
                problems = course_study.generate_problems(course_id, request.count, request.source_id)
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

        @app.post("/v1/courses/{course_id}/quizzes", response_model=GeneratedQuizResponse)
        def generate_course_quiz(course_id: str, request: GenerateQuizRequest) -> GeneratedQuizResponse:
            try:
                questions, sources = course_study.generate_quiz(
                    course_id, request.count, request.difficulty, source_id=request.source_id
                )
            except LookupError as error:
                raise HTTPException(status_code=409, detail=str(error)) from error
            except Exception as error:
                raise HTTPException(status_code=502, detail="The quiz could not be generated.") from error
            return GeneratedQuizResponse(
                questions=[QuizQuestionResponse(**question.__dict__) for question in questions],
                sources=sources,
            )

        @app.post("/v1/courses/{course_id}/flashcards", response_model=GeneratedFlashcardsResponse)
        def generate_course_flashcards(
            course_id: str, request: GenerateFlashcardsRequest,
        ) -> GeneratedFlashcardsResponse:
            try:
                cards = course_study.generate_flashcards(course_id, request.count, request.source_id)
            except LookupError as error:
                raise HTTPException(status_code=409, detail=str(error)) from error
            except Exception as error:
                raise HTTPException(status_code=502, detail="Course flashcards could not be generated.") from error
            return GeneratedFlashcardsResponse(cards=[
                GeneratedFlashcardResponse(front=card.front, back=card.back, sources=card.sources)
                for card in cards
            ])

        @app.post("/v1/courses/{course_id}/summaries", response_model=GeneratedSummaryResponse)
        def generate_course_summary(course_id: str, request: GenerateSummaryRequest) -> GeneratedSummaryResponse:
            try:
                summary = course_study.summarize(course_id, request.source_id)
            except LookupError as error:
                raise HTTPException(status_code=409, detail=str(error)) from error
            except Exception as error:
                raise HTTPException(status_code=502, detail="The summary could not be generated.") from error
            return GeneratedSummaryResponse(
                overview=summary.overview,
                ideas=[SummaryIdeaResponse(**idea.__dict__) for idea in summary.ideas],
            )

    return app


def _has_valid_signature(data: bytes, media_type: str) -> bool:
    if media_type == "image/png":
        return data.startswith(b"\x89PNG\r\n\x1a\n")
    if media_type == "image/jpeg":
        return data.startswith(b"\xff\xd8\xff")
    return False
