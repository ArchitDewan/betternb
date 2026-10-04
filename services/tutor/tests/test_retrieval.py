from betternb_tutor.knowledge import KnowledgeChunk, InMemoryKnowledgeRepository


class KeywordEmbeddingGateway:
    dimensions = 3

    def embed(self, texts: list[str]) -> list[list[float]]:
        vectors: list[list[float]] = []
        for text in texts:
            lowered = text.lower()
            vectors.append(
                [
                    float("chain" in lowered or "composite" in lowered),
                    float("product" in lowered),
                    float("quotient" in lowered),
                ]
            )
        return vectors


class SharedDerivativeEmbedding:
    """All derivative notes share a topic axis, so ranking cannot rely on top-k alone."""

    dimensions = 5

    def embed(self, texts: list[str]) -> list[list[float]]:
        vectors: list[list[float]] = []
        for text in texts:
            lowered = text.lower()
            compact = "".join(lowered.split())
            vectors.append(
                [
                    1.0,
                    float("power" in lowered or "x^n" in lowered or "x^2" in compact or "exponent" in lowered),
                    float("chain" in lowered or "composite" in lowered),
                    float("product" in lowered),
                    float("quotient" in lowered),
                ]
            )
        return vectors


def _rule_chunks() -> list[KnowledgeChunk]:
    return [
        KnowledgeChunk(
            source_id="calc.derivatives.power-rule.method",
            title="Power rule",
            section="Method",
            topic="derivatives",
            content="For a constant exponent n, the derivative of x^n is n times x^(n-1).",
        ),
        KnowledgeChunk(
            source_id="calc.derivatives.power-rule.example",
            title="Power rule",
            section="Example",
            topic="derivatives",
            content="If f(x) = 3x^4 - 2x + 7, then f'(x) = 12x^3 - 2.",
        ),
        KnowledgeChunk(
            source_id="calc.derivatives.chain-rule.method",
            title="Chain rule",
            section="Method",
            topic="derivatives",
            content="For a composite function, differentiate the outside, then multiply by the inner derivative.",
        ),
        KnowledgeChunk(
            source_id="calc.derivatives.quotient-rule.method",
            title="Quotient rule",
            section="Method",
            topic="derivatives",
            content="For a quotient of functions, use (u'v - uv') / v^2.",
        ),
        KnowledgeChunk(
            source_id="calc.derivatives.product-rule.method",
            title="Product rule",
            section="Method",
            topic="derivatives",
            content="For a product of functions, use u'v + uv'.",
        ),
    ]


def test_retrieval_returns_stable_source_metadata() -> None:
    chunks = [
        KnowledgeChunk(
            source_id="calc.derivatives.chain-rule",
            title="Chain rule",
            section="Method",
            topic="derivatives",
            content="For a composite function, use the chain rule.",
        ),
        KnowledgeChunk(
            source_id="calc.derivatives.product-rule",
            title="Product rule",
            section="Method",
            topic="derivatives",
            content="For a product of functions, use the product rule.",
        ),
    ]
    repository = InMemoryKnowledgeRepository(chunks, KeywordEmbeddingGateway())

    results = repository.search("Which rule handles a composite function?", limit=1)

    assert len(results) == 1
    assert results[0].chunk.source_id == "calc.derivatives.chain-rule"
    assert results[0].chunk.title == "Chain rule"
    assert results[0].score > 0


def test_simple_power_rule_problem_does_not_cite_unrelated_rules() -> None:
    repository = InMemoryKnowledgeRepository(_rule_chunks(), SharedDerivativeEmbedding())

    results = repository.search("Differentiate f(x) = x^2", limit=3)

    assert results
    assert {result.chunk.title for result in results} == {"Power rule"}
    assert all("chain" not in result.chunk.source_id for result in results)
    assert all("quotient" not in result.chunk.source_id for result in results)


class NearDuplicateDerivativeEmbedding:
    """Real embeddings often place every derivative rule close together."""

    dimensions = 2

    def embed(self, texts: list[str]) -> list[list[float]]:
        vectors: list[list[float]] = []
        for text in texts:
            lowered = text.lower()
            compact = "".join(lowered.split())
            power = float("power" in lowered or "x^2" in compact or "x^n" in lowered)
            vectors.append([1.0, 0.04 * power])
        return vectors


def test_near_duplicate_embeddings_still_keep_power_rule_citations_focused() -> None:
    repository = InMemoryKnowledgeRepository(_rule_chunks(), NearDuplicateDerivativeEmbedding())

    results = repository.search("Differentiate f(x) = x^2", limit=3)

    assert {result.chunk.title for result in results} == {"Power rule"}
