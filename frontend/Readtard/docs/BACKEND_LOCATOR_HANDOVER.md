# Readtard Backend Handover (Current iOS Contract)

This document describes the request contract currently sent by the iOS app.

## Endpoint

`POST /ask`

## Summary

The app sends:

- `book_id`
- `source`
- `question`
- for ebook: `ebook.kind = "locator"` and `ebook.locator`
- for audiobook: `audiobook.timestamp_sec`

## Book ID source

- Frontend syncs `GET /books` on launch.
- `books[].id` is treated as canonical `book_id` for requests when mapped.
- `directory_id` (if present) is ignored by iOS for API calls.

## Ebook request shape

```json
{
  "book_id": "HarryPotter",
  "source": "ebook",
  "question": "Who is being referred to here?",
  "ebook": {
    "kind": "locator",
    "locator": {
      "href": "index_split_000.html",
      "title": "Chapter title if available",
      "fragments": [],
      "position": 3,
      "progression": 0.04,
      "totalProgression": 0.01,
      "otherLocations": {},
      "textBefore": "...optional context...",
      "textHighlight": "...last visible words / selected snippet...",
      "textAfter": "...optional context..."
    }
  }
}
```

## Backend resolution recommendation

Preferred order:

1. `href + fragments` (strongest)
2. `href + position`
3. `href + progression`
4. `totalProgression`
5. `textBefore/textHighlight/textAfter` (fallback disambiguation)

## Notes

- Frontend no longer sends `ebook.kind = "snippet"` as the canonical path.
- `textHighlight` may be populated from the reader's current visible tail text when user taps Ask.
