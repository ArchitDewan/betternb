import hashlib
import json
import math
import os
import re
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path
from typing import Protocol

from pypdf import PdfReader
import pypdfium2 as pdfium

from .contracts import SourceReference
from .knowledge import EmbeddingGateway, KnowledgeChunk, SearchResult


@dataclass(frozen=True)
class CourseSource:
    source_id: str
    filename: str
    page_count: int
    chunk_count: int
    media_type: str = "application/pdf"
    unreadable_pages: list[int] = field(default_factory=list)


@dataclass(frozen=True)
class GroundedAnswer:
    text: str
    sources: list[SourceReference]


@dataclass(frozen=True)
class GeneratedCourseProblem:
    prompt: str
    sources: list[SourceReference]


@dataclass(frozen=True)
class QuizQuestion:
    prompt: str
    options: list[str]
    correct_index: int
    explanation: str


@dataclass(frozen=True)
class GeneratedCourseFlashcard:
    front: str
    back: str
    sources: list[SourceReference]


@dataclass(frozen=True)
class SummaryIdea:
    heading: str
    explanation: str
    sources: list[SourceReference]


@dataclass(frozen=True)
class GeneratedCourseSummary:
    overview: str
    ideas: list[SummaryIdea]


class CourseStudyModel(Protocol):
    def answer_course_question(
        self, question: str, context: list[KnowledgeChunk], image: tuple[bytes, str] | None = None
    ) -> str: ...

    def generate_course_problems(self, context: list[KnowledgeChunk], count: int, topic: str | None = None) -> list[str]: ...

    def transcribe_worksheet_page(self, data: bytes, media_type: str) -> str: ...

    def extract_worksheet_questions(self, page_text: str) -> list[str]: ...

    def generate_course_quiz(
        self, context: list[KnowledgeChunk], count: int, difficulty: str
    ) -> list[QuizQuestion]: ...

    def generate_course_flashcards(self, context: list[KnowledgeChunk], count: int, topic: str | None = None) -> list[dict[str, str]]: ...

    def generate_course_roadmap(self, context: list[KnowledgeChunk], primary_source_id: str) -> dict: ...

    def summarize_course_source(self, context: list[KnowledgeChunk]) -> dict: ...


