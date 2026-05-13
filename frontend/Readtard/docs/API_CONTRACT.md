# Readtard API Contract (Current iOS App)

This document is the backend-facing contract for requests sent by the current iOS app.

## Endpoint

- `POST /ask`

## Related endpoints used by current app

- `GET /health`
- `GET /books`
- `GET /books/{book_id}/epub`

## Top-level request shape

```json
{
  "book_id": "HarryPotter",
  "source": "ebook",
  "question": "Who is being referred to here?",
  "ebook": { "...": "..." },
  "audiobook": null
}
```

### Required top-level fields

- `book_id` (string)
- `source` (`"ebook"` or `"audiobook"`)
- `question` (string, non-empty)

## Book ID selection in frontend

- App syncs `GET /books` on launch.
- Uses `books[].id` as canonical `book_id` when matched to a local bundled book.
- May ignore `directory_id` field if backend returns it.
- For ebook books missing bundled EPUB, app downloads `GET /books/{book_id}/epub` and opens cached file from Application Support.

---

## Ebook request payload

### Current app behavior

```json
{
  "book_id": "HarryPotter",
  "source": "ebook",
  "question": "What just happened?",
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
      "textHighlight": "last 20 visible words from the current page",
      "textAfter": null
    }
  }
}
```

### Notes

- `ebook.kind` is currently always `"locator"`.
- `textHighlight` is populated from the reader's current visible page tail (last 20 words).
- `fragments` and `otherLocations` may be empty depending on what Readium exposes.

---

## Audiobook request payload

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

## Backend handling guidance (ebook locator)

Recommended resolution order:

1. `href + fragments`
2. `href + position`
3. `href + progression`
4. `totalProgression`
5. `textBefore/textHighlight/textAfter` as fallback disambiguation

In current frontend behavior, the common practical signals are:

- `href`
- `position/progression`
- `textHighlight` (tail snippet)

---

## Validation and error handling

### Validate

- `book_id` exists
- `source` is valid
- `question` is non-empty
- if `source == "ebook"`:
  - `ebook.kind == "locator"`
  - `ebook.locator` exists
- if `source == "audiobook"`:
  - `audiobook.timestamp_sec` exists

### Suggested error responses

- `422`: invalid request/missing required fields
- `404`: unknown `book_id`
- `400`: unresolved or ambiguous position (`BAD_POSITION`)
- `501`: audiobook mapping not implemented yet

---

## Expected success response

```json
{ "answer": "..." }
```

## Accepted error response shapes

```json
{ "detail": "..." }
```

or

```json
{ "detail": { "code": "...", "message": "..." } }
```
