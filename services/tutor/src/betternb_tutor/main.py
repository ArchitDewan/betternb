import os
from pathlib import Path

import uvicorn
from openai import OpenAI

from .api import create_app
from .course_study import CourseSourceIndex, CourseStudyService
from .knowledge import load_markdown_knowledge, load_or_build_repository
from .orchestrator import TutorOrchestrator
from .providers import OpenAIEmbeddingGateway, OpenAIModelGateway
from .verification import DerivativeVerifier


def build_app():
    repository_root = Path(__file__).resolve().parents[4]
    client = OpenAI(api_key=os.environ["OPENAI_API_KEY"], timeout=30.0, max_retries=1)
    model_name = os.getenv("BETTERNB_OPENAI_MODEL", "gpt-6.1-sol")
    embedding_model = os.getenv("BETTERNB_EMBEDDING_MODEL", "text-embedding-3-small")
    embeddings = OpenAIEmbeddingGateway(client, model=embedding_model)
    chunks = load_markdown_knowledge(repository_root / "services/tutor/knowledge/calculus/derivatives")
    knowledge = load_or_build_repository(
        chunks,
        embeddings,
        repository_root / ".build/tutor/derivatives-index.json",
        cache_key=f"{embedding_model}:{embeddings.dimensions}:title-section-v1",
    )
    model = OpenAIModelGateway(client, model=model_name)
    orchestrator = TutorOrchestrator(
        model=model,
        knowledge=knowledge,
        verifier=DerivativeVerifier(),
    )
    course_study = CourseStudyService(CourseSourceIndex(embeddings), model)
    return create_app(orchestrator, course_study=course_study)


def run() -> None:
    address = os.getenv("BETTERNB_TUTOR_ADDRESS", "127.0.0.1")
    if address not in {"127.0.0.1", "localhost", "::1"}:
        raise RuntimeError("F009A tutor service must bind to a loopback address")
    port = int(os.getenv("BETTERNB_TUTOR_PORT", "8082"))
    uvicorn.run(build_app(), host=address, port=port, log_level="info")


if __name__ == "__main__":
    run()
