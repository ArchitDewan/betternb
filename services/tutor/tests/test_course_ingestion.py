from betternb_tutor.course_study import CourseSourceIndex, CourseStudyService


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
    def answer_course_question(self, question, context):
        assert context
        return f"Grounded answer: {context[0].content}"

    def generate_course_problems(self, context, count):
        assert context
        return [f"Problem {index + 1} from {context[0].section}" for index in range(count)]


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
