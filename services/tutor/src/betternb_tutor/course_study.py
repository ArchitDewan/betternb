import hashlib
import math
import re
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from typing import Protocol

from pypdf import PdfReader

from .contracts import SourceReference
from .knowledge import EmbeddingGateway, KnowledgeChunk, SearchResult


@dataclass(frozen=True)
class CourseSource:
    source_id: str
    filename: str
    page_count: int
    chunk_count: int


@dataclass(frozen=True)
class GroundedAnswer:
    text: str
    sources: list[SourceReference]


@dataclass(frozen=True)
class GeneratedCourseProblem:
    prompt: str
    sources: list[SourceReference]


class CourseStudyModel(Protocol):
    def answer_course_question(self, question: str, context: list[KnowledgeChunk]) -> str: ...

    def generate_course_problems(self, context: list[KnowledgeChunk], count: int) -> list[str]: ...


class CourseSourceIndex:
    def __init__(self, embeddings: EmbeddingGateway) -> None:
        self._embeddings = embeddings
        self._sources: dict[str, dict[str, CourseSource]] = {}
        self._chunks: dict[str, list[KnowledgeChunk]] = {}
        self._vectors: dict[str, list[list[float]]] = {}

    def import_pdf(self, course_id: str, filename: str, data: bytes) -> CourseSource:
        safe_filename = Path(filename).name.strip()
        if not safe_filename or not data.startswith(b"%PDF"):
            raise ValueError("Choose a valid PDF file.")
        try:
            reader = PdfReader(BytesIO(data), strict=False)
        except Exception as error:
            raise ValueError("The PDF could not be read.") from error
        if reader.is_encrypted:
            raise ValueError("Password-protected PDFs are not supported.")
        if len(reader.pages) > 500:
            raise ValueError("Choose a PDF with 500 pages or fewer.")

        source_id = "course." + hashlib.sha256(
            course_id.encode() + b"\0" + safe_filename.encode() + b"\0" + data
        ).hexdigest()[:20]
        chunks: list[KnowledgeChunk] = []
        for page_index, page in enumerate(reader.pages, start=1):
            try:
                text = _normalize_text(page.extract_text() or "")
            except Exception as error:
                raise ValueError(f"Text could not be extracted from page {page_index}.") from error
            for chunk_index, content in enumerate(_chunk_text(text), start=1):
                chunks.append(
                    KnowledgeChunk(
                        source_id=f"{source_id}.p{page_index}.c{chunk_index}",
                        title=safe_filename,
                        section=f"Page {page_index}",
                        topic=course_id,
                        content=content,
                    )
                )
        if not chunks:
            raise ValueError("No readable text was found. Scanned PDFs need OCR, which is not supported yet.")

        source = CourseSource(
            source_id=source_id,
            filename=safe_filename,
            page_count=len(reader.pages),
            chunk_count=len(chunks),
        )
        existing_chunks = [
            chunk
            for chunk in self._chunks.get(course_id, [])
            if not chunk.source_id.startswith(f"{source_id}.")
        ]
        combined_chunks = existing_chunks + chunks
        self._chunks[course_id] = combined_chunks
        self._vectors[course_id] = self._embeddings.embed([_index_text(chunk) for chunk in combined_chunks])
        self._sources.setdefault(course_id, {})[source_id] = source
        return source

    def list_sources(self, course_id: str) -> list[CourseSource]:
        return sorted(self._sources.get(course_id, {}).values(), key=lambda source: source.filename.lower())

    def search(self, course_id: str, query: str, limit: int = 5) -> list[SearchResult]:
        chunks = self._chunks.get(course_id, [])
        vectors = self._vectors.get(course_id, [])
        if not chunks or limit < 1:
            return []
        query_vector = self._embeddings.embed([query])[0]
        query_terms = _terms(query)
        results = [
            SearchResult(
                chunk=chunk,
                score=(0.78 * _cosine(query_vector, vector)) + (0.22 * _lexical(query_terms, chunk)),
            )
            for chunk, vector in zip(chunks, vectors, strict=True)
        ]
        results.sort(key=lambda result: (-result.score, result.chunk.source_id))
        return [result for result in results if result.score > 0][:limit]

    def all_chunks(self, course_id: str, limit: int = 8) -> list[KnowledgeChunk]:
        return self._chunks.get(course_id, [])[:limit]


class CourseStudyService:
    def __init__(self, sources: CourseSourceIndex, model: CourseStudyModel) -> None:
        self.sources = sources
        self._model = model

    def answer(self, course_id: str, question: str) -> GroundedAnswer:
        results = self.sources.search(course_id, question, limit=5)
        if not results:
            raise LookupError("Add a readable course source before asking a grounded question.")
        context = [result.chunk for result in results]
        return GroundedAnswer(
            text=self._model.answer_course_question(question, context),
            sources=_references(context),
        )

    def generate_problems(self, course_id: str, count: int = 3) -> list[GeneratedCourseProblem]:
        context = self.sources.all_chunks(course_id)
        if not context:
            raise LookupError("Add a readable course source before generating problems.")
        prompts = self._model.generate_course_problems(context, count)
        if len(prompts) != count:
            raise RuntimeError("The model returned the wrong number of problems.")
        sources = _references(context)
        return [GeneratedCourseProblem(prompt=prompt.strip(), sources=sources) for prompt in prompts]


def _chunk_text(text: str, size: int = 220, overlap: int = 30) -> list[str]:
    words = text.split()
    if not words:
        return []
    chunks: list[str] = []
    start = 0
    while start < len(words):
        end = min(start + size, len(words))
        chunks.append(" ".join(words[start:end]))
        if end == len(words):
            break
        start = max(start + 1, end - overlap)
    return chunks


def _normalize_text(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _index_text(chunk: KnowledgeChunk) -> str:
    return f"{chunk.title}\n{chunk.section}\n{chunk.content}"


def _terms(text: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+", text.lower()))


def _lexical(query_terms: set[str], chunk: KnowledgeChunk) -> float:
    if not query_terms:
        return 0.0
    overlap = query_terms & _terms(_index_text(chunk))
    return len(overlap) / len(query_terms)


def _cosine(left: list[float], right: list[float]) -> float:
    if len(left) != len(right):
        raise ValueError("Embedding dimensions do not match")
    left_norm = math.sqrt(sum(value * value for value in left))
    right_norm = math.sqrt(sum(value * value for value in right))
    if left_norm == 0 or right_norm == 0:
        return 0.0
    return sum(a * b for a, b in zip(left, right, strict=True)) / (left_norm * right_norm)


def _references(chunks: list[KnowledgeChunk]) -> list[SourceReference]:
    references: list[SourceReference] = []
    seen: set[tuple[str, str]] = set()
    for chunk in chunks:
        key = (chunk.title, chunk.section)
        if key in seen:
            continue
        seen.add(key)
        references.append(
            SourceReference(source_id=chunk.source_id, title=chunk.title, section=chunk.section)
        )
    return references
