"""Exercise the live OpenAI provider for the F009A tutoring loop.

This is intentionally outside the default pytest path. It requires OPENAI_API_KEY
and makes several model calls.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

from fastapi.testclient import TestClient

from betternb_tutor.main import build_app

PROBLEM = "Differentiate f(x) = x^2"
SESSION_ID = "live-smoke-f009a"


def _require_key() -> None:
    if not os.environ.get("OPENAI_API_KEY") or "YOUR_" in os.environ.get("OPENAI_API_KEY", ""):
        raise SystemExit("Set OPENAI_API_KEY before running the live tutor smoke test.")


def _turn(client: TestClient, **payload: object) -> dict:
    response = client.post("/v1/tutor/turns", json=payload)
    response.raise_for_status()
    return response.json()


def _write_problem_image(path: Path) -> None:
    script = path.with_suffix(".swift")
    script.write_text(
        """
import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let text = "Differentiate f(x) = x^2"
let size = NSSize(width: 720, height: 160)
let image = NSImage(size: size)
image.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 32, weight: .medium),
    .foregroundColor: NSColor.black,
]
text.draw(at: NSPoint(x: 28, y: 58), withAttributes: attributes)
image.unlockFocus()
guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("Failed to render PNG\\n".utf8))
    exit(1)
}
try png.write(to: output)
""",
        encoding="utf-8",
    )
    completed = subprocess.run(
        ["swift", script.as_posix(), path.as_posix()],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0 or not path.exists():
        raise RuntimeError(completed.stderr or completed.stdout or "Swift image render failed")


def run() -> None:
    _require_key()
    client = TestClient(build_app())
    assert client.get("/healthz").text == "ok\n"

    checked = _turn(
        client,
        session_id=SESSION_ID,
        problem=PROBLEM,
        attempt_steps=["f'(x) = 2*x"],
        action="check_step",
        hint_level=0,
        solution_revealed=False,
    )
    source_titles = {source["title"] for source in checked["sources"]}
    print(f"checked_step status={checked['verification_status']} assessment={checked['assessment']} sources={source_titles}")
    if source_titles - {"Power rule"}:
        raise SystemExit(f"Power-rule problem cited unrelated material: {source_titles}")

    for level in (1, 2, 3):
        hint = _turn(
            client,
            session_id=SESSION_ID,
            problem=PROBLEM,
            attempt_steps=["f'(x) = 2*x"],
            action="request_hint",
            hint_level=level,
            solution_revealed=False,
        )
        print(f"hint_{level} accepted={hint['action_accepted']} next={hint['next_hint_level']} latex={'\\\\' in hint['message']}")
        if not hint["action_accepted"]:
            raise SystemExit(f"Hint {level} was rejected: {hint['message']}")

    skipped = client.post(
        "/v1/tutor/turns",
        json={
            "session_id": SESSION_ID,
            "problem": PROBLEM,
            "attempt_steps": ["f'(x) = 2*x"],
            "action": "request_hint",
            "hint_level": 0,
            "solution_revealed": False,
        },
    )
    if skipped.status_code < 400:
        raise SystemExit("Invalid hint request should fail so the student draft can stay local")
    print(f"invalid_hint_rejected status={skipped.status_code}")

    recovered = _turn(
        client,
        session_id=SESSION_ID,
        problem=PROBLEM,
        attempt_steps=["f'(x) = 2*x"],
        action="check_step",
        hint_level=0,
        solution_revealed=False,
    )
    print(f"recovered_step status={recovered['verification_status']}")

    revealed = _turn(
        client,
        session_id=SESSION_ID,
        problem=PROBLEM,
        attempt_steps=["f'(x) = 2*x"],
        action="reveal_solution",
        hint_level=3,
        solution_revealed=True,
    )
    print(f"reveal next_action={revealed['next_action']} boxed={'\\boxed' in revealed['message'] or 'boxed' in revealed['message'].lower()}")
    if revealed["next_action"] != "continue_practice":
        raise SystemExit("Reveal did not close the hint/reveal loop")

    with tempfile.TemporaryDirectory() as directory:
        image_path = Path(directory) / "problem.png"
        _write_problem_image(image_path)
        transcribed = client.post(
            "/v1/math/transcriptions",
            files={"image": ("problem.png", image_path.read_bytes(), "image/png")},
        )
        transcribed.raise_for_status()
        text = transcribed.json()["transcription"]
        print(f"transcription={text!r} requires_confirmation={transcribed.json()['requires_confirmation']}")
        if "x^2" not in text.replace(" ", "") and "x^{2}" not in text.replace(" ", ""):
            raise SystemExit(f"Transcription missed the power-rule problem: {text!r}")

    print("live smoke passed")


if __name__ == "__main__":
    try:
        run()
    except Exception as error:  # noqa: BLE001
        print(f"live smoke failed: {error}", file=sys.stderr)
        raise
