import pytest
from betternb_tutor.course_study import CourseSourceIndex, CourseStudyService
from test_course_ingestion import KeywordEmbeddings, StubStudyModel

class RoadmapModel(StubStudyModel):
    def generate_course_roadmap(self, context, primary_source_id):
        self.context = context
        return {"units": [{"title": "Calculus", "topics": [
            {"title": "Limits", "description": "Understand limits", "source_ids": [context[0].source_id]},
            {"title": "Integrals", "description": "Accumulate change", "source_ids": [context[-1].source_id]}
        ]}]}

    def generate_course_problems(self, context, count, topic=None):
        self.context, self.topic = context, topic
        return super().generate_course_problems(context, count)


def setup():
    index = CourseSourceIndex(KeywordEmbeddings())
    source = index.import_pages("a", "Text.pdf", b"pdf", "application/pdf", [f"Chapter {i} limits and integration" for i in range(100)])
    other = index.import_pages("a", "Other.pdf", b"other", "application/pdf", ["unrelated content"])
    model = RoadmapModel()
    return CourseStudyService(index, model), model, source, other


def test_roadmap_covers_end_of_document_and_validates_scope():
    service, model, source, other = setup()
    result = service.generate_roadmap("a", [source.source_id], source.source_id)
    assert result["units"][0]["topics"][1]["sources"][0]["section"] == "Page 100"
    assert all(c.title == "Text.pdf" for c in model.context)
    with pytest.raises(LookupError):
        service.generate_roadmap("b", [source.source_id], source.source_id)
    with pytest.raises(ValueError):
        service.generate_roadmap("a", [source.source_id], other.source_id)


def test_invalid_roadmap_citation_is_rejected():
    service, model, source, _ = setup()
    model.generate_course_roadmap = lambda *args: {"units": [{"title": "Unit", "topics": [{"title": "Topic", "description": "d", "source_ids": ["invented"]}]}]}
    with pytest.raises(RuntimeError):
        service.generate_roadmap("a", [source.source_id], source.source_id)


def test_topic_generation_filters_resources_and_passes_focus():
    service, model, source, _ = setup()
    problems = service.generate_problems("a", 3, topic="Limits", source_ids=[source.source_id])
    assert len(problems) == 3
    assert model.topic == "Limits"
    assert all(c.title == "Text.pdf" for c in model.context)
    with pytest.raises(LookupError):
        service.generate_problems("b", 3, topic="Limits", source_ids=[source.source_id])


def test_http_contracts_and_failure_do_not_write_source_data():
    from fastapi.testclient import TestClient
    from betternb_tutor.api import create_app
    from betternb_tutor.orchestrator import TutorOrchestrator
    from test_api import StubModel, StubKnowledgeRepository, StubVerifier
    service, model, source, other = setup()
    client = TestClient(create_app(TutorOrchestrator(StubModel(), StubKnowledgeRepository(), StubVerifier()), service))
    route = "/v1/courses/a/roadmaps"
    payload = {"source_ids": [source.source_id], "primary_source_id": source.source_id}
    response = client.post(route, json=payload)
    assert response.status_code == 200
    assert response.json()["units"][0]["topics"][0]["sources"]
    assert client.post(route, json={**payload, "primary_source_id": other.source_id}).status_code == 422
    assert client.post(route, json={**payload, "source_ids": []}).status_code == 422
    assert client.post("/v1/courses/b/roadmaps", json=payload).status_code == 409
    response = client.post("/v1/courses/a/problems", json={"count": 1, "topic": "Limits", "source_ids": [source.source_id]})
    assert response.status_code == 200
    assert model.topic == "Limits"
    assert client.post("/v1/courses/a/problems", json={"count": 1, "topic": "Limits"}).status_code == 422
    assert client.post("/v1/courses/a/flashcards", json={"source_ids": [source.source_id]}).status_code == 422
    model.generate_course_roadmap = lambda *args: {"units": []}
    assert client.post(route, json=payload).status_code == 502
    assert len(service.sources.list_sources("a")) == 2


def test_topic_flashcards_keep_the_requested_focus_and_citations():
    service, model, source, _ = setup()
    def generate(context, count, topic=None):
        assert topic == "Limits"
        assert all(c.title == "Text.pdf" for c in context)
        return StubStudyModel().generate_course_flashcards(context, count)
    model.generate_course_flashcards = generate
    cards = service.generate_flashcards("a", 5, topic="Limits", source_ids=[source.source_id])
    assert len(cards) == 5
    assert all(card.sources[0].title == "Text.pdf" for card in cards)


def test_provider_receives_primary_sequence_and_topic_focus():
    import json
    from types import SimpleNamespace
    from betternb_tutor.providers import OpenAIModelGateway
    from betternb_tutor.knowledge import KnowledgeChunk
    class Responses:
        def parse(self, **kwargs):
            self.request = kwargs
            if kwargs["text_format"].__name__ == "_RoadmapOutput":
                return SimpleNamespace(output_parsed=SimpleNamespace(model_dump=lambda: {"units": []}))
            return SimpleNamespace(output_parsed=SimpleNamespace(problems=["Find a limit."]))
    responses = Responses()
    provider = OpenAIModelGateway(SimpleNamespace(responses=responses))
    context = [KnowledgeChunk(source_id="s.p99", title="Book", section="Page 99", topic="course", content="Integration")]
    provider.generate_course_roadmap(context, "s")
    assert json.loads(responses.request["input"])["primary_source_id"] == "s"
    assert "Page 99" in responses.request["input"]
    assert "untrusted" in responses.request["instructions"]
    provider.generate_course_problems(context, 1, topic="Limits")
    assert json.loads(responses.request["input"])["topic_focus"] == "Limits"


def test_review_accepts_outline_and_many_lecture_files():
    from betternb_tutor.contracts import GenerateRoadmapRequest
    ids = [f"lecture-{i}" for i in range(20)]
    request = GenerateRoadmapRequest(source_ids=ids, primary_source_id=ids[0])
    assert request.source_ids == ids
    with pytest.raises(ValueError):
        GenerateRoadmapRequest(source_ids=ids + ["extra"], primary_source_id=ids[0])


def test_many_materials_keep_every_page_with_bounded_context():
    index = CourseSourceIndex(KeywordEmbeddings())
    sources = [index.import_pages("a", f"Lecture {i}.pdf", f"pdf{i}".encode(), "application/pdf",
                                  ["limits " * 500] * 30) for i in range(20)]
    model = RoadmapModel()
    CourseStudyService(index, model).generate_roadmap("a", [s.source_id for s in sources], sources[0].source_id)
    assert len(model.context) == 600
    assert len({chunk.title for chunk in model.context}) == 20
    assert sum(len(chunk.content) for chunk in model.context) <= 400_000
