from betternb_tutor.course_study import CourseSourceIndex, CourseStudyService, QuizQuestion, _sample_chunks
from betternb_tutor.knowledge import KnowledgeChunk
from betternb_tutor.providers import OpenAIModelGateway
from types import SimpleNamespace


class KeywordEmbeddings:
    dimensions = 4

    def embed(self, texts: list[str]) -> list[list[float]]:
        return [
            [
                float("chain" in text.lower()),
                float("product" in text.lower()),
                float("limit" in text.lower()),
                1.0,
            ]
            for text in texts
        ]


class StubStudyModel:
    def answer_course_question(self, question, context, image=None):
        assert context
        self.last_image = image
        return f"Grounded answer: {context[0].content}"

    def generate_course_problems(self, context, count):
        assert context
        return [f"Problem {index + 1} from {context[0].section}" for index in range(count)]

    def generate_course_quiz(self, context, count, difficulty):
        assert context
        assert difficulty == "standard"
        return [QuizQuestion(f"Question {index + 1}?", ["A", "B", "C", "D"], 1, "B is correct.")
                for index in range(count)]

    def generate_course_flashcards(self, context, count):
        assert context
        return [
            {"front": f"What is idea {index + 1}?", "back": "The product rule.",
             "source_id": context[0].source_id}
            for index in range(count)
        ]


def _single_page_pdf(text: str) -> bytes:
    content = f"BT /F1 12 Tf 72 720 Td ({text}) Tj ET".encode("latin-1")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Length " + str(len(content)).encode() + b" >>\nstream\n" + content + b"\nendstream",
    ]
    result = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for index, obj in enumerate(objects, start=1):
        offsets.append(len(result))
        result.extend(f"{index} 0 obj\n".encode())
        result.extend(obj)
        result.extend(b"\nendobj\n")
    xref = len(result)
    result.extend(f"xref\n0 {len(objects) + 1}\n".encode())
    result.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        result.extend(f"{offset:010d} 00000 n \n".encode())
    result.extend(
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    )
    return bytes(result)


def test_pdf_import_extracts_page_aware_chunks_and_isolates_courses() -> None:
    index = CourseSourceIndex(KeywordEmbeddings())

    source = index.import_pdf(
        "calculus-1",
        "Lecture 4.pdf",
        _single_page_pdf("The chain rule differentiates composite functions."),
    )
    index.import_pdf(
        "linear-algebra",
        "Vectors.pdf",
        _single_page_pdf("A basis is a linearly independent spanning set."),
    )

    results = index.search("calculus-1", "How does the chain rule work?")

    assert source.filename == "Lecture 4.pdf"
    assert source.page_count == 1
    assert source.chunk_count == 1
    assert len(results) == 1
    assert results[0].chunk.title == "Lecture 4.pdf"
    assert results[0].chunk.section == "Page 1"
    assert "basis" not in results[0].chunk.content


def test_original_pdf_is_available_only_to_its_course() -> None:
    index = CourseSourceIndex(KeywordEmbeddings())
    pdf = _single_page_pdf("The chain rule differentiates composite functions.")
    source = index.import_pdf("calculus-1", "Lecture 4.pdf", pdf)

    assert index.get_document("calculus-1", source.source_id) == pdf
    assert index.get_document("linear-algebra", source.source_id) is None
    assert index.get_document("calculus-1", "missing") is None


def test_scanned_or_empty_pdf_has_an_actionable_failure() -> None:
    index = CourseSourceIndex(KeywordEmbeddings())

    try:
        index.import_pdf("calculus-1", "scan.pdf", _single_page_pdf(""))
    except ValueError as error:
        assert "text" in str(error).lower()
        assert "ocr" in str(error).lower()
    else:
        raise AssertionError("An empty PDF should require OCR")


def test_grounded_answers_and_generated_problems_keep_page_citations() -> None:
    index = CourseSourceIndex(KeywordEmbeddings())
    index.import_pdf(
        "calculus-1",
        "Lecture 4.pdf",
        _single_page_pdf("The product rule is u prime v plus u v prime."),
    )
    service = CourseStudyService(index, StubStudyModel())

    answer = service.answer("calculus-1", "What is the product rule?")
    generated = service.generate_problems("calculus-1", count=2)

    assert answer.text.startswith("Grounded answer")
    assert answer.sources[0].title == "Lecture 4.pdf"
    assert answer.sources[0].section == "Page 1"
    assert [item.prompt for item in generated] == ["Problem 1 from Page 1", "Problem 2 from Page 1"]
    assert all(item.sources[0].section == "Page 1" for item in generated)


def test_image_only_question_receives_course_context() -> None:
    index = CourseSourceIndex(KeywordEmbeddings())
    index.import_pdf("calculus-1", "Lecture.pdf", _single_page_pdf("The chain rule differentiates functions."))
    model = StubStudyModel()
    service = CourseStudyService(index, model)
    image = (b"\x89PNG\r\n\x1a\nexample", "image/png")

    answer = service.answer("calculus-1", "What is in this image?", image=image)

    assert model.last_image == image
    assert answer.sources[0].title == "Lecture.pdf"


def test_course_model_sends_the_image_with_retrieved_excerpts() -> None:
    class Responses:
        request = None

        def parse(self, **kwargs):
            self.request = kwargs
            return SimpleNamespace(output_parsed=SimpleNamespace(answer="The diagram shows a derivative."))

    responses = Responses()
    model = OpenAIModelGateway(SimpleNamespace(responses=responses))
    chunk = KnowledgeChunk("source-1", "Lecture.pdf", "Page 3", "calculus-1", "The chain rule.")

    answer = model.answer_course_question("Explain this", [chunk], image=(b"png", "image/png"))

    assert answer == "The diagram shows a derivative."
    content = responses.request["input"][0]["content"]
    assert "The chain rule." in content[0]["text"]
    assert content[1]["image_url"].startswith("data:image/png;base64,")