class CourseSourceIndex:
    def __init__(self, embeddings: EmbeddingGateway, storage_dir: Path | None = None) -> None:
        self._embeddings = embeddings
        self._storage_dir = storage_dir
        self._sources: dict[str, dict[str, CourseSource]] = {}
        self._documents: dict[str, dict[str, bytes]] = {}
        self._page_texts: dict[str, dict[str, list[str]]] = {}
        self._chunks: dict[str, list[KnowledgeChunk]] = {}
        self._vectors: dict[str, list[list[float]]] = {}
        if storage_dir is not None and storage_dir.exists():
            for metadata_file in storage_dir.glob("*.json"):
                metadata = json.loads(metadata_file.read_text())
                document_file = metadata_file.with_suffix(".bin")
                if document_file.exists():
                    self.import_pages(
                        metadata["course_id"], metadata["filename"], document_file.read_bytes(),
                        metadata["media_type"], metadata["pages"],
                        unreadable_pages=metadata.get("unreadable_pages", []), persist=False,
                    )

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

        pages: list[str] = []
        for page_index, page in enumerate(reader.pages, start=1):
            try:
                text = _normalize_text(page.extract_text() or "")
            except Exception as error:
                raise ValueError(f"Text could not be extracted from page {page_index}.") from error
            pages.append(text)
        if not any(pages):
            raise ValueError("No readable text was found. Scanned PDFs need OCR, which is not supported yet.")
        return self.import_pages(course_id, safe_filename, data, "application/pdf", pages)

    def import_pages(
        self, course_id: str, filename: str, data: bytes, media_type: str,
        pages: list[str], *, unreadable_pages: list[int] | None = None,
        persist: bool = True,
    ) -> CourseSource:
        safe_filename = Path(filename).name.strip()
        if not safe_filename or not pages or not any(page.strip() for page in pages):
            raise ValueError("No readable questions were found in the worksheet.")
        source_id = "course." + hashlib.sha256(
            course_id.encode() + b"\0" + safe_filename.encode() + b"\0" + data
        ).hexdigest()[:20]
        chunks: list[KnowledgeChunk] = []
        for page_index, text in enumerate(pages, start=1):
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
        source = CourseSource(
            source_id=source_id,
            filename=safe_filename,
            page_count=len(pages),
            chunk_count=len(chunks),
            media_type=media_type,
            unreadable_pages=unreadable_pages or [],
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
        self._documents.setdefault(course_id, {})[source_id] = data
        self._page_texts.setdefault(course_id, {})[source_id] = pages
        if persist and self._storage_dir is not None:
            self._storage_dir.mkdir(parents=True, exist_ok=True)
            stem = hashlib.sha256((course_id + ":" + source_id).encode()).hexdigest()
            document_file = self._storage_dir / f"{stem}.bin"
            metadata_file = self._storage_dir / f"{stem}.json"
            temporary_document = document_file.with_suffix(".bin.tmp")
            temporary_metadata = metadata_file.with_suffix(".json.tmp")
            temporary_document.write_bytes(data)
            temporary_metadata.write_text(json.dumps({
                "course_id": course_id, "filename": safe_filename,
                "media_type": media_type, "pages": pages,
                "unreadable_pages": unreadable_pages or [],
            }))
            os.replace(temporary_document, document_file)
            os.replace(temporary_metadata, metadata_file)
        return source

    def list_sources(self, course_id: str) -> list[CourseSource]:
        return sorted(self._sources.get(course_id, {}).values(), key=lambda source: source.filename.lower())

    def get_document(self, course_id: str, source_id: str) -> bytes | None:
        return self._documents.get(course_id, {}).get(source_id)

    def source(self, course_id: str, source_id: str) -> CourseSource | None:
        return self._sources.get(course_id, {}).get(source_id)

    def pages_for_source(self, course_id: str, source_id: str) -> list[tuple[int, str]]:
        pages = self._page_texts.get(course_id, {}).get(source_id, [])
        return list(enumerate(pages, start=1))

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

    def sample_chunks(self, course_id: str, limit: int = 12) -> list[KnowledgeChunk]:
        return _sample_chunks(self._chunks.get(course_id, []), limit)

    def chunks_for_source(self, course_id: str, source_id: str, limit: int = 12) -> list[KnowledgeChunk]:
        if source_id not in self._sources.get(course_id, {}):
            return []
        candidates = [chunk for chunk in self._chunks.get(course_id, [])
                      if chunk.source_id.startswith(f"{source_id}.")]
        return _sample_chunks(candidates, limit)


class CourseStudyService:
    def __init__(self, sources: CourseSourceIndex, model: CourseStudyModel) -> None:
        self.sources = sources
        self._model = model

    def generate_roadmap(self, course_id: str, source_ids: list[str], primary_source_id: str) -> dict:
        if primary_source_id not in source_ids:
            raise ValueError("Choose the primary source from the selected resources.")
        context = []
        unique_ids = sorted(set(source_ids), key=lambda value: (value != primary_source_id, value))
        for source_id in unique_ids:
            source = self.sources.source(course_id, source_id)
            if source is None:
                raise LookupError("A selected resource is not available in this notebook.")
            pages = self.sources.pages_for_source(course_id, source_id)
            for page, text in pages:
                if text.strip():
                    # Preserve a structural excerpt from every page, including late chapters.
                    budget = 2400 if len(pages) <= 30 else (1800 if page <= 8 else 500)
                    # Bound the combined input when a course has many lecture files.
                    budget = min(budget, 400_000 // len(unique_ids) // len(pages))
                    context.append(KnowledgeChunk(source_id=f"{source_id}.p{page}",
                        title=source.filename, section=f"Page {page}", topic=course_id,
                        content=text[:budget]))
        if not context:
            raise LookupError("The selected resources have no readable content.")
        draft = self._model.generate_course_roadmap(context, primary_source_id)
        references = {c.source_id: c for c in context}
        units = draft.get("units") if isinstance(draft, dict) else None
        if not isinstance(units, list) or not 1 <= len(units) <= 40:
            raise RuntimeError("The model returned an invalid roadmap.")
        result = []
        for unit in units:
            if not isinstance(unit, dict) or not isinstance(unit.get("title"), str) or not unit["title"].strip():
                raise RuntimeError("The model returned an invalid unit.")
            topics = unit.get("topics")
            if not isinstance(topics, list) or not 1 <= len(topics) <= 40:
                raise RuntimeError("The model returned an empty or oversized unit.")
            validated = []
            for topic in topics:
                if not isinstance(topic, dict) or any(not isinstance(topic.get(k), str) or not topic[k].strip() for k in ("title", "description")):
                    raise RuntimeError("The model returned an invalid topic.")
                ids = topic.get("source_ids")
                if not isinstance(ids, list) or not ids or any(not isinstance(i, str) or i not in references for i in ids):
                    raise RuntimeError("The model returned an invalid roadmap citation.")
                validated.append(dict(title=topic["title"].strip(), description=topic["description"].strip(),
                    sources=[ref.model_dump() for ref in _references([references[i] for i in ids])]))
            result.append(dict(title=unit["title"].strip(), topics=validated))
        return {"units": result}

    def topic_context(self, course_id: str, topic: str, source_ids: list[str] | None) -> list[KnowledgeChunk]:
        if not source_ids or any(self.sources.source(course_id, sid) is None for sid in source_ids):
            raise LookupError("Choose readable resources from this notebook for the topic.")
        # Search all course chunks, then filter before limiting so unrelated files cannot crowd out matches.
        results = self.sources.search(course_id, topic, limit=100000)
        context = [r.chunk for r in results if any(r.chunk.source_id.startswith(sid + ".") for sid in source_ids)][:12]
        if not context:
            raise LookupError("No readable material was found for this topic in the selected resources.")
        return context

    def answer(self, course_id: str, question: str, image: tuple[bytes, str] | None = None) -> GroundedAnswer:
        results = self.sources.search(course_id, question, limit=5)
        context = [result.chunk for result in results]
        if not context and image is not None:
            context = self.sources.all_chunks(course_id, limit=5)
        if not context:
            raise LookupError("Add a readable course source before asking a grounded question.")
        return GroundedAnswer(
            text=self._model.answer_course_question(question, context, image=image),
            sources=_references(context),
        )

    def import_worksheet(self, course_id: str, filename: str, data: bytes, media_type: str) -> CourseSource:
        if media_type == "application/pdf":
            try:
                reader = PdfReader(BytesIO(data), strict=False)
            except Exception as error:
                raise ValueError("The PDF could not be read.") from error
            if reader.is_encrypted:
                raise ValueError("Password-protected PDFs are not supported.")
            if not 1 <= len(reader.pages) <= 30:
                raise ValueError("Choose a worksheet with 30 pages or fewer.")
            pages = []
            unreadable_pages = []
            document = pdfium.PdfDocument(data)
            for page_index, page in enumerate(reader.pages):
                text = _normalize_text(page.extract_text() or "")
                image = document[page_index].render(scale=2).to_pil()
                output = BytesIO()
                image.save(output, format="PNG")
                visual_text = self._model.transcribe_worksheet_page(output.getvalue(), "image/png").strip()
                if visual_text:
                    text = visual_text
                if not text:
                    unreadable_pages.append(page_index + 1)
                pages.append(text)
        elif media_type in {"image/png", "image/jpeg"}:
            pages = [self._model.transcribe_worksheet_page(data, media_type).strip()]
            unreadable_pages = [1] if not pages[0] else []
        else:
            raise ValueError("Choose a PDF, PNG, or JPEG worksheet.")
        return self.sources.import_pages(course_id, filename, data, media_type, pages,
                                         unreadable_pages=unreadable_pages)

    def extract_problems(self, course_id: str, source_id: str) -> list[GeneratedCourseProblem]:
        source = self.sources.source(course_id, source_id)
        if source is None:
            raise LookupError("Worksheet not found in this course.")
        result: list[GeneratedCourseProblem] = []
        for page, text in self.sources.pages_for_source(course_id, source_id):
            for prompt in self._model.extract_worksheet_questions(text):
                trimmed = prompt.strip()
                if trimmed:
                    result.append(GeneratedCourseProblem(trimmed, [SourceReference(
                        source_id=f"{source_id}.p{page}", title=source.filename, section=f"Page {page}",
                    )]))
        return result

    def generate_problems(self, course_id: str, count: int = 3, source_id: str | None = None, *, topic: str | None = None, source_ids: list[str] | None = None) -> list[GeneratedCourseProblem]:
        context = (self.sources.chunks_for_source(course_id, source_id, limit=12)
                   if source_id else self.sources.all_chunks(course_id))
        if not context:
            raise LookupError("Add a readable course source before generating problems.")
        if topic is not None:
            context = self.topic_context(course_id, topic, source_ids)
        prompts = (self._model.generate_course_problems(context, count, topic=topic) if topic is not None
                   else self._model.generate_course_problems(context, count))
        if len(prompts) != count:
            raise RuntimeError("The model returned the wrong number of problems.")
        sources = _references(context)
        return [GeneratedCourseProblem(prompt=prompt.strip(), sources=sources) for prompt in prompts]

    def generate_quiz(
        self, course_id: str, count: int, difficulty: str, source_id: str | None = None
    ) -> tuple[list[QuizQuestion], list[SourceReference]]:
        context = (self.sources.chunks_for_source(course_id, source_id, limit=10)
                   if source_id else self.sources.all_chunks(course_id, limit=10))
        if not context:
            raise LookupError("Add a readable course source before generating a quiz.")
        questions = self._model.generate_course_quiz(context, count, difficulty)
        if len(questions) != count or any(
            not question.prompt.strip()
            or len(question.options) != 4
            or len({option.strip() for option in question.options}) != 4
            or any(not option.strip() for option in question.options)
            or not 0 <= question.correct_index < 4
            or not question.explanation.strip()
            for question in questions
        ):
            raise RuntimeError("The model returned an incomplete quiz.")
        return questions, _references(context)

    def generate_flashcards(
        self, course_id: str, count: int = 5, source_id: str | None = None, *, topic: str | None = None, source_ids: list[str] | None = None
    ) -> list[GeneratedCourseFlashcard]:
        context = (self.sources.chunks_for_source(course_id, source_id)
                   if source_id else self.sources.sample_chunks(course_id))
        if not context:
            raise LookupError("Add a readable course source or choose an available source before generating flashcards.")
        if topic is not None:
            context = self.topic_context(course_id, topic, source_ids)
        drafts = (self._model.generate_course_flashcards(context, count, topic=topic) if topic is not None
                  else self._model.generate_course_flashcards(context, count))
        if len(drafts) != count:
            raise RuntimeError("The model returned the wrong number of flashcards.")
        chunks_by_id = {chunk.source_id: chunk for chunk in context}
        cards: list[GeneratedCourseFlashcard] = []
        seen_fronts: set[str] = set()
        for draft in drafts:
            if not isinstance(draft, dict):
                raise RuntimeError("The model returned an invalid flashcard.")
            front, back = draft.get("front", "").strip(), draft.get("back", "").strip()
            chunk = chunks_by_id.get(draft.get("source_id"))
            if not front or not back or chunk is None:
                raise RuntimeError("The model returned an invalid flashcard or citation.")
            if front.casefold() in seen_fronts:
                raise RuntimeError("The model returned a duplicate flashcard.")
            seen_fronts.add(front.casefold())
            cards.append(GeneratedCourseFlashcard(front=front, back=back, sources=_references([chunk])))
        return cards

    def summarize(self, course_id: str, source_id: str) -> GeneratedCourseSummary:
        context = self.sources.chunks_for_source(course_id, source_id, limit=12)
        if not context:
            raise LookupError("Choose a readable course source to summarize.")
        draft = self._model.summarize_course_source(context)
        if not isinstance(draft, dict) or not isinstance(draft.get("ideas"), list):
            raise RuntimeError("The model returned an incomplete summary.")
        overview = draft.get("overview", "").strip()
        if not overview or not 1 <= len(draft["ideas"]) <= 6:
            raise RuntimeError("The model returned an incomplete summary.")
        chunks_by_id = {chunk.source_id: chunk for chunk in context}
        ideas: list[SummaryIdea] = []
        for item in draft["ideas"]:
            if not isinstance(item, dict):
                raise RuntimeError("The model returned an invalid key idea.")
            heading = item.get("heading", "").strip()
            explanation = item.get("explanation", "").strip()
            chunk = chunks_by_id.get(item.get("source_id"))
            if not heading or not explanation or chunk is None:
                raise RuntimeError("The model returned an invalid key idea or citation.")
            ideas.append(SummaryIdea(heading, explanation, _references([chunk])))
        return GeneratedCourseSummary(overview, ideas)


def _sample_chunks(chunks: list[KnowledgeChunk], limit: int) -> list[KnowledgeChunk]:
    if limit < 1:
        return []
    if len(chunks) <= limit:
        return chunks
    if limit == 1:
        return [chunks[0]]
    return [chunks[round(index * (len(chunks) - 1) / (limit - 1))] for index in range(limit)]


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
