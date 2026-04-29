# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Readtard is a spoiler-aware reading companion. Given a reader's current position in an EPUB and a natural-language question, the backend answers using only text at or before that position. The deployment target is a single-process FastAPI service on Google Cloud Run; an iOS/SwiftUI client (Readium-based ebook reader) is the primary consumer.

## Commands

Dependencies are managed with `uv` (Python ≥ 3.11; default to 3.12+).

```bash
uv venv                       # create .venv
uv pip install -e .           # install project + deps from pyproject.toml / uv.lock

readtard                      # run uvicorn via app/cli.py
                              #   READTARD_HOST (default 0.0.0.0)
                              #   READTARD_PORT (default 8000)
                              #   READTARD_RELOAD=1 (default on)
uvicorn app.main:app --reload # alternative

python -m app.demo            # one-shot CLI demo (no HTTP); uses force_reindex=True
                              # and a hard-coded DEMO_BOOK_ID
```

OpenAPI UI is at `/docs` once the server is running. There is no test suite, linter, or formatter configured.

## Architecture

Layered, single-process, in-memory. HTTP layer (`app/api/`) is a thin shell over `ReadingSession` (`app/session/reading.py`), which composes book loading, indexing, and retrieval.

### Request lifecycle

1. FastAPI lifespan (`app/main.py`) calls `initialize_environment()` (loads `.env`) and creates one shared `LLM` via `app.llm.create_llm`. `app.state.sessions: dict[str, ReadingSession]` starts empty — no book is preloaded.
2. `POST /ask` → `app/api/sessions.py:get_or_create_reading_session` lazily constructs and caches one `ReadingSession` per `book_id` and calls `load_book(force_reindex=False)`. **Never pass `force_reindex=True` on a request path** — it's only for one-off reindexing (see `app/demo.py`).
3. The route resolves the client's position into a `ResolvedPosition`, then calls `session.ask(question)`.

### Spoiler safety (the core invariant)

The whole pipeline preserves a single ordering: `(spine_idx, local_plain_offset)` encoded as a fixed-width string `f"{spine_idx:04d}{local_plain_offset:010d}"` (`app/book/position.py:spine_local_sort_key`). This key works as a lexicographic substitute for the tuple, which lets persisted vector stores apply a `MetadataFilter` LTE filter — that's why the encoding must stay fixed-width.

- **Load** (`app/book/loaders.py`): EPUB → one LlamaIndex `Document` per spine HTML item, in OPF spine order, with body text flattened by joining non-empty stripped `text()` nodes with spaces. Any code that maps an offset back into `doc.text` must use the same flattening.
- **Index** (`app/index/`): `SentenceSplitter` chunks documents; `enrich_spine_local_chunk_nodes` writes `spine_idx`, `end_char_idx`, and the `pos_end_key` (the same fixed-width sort key, evaluated at the chunk's last character). The index is persisted under `persist_dir/<book_stem>/` with `SimpleDocumentStore` / `SimpleIndexStore` / `SimpleVectorStore`. On load, `spine_local_index_nodes_are_compatible` checks for `pos_end_key`; missing → rebuild.
- **Position** (`app/book/position.py`): `resolve_position_from_snippet` finds **exactly one** match (whitespace-tolerant regex, case-insensitive) in spine-ordered docs. Multiple or zero matches → `ValueError`.
- **Locator** (`app/book/locator.py`): builds a snippet from `textHighlight` and reuses `resolve_position_from_snippet`. The other Readium fields (`href`, `fragments`, `position`, `progression`) are accepted in the schema but currently unused. (`docs/BACKEND_LOCATOR_HANDOVER.md` describes a richer resolution order but predates the current code — treat the code as the source of truth.)
- **Retrieve** (`app/session/retrieve.py`): vector retrieval with a `MetadataFilter` `LTE` against `pos_end_key`. Optionally merges a "partial chunk" (the part of the reader's current chunk up to and including their offset) by re-embedding it and re-sorting top-k.
- **Answer** (`app/session/query.py`): with retrieved nodes, uses LlamaIndex `ResponseMode.COMPACT` synthesizer with templates from `app/prompts/query_prompts.py` and a small reader-window context (`READER_CONTEXT_CHARS_BEFORE/AFTER`) for resolving deictics. With no retrieved nodes, falls back to passage-only completion.

### Books on disk

- `data/books/<book_id>/` — exactly one `*.epub`, optional `metadata.json` with a `title` and optional `client_book_ids` for client-facing aliases. `data/books/book_aliases.json` is an alternate alias map. `app/library/books.py:resolve_to_directory_id` resolves: direct dir match → aliases file → metadata `client_book_ids` scan.
- `book_id` must match `^[a-zA-Z0-9][a-zA-Z0-9._-]*$` (no path traversal). Validate via `validate_book_id` before any filesystem work.
- `persist_dir/` (gitignored) holds vector indices, keyed by EPUB stem (`get_book_persist_path`). Deleting a book's persist dir forces a reindex on next load.

### Audiobook source

`source: "audiobook"` is wired through API/schemas but `resolve_position_from_audiobook_timestamp` raises `AudiobookTimestampMappingNotImplemented` → HTTP 501. Don't add `# TODO` removals here without designing the timestamp → spine-offset mapping first.

## Conventions

- Tunables (chunk size, `SIMILARITY_TOP_K`, reader window, model name, temperature) live in `app/config.py`. Book identity is **not** configured here — it's per-request.
- LlamaIndex `Settings` (embed model, callback manager) is read globally; the LLM instance is passed explicitly to `ReadingSession`.
- OpenAI is the only supported LLM provider (`app/llm/factory.py`); adding another provider means extending the factory, not bypassing it.
- Cloud Run constraints: bind `0.0.0.0`, honor `$PORT`, avoid filesystem writes outside `persist_dir/`. In-memory session loss across restarts is acceptable for the demo stage.

## Reference docs

- `docs/BACKEND_OVERVIEW.md` — narrative architecture overview (mirrors this file at higher level).
- `docs/BACKEND_LOCATOR_HANDOVER.md` — frontend → backend Ask request contract; the locator resolution order the backend should eventually implement.
- `docs/FRONTEND_INTEGRATION.md`, `docs/FRONTEND_HANDOVER.md` — Swift client integration notes.
- `readtard_backend_plan.md` — original milestone plan; may drift from current code.
