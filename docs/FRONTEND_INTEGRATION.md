# Readtard iOS (Swift) — backend integration guide

This document describes what to build in the **Swift/SwiftUI** app to talk to the **Readtard FastAPI** backend. It assumes a single development machine on your LAN for now (no production hardening).

---

## 1. What the backend provides

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/health` | Liveness; `{ "status": "ok", "ready": true }` when the process finished startup. |
| `GET` | `/books` | List books the server can index and serve. |
| `GET` | `/books/{book_id}/epub` | Download the **same EPUB file** the server uses for RAG (for your ereader). |
| `POST` | `/ask` | Spoiler-safe Q&A at an ebook/audiobook position. |

OpenAPI docs (useful while building): `GET /docs` on the server.

**There is no default book.** Every `/ask` request **must** include a `book_id`.

**Book id naming:** The server stores each title under `data/books/<directory_id>/` (e.g. `hp_philosophers_stone`). Your app may use a **different** bundle folder name (e.g. `HarryPotter`). The backend resolves that via `data/books/book_aliases.json` and/or `client_book_ids` in each book’s `metadata.json`, so **`book_id` can be the iOS bundle name** when it is registered. `GET /books` returns the **client-facing** `id` plus `directory_id` for debugging.

---

## 2. Configuration in the app

Build a small **API configuration** type (or `Info.plist` / build settings):

- **`baseURL`** — e.g. `http://192.168.1.12:8000` during development (Mac’s LAN IP + port). No trailing slash.
- **Timeouts** — use a **long** read timeout for `POST /ask` (LLM calls are slow; 60–120s is reasonable for demos).
- **Optional:** `READTARD_RELOAD=0` on the server for stable connections when not editing Python.

You will likely add an **App Transport Security** exception for **local HTTP** during dev (see Apple docs: “Allow Arbitrary Loads” or per-domain exceptions). Use **HTTPS** in production (e.g. Cloud Run).

---

## 3. REST contract (JSON)

### 3.1 `GET /health`

**Response 200**

```json
{ "status": "ok", "ready": true }
```

Use this to show “backend reachable” before opening the Ask flow (optional but good UX).

---

### 3.2 `GET /books`

**Response 200**

```json
{
  "books": [
    {
      "id": "HarryPotter",
      "directory_id": "hp_philosophers_stone",
      "epub_filename": "Harry Potter and the Sorcerer's Stone.epub",
      "title": "Harry Potter and the Sorcerer's Stone"
    }
  ]
}
```

- **`id`** — use this in `/ask` and `/books/{book_id}/epub` (matches your bundle folder name when aliased).
- **`directory_id`** — actual folder on the server (for debugging).
- **`title`** — may be `null` if the server folder has no `metadata.json`.
- **`epub_filename`** — filename when saving locally (informational).

**Frontend work:** model `BookListItem` / `BookListResponse`; drive a library picker or hard-code an id during early development.

---

### 3.3 `GET /books/{book_id}/epub`

**Binary response:** `Content-Type: application/epub+zip` (treat as EPUB file bytes).

**Errors**

- **404** — `detail` may be a JSON object with `code`: `BOOK_NOT_FOUND`.
- **400** — invalid `book_id` format.

**Frontend work**

1. Build a URL: `{baseURL}/books/{bookId}/epub`.
2. Download with `URLSession` (or async `URLSession.shared.data(from:)`).
3. Write to **Application Support** (recommended), not the app bundle, e.g.:

   `Application Support/Readtard/books/{bookId}/{epub_filename}`

4. Pass the **local file URL** into your EPUB reader component.
5. Optionally cache **etag** / file size later; for MVP, overwrite on each “sync” is fine.

---

### 3.4 `POST /ask`

**Request body (ebook path — Readium locator preferred)**

```json
{
  "book_id": "hp_philosophers_stone",
  "source": "ebook",
  "question": "What does this passage refer to?",
  "ebook": {
    "kind": "locator",
    "locator": {
      "href": "OEBPS/chapter-04.xhtml",
      "title": "Chapter Four",
      "fragments": ["epubcfi(/6/14!/4/2/10)", "some-anchor-id"],
      "position": 187,
      "progression": 0.421,
      "totalProgression": 0.162,
      "textBefore": "...",
      "textHighlight": "...",
      "textAfter": "..."
    }
  }
}
```

