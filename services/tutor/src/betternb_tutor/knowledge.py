import hashlib
import json
import math
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Protocol


@dataclass(frozen=True)
class KnowledgeChunk:
    source_id: str
    title: str
    section: str
    topic: str
    content: str


@dataclass(frozen=True)
class SearchResult:
    chunk: KnowledgeChunk
    score: float


class EmbeddingGateway(Protocol):
    dimensions: int

    def embed(self, texts: list[str]) -> list[list[float]]: ...


class KnowledgeRepository(Protocol):
    def search(self, query: str, limit: int = 3) -> list[SearchResult]: ...


class InMemoryKnowledgeRepository:
    def __init__(
        self,
        chunks: list[KnowledgeChunk],
        embeddings: EmbeddingGateway,
        vectors: list[list[float]] | None = None,
    ) -> None:
        self._chunks = chunks
        self._embeddings = embeddings
        self._vectors = vectors or embeddings.embed([_index_text(chunk) for chunk in chunks])
        if len(self._vectors) != len(self._chunks):
            raise ValueError("Every knowledge chunk requires one embedding vector")

    def search(self, query: str, limit: int = 3) -> list[SearchResult]:
        if limit < 1:
            return []
        query_vector = self._embeddings.embed([query])[0]
        query_terms = _terms(query)
        ranked = [
            SearchResult(
                chunk=chunk,
                score=_combined_score(
                    _cosine_similarity(query_vector, vector),
                    _lexical_score(query_terms, chunk),
                ),
            )
            for chunk, vector in zip(self._chunks, self._vectors, strict=True)
        ]
        ranked.sort(key=lambda result: (-result.score, result.chunk.source_id))
        return _select_results(ranked, limit, query)


def load_markdown_knowledge(directory: Path) -> list[KnowledgeChunk]:
    chunks: list[KnowledgeChunk] = []
    for path in sorted(directory.glob("*.md")):
        lines = path.read_text(encoding="utf-8").splitlines()
        if not lines or not lines[0].startswith("# "):
            raise ValueError(f"Knowledge file {path} needs a level-one title")
        title = lines[0][2:].strip()
        section = "Overview"
        body: list[str] = []

        def append_chunk() -> None:
            content = "\n".join(body).strip()
            if not content:
                return
            section_slug = _slug(section)
            chunks.append(
                KnowledgeChunk(
                    source_id=f"calc.derivatives.{path.stem}.{section_slug}",
                    title=title,
                    section=section,
                    topic="derivatives",
                    content=content,
                )
            )

        for line in lines[1:]:
            if line.startswith("## "):
                append_chunk()
                section = line[3:].strip()
                body = []
            else:
                body.append(line)
        append_chunk()
    if not chunks:
        raise ValueError(f"No knowledge chunks found in {directory}")
    return chunks


def load_or_build_repository(
    chunks: list[KnowledgeChunk],
    embeddings: EmbeddingGateway,
    cache_path: Path,
    cache_key: str,
) -> InMemoryKnowledgeRepository:
    digest_input = json.dumps([asdict(chunk) for chunk in chunks], sort_keys=True) + cache_key
    digest = hashlib.sha256(digest_input.encode()).hexdigest()
    vectors: list[list[float]] | None = None
    try:
        cached = json.loads(cache_path.read_text(encoding="utf-8"))
        if cached.get("digest") == digest:
            vectors = cached.get("vectors")
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        pass

    repository = InMemoryKnowledgeRepository(chunks, embeddings, vectors=vectors)
    if vectors is None:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(
            json.dumps({"digest": digest, "vectors": repository._vectors}),
            encoding="utf-8",
        )
    return repository


_TOKEN = re.compile(r"[a-z0-9]+")
_COMPOSITE_POWER = re.compile(r"\([^()]+\)\^")
_SIMPLE_POWER = re.compile(r"x\^-?\d")
_QUOTIENT_FORM = re.compile(r"/[a-z(]")
_TITLE_COMPETITION_FLOOR = 0.95


def _index_text(chunk: KnowledgeChunk) -> str:
    return f"{chunk.title}\n{chunk.section}\n{chunk.content}"


def _structural_cues(text: str) -> set[str]:
    lowered = text.lower()
    compact = re.sub(r"\s+", "", lowered)
    cues: set[str] = set()
    if "chain" in lowered or "composite" in lowered or _COMPOSITE_POWER.search(compact):
        cues.add("chain")
    if "product" in lowered:
        cues.add("product")
    if "quotient" in lowered or _QUOTIENT_FORM.search(compact):
        cues.add("quotient")
    if "power" in lowered or "x^n" in compact or _SIMPLE_POWER.search(compact):
        cues.add("power")
    return cues


def _terms(text: str) -> set[str]:
    return set(_TOKEN.findall(text.lower())) | _structural_cues(text)


def _lexical_score(query_terms: set[str], chunk: KnowledgeChunk) -> float:
    if not query_terms:
        return 0.0
    chunk_terms = _terms(_index_text(chunk))
    overlap = query_terms & chunk_terms
    if not overlap:
        return 0.0
    title_hits = len(overlap & _terms(chunk.title))
    return (len(overlap) + title_hits) / (len(query_terms) + 1)


def _combined_score(semantic: float, lexical: float) -> float:
    return (0.72 * semantic) + (0.28 * lexical)


def _select_results(ranked: list[SearchResult], limit: int, query: str) -> list[SearchResult]:
    eligible = [result for result in ranked if result.score > 0]
    if not eligible:
        return []
    top_score = eligible[0].score
    lead_title = eligible[0].chunk.title
    query_cues = _structural_cues(query)
    selected = [result for result in eligible if result.chunk.title == lead_title]
    for result in eligible:
        title_cues = _structural_cues(result.chunk.title)
        if (
            result.chunk.title != lead_title
            and title_cues
            and title_cues <= query_cues
            and result.score >= top_score * _TITLE_COMPETITION_FLOOR
        ):
            selected.append(result)
    selected.sort(key=lambda result: (-result.score, result.chunk.source_id))
    return selected[:limit]


def _cosine_similarity(left: list[float], right: list[float]) -> float:
    if len(left) != len(right):
        raise ValueError("Embedding dimensions do not match")
    left_norm = math.sqrt(sum(value * value for value in left))
    right_norm = math.sqrt(sum(value * value for value in right))
    if left_norm == 0 or right_norm == 0:
        return 0.0
    return sum(a * b for a, b in zip(left, right, strict=True)) / (left_norm * right_norm)


def _slug(value: str) -> str:
    return "-".join(part for part in "".join(character.lower() if character.isalnum() else " " for character in value).split())
