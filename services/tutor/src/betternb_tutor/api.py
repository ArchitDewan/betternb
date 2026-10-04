from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import PlainTextResponse

from .contracts import TranscriptionResponse, TutorTurnRequest, TutorTurnResponse
from .orchestrator import TutorOrchestrator


MAXIMUM_IMAGE_BYTES = 10 * 1_024 * 1_024
SUPPORTED_IMAGE_TYPES = {"image/png", "image/jpeg"}


def create_app(orchestrator: TutorOrchestrator) -> FastAPI:
    app = FastAPI(title="BetterNB Tutor", version="1.0.0")

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

    return app


def _has_valid_signature(data: bytes, media_type: str) -> bool:
    if media_type == "image/png":
        return data.startswith(b"\x89PNG\r\n\x1a\n")
    if media_type == "image/jpeg":
        return data.startswith(b"\xff\xd8\xff")
    return False