- **`book_id`** — **required.** Must match a server book id.
- **`source`** — `"ebook"` or `"audiobook"`.
- **`ebook.kind = "locator"`** — backend resolves position from Readium locator using fallbacks (`href + fragments`, `href + position`, `href + progression`, `totalProgression`, then text fallback).

**Response 200**

```json
{ "answer": "..." }
```

**Typical errors**

| Status | Meaning |
|--------|---------|
| **422** | Validation error (e.g. missing `book_id`, empty `question`). |
| **400** | `BAD_POSITION` — unresolved or ambiguous reading position (including locator resolution failures). |
| **404** | Unknown `book_id` / no book on disk. |
| **501** | `AUDIOBOOK_NOT_IMPLEMENTED` if `source` is `audiobook` (until you implement mapping). |

**Audiobook (future)**

```json
{
  "book_id": "...",
  "source": "audiobook",
  "question": "...",
  "audiobook": { "timestamp_sec": 123.45 }
}
```

Currently returns **501**; your app should handle that while audiobook timestamp mapping is being implemented.

---

## 4. What to build in the Swift app (checklist)

### 4.1 Networking layer

- [ ] `APIClient` (or similar) with injectable `baseURL`.
- [ ] Typed methods: `health()`, `listBooks()`, `downloadEpub(bookId:)`, `ask(request:)`.
- [ ] **Codable** models matching the JSON above (`AskRequest`, `AskResponse`, `BookListResponse`, …).
- [ ] Centralized **error** type: decode FastAPI `detail` (string or `{ code, message }`).
- [ ] Long timeout for `/ask`; shorter for `/health` and downloads.

### 4.2 Library / book identity

- [ ] Persist **selected `book_id`** (UserDefaults or SwiftData) after user picks a book or after first sync.
- [ ] After `GET /books`, reconcile with local cached EPUBs (optional): re-download if missing or outdated.

### 4.3 Ereader

- [ ] Open EPUB from **local file URL** (downloaded via `GET .../epub`).
- [ ] Send the current **Readium locator** (`ebook.kind = "locator"`) from the active reading position.
- [ ] No snippet payload is required for the current app contract; send locator payload directly.

### 4.4 Ask UI (existing `AskConversation*` flow)

- [ ] On submit: build `POST /ask` with `book_id`, `source: "ebook"`, `question`, and `ebook: { kind: "locator", locator: ... }`.
- [ ] Show loading state; handle errors with user-visible messages.
- [ ] Display `answer` string in the conversation UI.

### 4.5 Audiobook player (parallel track)

- [ ] Keep playback UI and **metadata** as you have now.
- [ ] Until audiobook timestamp mapping exists, either hide Ask for audiobook-only sessions or show “not supported yet” when the backend returns **501**.

### 4.6 Development workflow

- [ ] Document in README: set Mac IP, run backend with `0.0.0.0:8000`, point app `baseURL` at `http://<ip>:8000`.
- [ ] Optional: Settings screen in the app to edit base URL for testers.

---

## 5. Suggested order of implementation

1. **Config + `GET /health`** — proves connectivity.
2. **`GET /books` + list UI** — user (or dev) picks `book_id`.
3. **`GET /books/{id}/epub` + save to disk + open in reader** — vertical slice for reading.
4. **`POST /ask` with locator from reader** — full Ask loop.
5. Polish errors, timeouts, and later audiobook mapping.

---

## 6. curl examples (sanity checks)

```bash
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/books
curl -sOJ http://127.0.0.1:8000/books/hp_philosophers_stone/epub
curl -s http://127.0.0.1:8000/docs
```

```bash
curl -s -X POST http://127.0.0.1:8000/ask \
  -H 'Content-Type: application/json' \
  -d '{"book_id":"hp_philosophers_stone","source":"ebook","question":"Who is Dumbledore?","ebook":{"kind":"locator","locator":{"href":"OEBPS/chapter-04.xhtml","position":187,"progression":0.421}}}'
```

---

## 7. Backend file layout (reference)

Server repo:

```text
data/books/<book_id>/
  *.epub          # exactly one EPUB
  metadata.json   # optional: { "title": "..." }
```

Same **`book_id`** string in URLs, download path, and `POST /ask` body.
