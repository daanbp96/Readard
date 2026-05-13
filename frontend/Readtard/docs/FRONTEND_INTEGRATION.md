# Readtard iOS (Swift) — current backend contract

This document describes the request/response contract currently used by the iOS app with the Readtard backend.

---

## 1. What the backend provides

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/health` | Liveness; `{ "status": "ok", "ready": true }` when the process finished startup. |
| `GET` | `/books` | List books the server can index and serve. |
| `GET` | `/books/{book_id}/epub` | Download the **same EPUB file** the server uses for RAG (for your ereader). |
| `POST` | `/ask` | Spoiler-safe Q&A at a **text position** (ebook locator payload). |

OpenAPI docs (useful while building): `GET /docs` on the server.

**There is no default book.** Every `/ask` request **must** include a `book_id` that matches a directory on the server under `data/books/<book_id>/`.

---

## 2. Runtime configuration

Current app expectations:

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
      "id": "hp_philosophers_stone",
      "epub_filename": "Harry Potter and the Sorcerer's Stone.epub",
      "title": "Harry Potter and the Sorcerer's Stone"
    }
  ]
}
```

- **`id`** — stable string; use everywhere (downloads, navigation, `/ask`).
- **`title`** — may be `null` if the server folder has no `metadata.json`.
- **`epub_filename`** — filename when saving locally (informational).
- **`directory_id`** — optional backend/debug identifier; frontend ignores this for API calls.

Current frontend behavior:

- On app launch, iOS calls `GET /books`.
- If a backend entry matches a local bundled book (by ID or title), app updates that book’s backend `book_id` and `epub_filename`.

---

### 3.3 `GET /books/{book_id}/epub`

**Binary response:** `Content-Type: application/epub+zip` (treat as EPUB file bytes).

**Errors**

- **404** — `detail` may be a JSON object with `code`: `BOOK_NOT_FOUND`.
- **400** — invalid `book_id` format.

Current frontend behavior

1. Build a URL: `{baseURL}/books/{bookId}/epub`.
2. Download with `URLSession` (or async `URLSession.shared.data(from:)`).
3. Write to **Application Support** (recommended), not the app bundle, e.g.:

   `Application Support/Readtard/books/{bookId}/{epub_filename}`

4. Pass the **local file URL** into the EPUB reader.
5. App downloads when needed if bundled EPUB is missing.

---

### 3.4 `POST /ask`

```json
{
  "book_id": "hp_philosophers_stone",
  "source": "ebook",
  "question": "What does this passage refer to?",
  "ebook": {
    "kind": "locator",
    "locator": {
      "href": "index_split_000.html",
      "position": 3,
      "progression": 0.0406,
      "totalProgression": 0.0110,
      "textHighlight": "last visible words from current page"
    }
  }
}
```

- **`book_id`** — **required.** Must match a server book id.
- **`source`** — `"ebook"` or `"audiobook"`.
- **`ebook.locator`** — Readium locator-derived position payload used by the app for ebook asks. `textHighlight` may contain a short tail snippet extracted from the current visible page.

**Response 200**

```json
{ "answer": "..." }
```

**Typical errors**

| Status | Meaning |
|--------|---------|
| **422** | Validation error (e.g. missing `book_id`, empty `question`). |
| **400** | `BAD_POSITION` — locator or locator-derived context cannot be resolved (`detail` has `code` and `message`). |
| **404** | Unknown `book_id` / no book on disk. |
| **501** | `AUDIOBOOK_NOT_IMPLEMENTED` if `source` is `audiobook` (until you implement mapping). |

**Audiobook payload**

```json
{
  "book_id": "...",
  "source": "audiobook",
  "question": "...",
  "audiobook": { "timestamp_sec": 123.45 }
}
```

If audiobook ask is not mapped yet, backend may return **501**.

---

## 4. curl examples (sanity checks)

```bash
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/books
curl -sOJ http://127.0.0.1:8000/books/hp_philosophers_stone/epub
curl -s http://127.0.0.1:8000/docs
```

```bash
curl -s -X POST http://127.0.0.1:8000/ask \
  -H 'Content-Type: application/json' \
  -d '{"book_id":"hp_philosophers_stone","source":"ebook","question":"Who is Dumbledore?","ebook":{"kind":"locator","locator":{"href":"index_split_000.html","position":3,"progression":0.04,"totalProgression":0.01,"textHighlight":"last visible words from page"}}}'
```

---

## 5. Backend file layout (reference)

Server repo:

```text
data/books/<book_id>/
  *.epub          # exactly one EPUB
  metadata.json   # optional: { "title": "..." }
```

Same **`book_id`** string in URLs, download path, and `POST /ask` body.