def test_generated_quiz_respects_length_and_has_answer_keys() -> None:
    index = CourseSourceIndex(KeywordEmbeddings())
    index.import_pdf("calculus-1", "Lecture.pdf", _single_page_pdf("The chain rule differentiates functions."))

    questions, sources = CourseStudyService(index, StubStudyModel()).generate_quiz(
        "calculus-1", count=3, difficulty="standard"
    )

    assert len(questions) == 3
    assert questions[0].correct_index == 1
    assert sources[0].title == "Lecture.pdf"


def test_generated_quiz_uses_the_selected_pdf() -> None:
    index = CourseSourceIndex(KeywordEmbeddings())
    first = index.import_pdf("calculus-1", "First.pdf", _single_page_pdf("The chain rule differentiates functions."))
    second = index.import_pdf("calculus-1", "Second.pdf", _single_page_pdf("The product rule differentiates products."))

    _, sources = CourseStudyService(index, StubStudyModel()).generate_quiz(
        "calculus-1", count=3, difficulty="standard", source_id=second.source_id
    )

    assert first.source_id != second.source_id
    assert [source.title for source in sources] == ["Second.pdf"]


def test_generated_quiz_rejects_an_invalid_answer_key() -> None:
    class InvalidQuizModel(StubStudyModel):
        def generate_course_quiz(self, context, count, difficulty):
            return [QuizQuestion("Question?", ["A", "B", "C", "D"], 4, "Because.")]

    index = CourseSourceIndex(KeywordEmbeddings())
    index.import_pdf("calculus-1", "Lecture.pdf", _single_page_pdf("The chain rule differentiates functions."))

    try:
        CourseStudyService(index, InvalidQuizModel()).generate_quiz("calculus-1", 3, "easy")
    except RuntimeError as error:
        assert "incomplete quiz" in str(error)
    else:
        raise AssertionError("An invalid answer key must not reach the student")


def test_course_model_receives_quiz_difficulty_and_source_context() -> None:
    class Responses:
        request = None

        def parse(self, **kwargs):
            self.request = kwargs
            question = SimpleNamespace(model_dump=lambda: {
                "prompt": "What is the chain rule?",
                "options": ["A", "B", "C", "D"],
                "correct_index": 1,
                "explanation": "Because B.",
            })
            return SimpleNamespace(output_parsed=SimpleNamespace(questions=[question]))

    responses = Responses()
    model = OpenAIModelGateway(SimpleNamespace(responses=responses))
    chunk = KnowledgeChunk("source-1", "Lecture.pdf", "Page 1", "calculus-1", "The chain rule.")

    questions = model.generate_course_quiz([chunk], 1, "challenging")

    assert questions[0].correct_index == 1
    assert '"difficulty": "challenging"' in responses.request["input"]
    assert "The chain rule." in responses.request["input"]


def test_flashcards_are_scoped_to_the_selected_pdf_and_cited() -> None:
    index = CourseSourceIndex(KeywordEmbeddings())
    selected = index.import_pdf("calculus-1", "Product.pdf", _single_page_pdf("The product rule differentiates products."))
    index.import_pdf("calculus-1", "Limits.pdf", _single_page_pdf("A limit describes nearby values."))
    service = CourseStudyService(index, StubStudyModel())

    cards = service.generate_flashcards("calculus-1", count=2, source_id=selected.source_id)

    assert len(cards) == 2
    assert all(card.front and card.back for card in cards)
    assert all(card.sources[0].title == "Product.pdf" for card in cards)
    assert all(card.sources[0].section == "Page 1" for card in cards)


def test_flashcards_reject_unknown_source_and_bad_model_card() -> None:
    import pytest

    index = CourseSourceIndex(KeywordEmbeddings())
    index.import_pdf("calculus-1", "Product.pdf", _single_page_pdf("The product rule differentiates products."))
    service = CourseStudyService(index, StubStudyModel())
    with pytest.raises(LookupError, match="source"):
        service.generate_flashcards("calculus-1", count=1, source_id="missing")

    class BadModel(StubStudyModel):
        def generate_course_flashcards(self, context, count):
            return [{"front": "Question", "back": " ", "source_id": "invented"}]

    with pytest.raises(RuntimeError, match="flashcard"):
        CourseStudyService(index, BadModel()).generate_flashcards("calculus-1", count=1)


def test_flashcard_model_uses_source_ids_from_excerpts() -> None:
    class Responses:
        request = None

        def parse(self, **kwargs):
            self.request = kwargs
            card = SimpleNamespace(model_dump=lambda: {
                "front": "What is the product rule?", "back": "Differentiate both factors.",
                "source_id": "source-1"})
            return SimpleNamespace(output_parsed=SimpleNamespace(cards=[card]))

    responses = Responses()
    model = OpenAIModelGateway(SimpleNamespace(responses=responses))
    chunk = KnowledgeChunk("source-1", "Lecture.pdf", "Page 3", "calculus-1", "The product rule.")

    cards = model.generate_course_flashcards([chunk], 1)

    assert cards[0]["source_id"] == "source-1"
    assert '"source_id": "source-1"' in responses.request["input"]


def test_flashcard_context_spans_a_long_source() -> None:
    chunks = [KnowledgeChunk(f"chunk-{index}", "Book.pdf", f"Page {index}", "course", "Text")
              for index in range(40)]

    sampled = _sample_chunks(chunks, 12)

    assert len(sampled) == 12
    assert sampled[0].source_id == "chunk-0"
    assert sampled[-1].source_id == "chunk-39"
