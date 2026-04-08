# Frontend Handover (Current Backend)

Use this as the implementation contract for iOS right now.

## 1) Base URL
- Dev: `http://<your-mac-lan-ip>:8000`
- Backend docs: `GET /docs`

---

## 2) Endpoints available now

- `GET /health`
- `GET /books`
- `GET /books/{book_id}/epub`
- `POST /ask`

Note: dedicated endpoints for `metadata/cover/audio` are not implemented yet.

---

## 3) `GET /books` response (source of truth for IDs)

Example shape:

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

Frontend rule:
- Use `id` as the canonical `book_id` for all calls.
- Ignore `directory_id` (debug only).

---

## 4) Downloading EPUB

`GET /books/{book_id}/epub` returns `application/epub+zip`.

Frontend storage (recommended):
- `Application Support/Readtard/books/<book_id>/ebook.epub`

If already cached, you can skip download for now (manual MVP policy).

---

## 5) Ask request contract

### Ebook (implemented)

```json
{
  "book_id": "HarryPotter",
  "source": "ebook",
  "question": "Who is being referred to here?",
  "ebook": {
    "kind": "locator",
    "locator": {
      "href": "index_split_000.html",
      "title": null,
      "fragments": [],
      "position": 3,
      "progression": 0.0406,
      "totalProgression": 0.0110,
      "otherLocations": {},
      "textBefore": null,
      "textHighlight": "last 20 visible words",
      "textAfter": null
    }
  }
}
```

### Audiobook (shape accepted, mapping not implemented)

```json
{
  "book_id": "PumpUpTheJam",
  "source": "audiobook",
  "question": "What was just said?",
  "audiobook": {
    "timestamp_sec": 123.45
  }
}
```

---

## 6) Ask responses

Success:

```json
{ "answer": "..." }
```

Errors:
- `422` invalid payload
- `404` unknown `book_id`
- `400` `BAD_POSITION` (locator unresolved/ambiguous)
- `501` `AUDIOBOOK_NOT_IMPLEMENTED`

Handle both error shapes:
- `{ "detail": "..." }`
- `{ "detail": { "code": "...", "message": "..." } }`

---

## 7) Frontend flow to implement now

1. App launch / library screen:
   - call `GET /books`
2. User selects a book:
   - keep selected `book_id`
   - ensure local epub exists; if missing call `GET /books/{book_id}/epub`
3. Reader asks question:
   - send `POST /ask` with `source: "ebook"` and current Readium locator
4. Show answer text from response.

---

## 8) Important current constraints

- Ebook ask is locator-only (`ebook.kind = "locator"`).
- Audiobook ask currently returns `501` until timestamp mapping is implemented.
- Backend currently supports manual content ops; no version/hash sync yet.
- Ebook-only, audiobook-only, or both should be allowed as MVP policy.

