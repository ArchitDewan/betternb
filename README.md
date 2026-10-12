<div align="center">

# Lemma

A study workspace for Mac, built around your courses.

**SwiftUI · macOS 14+ · In development**

[Run locally](#run-locally) · [How it works](#how-it-works) · [Development notes](docs/DEVELOPMENT.md)

</div>

---

I'm building Lemma to keep course material, worked problems, and revision in one place. The idea is straightforward: bring in your notes, try a problem, and get help with the step you're stuck on.

The app is called **Lemma**. The repository and some internal names still use **BetterNB**.

## What's here

- **Course notebooks** for keeping each subject's material and study sessions together.
- **A textbook workspace** with PDF reading, questions, summaries, quizzes, and flashcards.
- **Guided practice** with numbered steps, feedback, and hints you can ask for as you work.
- **Course review** generated from uploaded material, with topics linked back to sources.

This is an early prototype, starting with university mathematics. The **Problems** screen is currently marked “In progress” while it's being reworked. Cross-device sync and a complete offline workflow aren't ready yet. There isn't a packaged public release.

## Run locally

You'll need **macOS 14 or later**, **Xcode with Swift 6**, **Python 3.13+**, [uv](https://docs.astral.sh/uv/getting-started/installation/), and an OpenAI API key.

```sh
git clone https://github.com/ArchitDewan/betternb.git
cd betternb
cp .env.example .env.local
```

Set `OPENAI_API_KEY` in `.env.local`, then run:

```sh
./scripts/run-dev.sh --local-account
```

This starts the tutoring service, builds the Mac app, and opens it with a local development account. It skips Auth0 and PostgreSQL. `.env.local` is ignored by Git; keep your key there, not in source files.

For the full sign-in flow, you'll also need **Go 1.26**, **Docker**, and an **Auth0 native application**. Follow [the authentication setup](docs/AUTHENTICATION.md), then run `./scripts/run-dev.sh` without the flag.

## How it works

The interface is a native SwiftUI app. A Python service handles course material and tutoring; a Go API handles accounts with Auth0 and PostgreSQL.

| Directory | Purpose |
| --- | --- |
| `macos/` | Mac app, workspace state, and Swift tests |
| `services/tutor/` | FastAPI service, model calls, retrieval, and math checks |
| `internal/account/` | Account API and database migrations |
| `internal/web/` | Earlier website and browser prototypes |
| `docs/` | Product direction, architecture, and setup |

Tutoring uses cloud model APIs. It's not an entirely local AI app: questions and relevant course content may be sent to the model provider. Mathematical checks cover some cases; generated feedback can still be wrong.

## Development

```sh
swift test
uv sync
uv run pytest
go test ./...
```

PostgreSQL integration tests need `BETTERNB_TEST_DATABASE_URL`; see [the setup notes](docs/AUTHENTICATION.md). The tests above cover separate parts of the stack, not a complete end-to-end run.

For the longer version, see the [math notebook plan](docs/MATH-NOTEBOOK.md), [architecture](docs/ARCHITECTURE.md), and [development workflow](docs/DEVELOPMENT.md).
