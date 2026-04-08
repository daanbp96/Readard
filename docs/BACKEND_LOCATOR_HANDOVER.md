# Readtard Backend Handover

This document describes the **frontend contract that the iOS app now sends** for Ask requests.

The frontend no longer uses snippet-based ebook positioning.
It now treats the **Readium locator** as the source of truth for ebook position.

## Summary

The app now sends:

- `book_id`
- `source`
- `question`
- for ebook: `ebook.kind = "locator"`
- for ebook: `ebook.locator = { ... }`
- for audiobook: `audiobook.timestamp_sec`

## Endpoint

`POST /ask`

## Request shape

### Ebook

```json
{
  "book_id": "HarryPotter",
  "source": "ebook",
  "question": "Who is being referred to here?",
  "ebook": {
    "kind": "locator",
    "locator": {
      "href": "OEBPS/chapter-04.xhtml",
      "title": "Chapter Four",
      "fragments": [
        "epubcfi(/6/14!/4/2/10)",
        "some-anchor-id"
      ],
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

### Audiobook

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

## Field definitions

### Top-level

- `book_id: string`
  - Currently sent from the frontend as the local book folder name.
  - Examples in the current app:
    - `HarryPotter`
    - `PumpUpTheJam`

- `source: string`
  - One of:
    - `ebook`
    - `audiobook`

- `question: string`
  - The raw user question from the Ask UI.

### Ebook payload

- `ebook.kind: string`
  - Always `locator` for the new frontend path.

- `ebook.locator: object`
  - EPUB-native location payload derived from the active Readium locator.

#### `ebook.locator` fields

- `href: string`
  - The reading-order document currently being viewed.
  - This should be treated as the primary document anchor.

- `title: string | null`
  - Optional document/chapter title if Readium provided one.

- `fragments: string[]`
  - Fragment identifiers from the Readium locator.
  - If Readium exposes EPUB CFI-like information, it will be here.
  - This is the strongest structural anchor and should be preferred when available.

- `position: int | null`
  - Readium position index.
  - Useful as a fallback / coarse position signal.

- `progression: float | null`
  - In-document progression.
  - Usually a value between `0` and `1`.

- `totalProgression: float | null`
  - Whole-book progression.
  - Usually a value between `0` and `1`.

- `textBefore: string | null`
- `textHighlight: string | null`
- `textAfter: string | null`
  - Optional nearby text context from the locator.
  - These are no longer the canonical position mechanism.
  - They are intended as fallback/disambiguation/debugging aids only.

### Audiobook payload

- `audiobook.timestamp_sec: float`
  - Current playback timestamp in seconds.

## Recommended backend resolution order for ebook

The frontend expects the backend to treat the ebook locator as canonical.

Recommended resolution order:

1. `href + fragments`
   - Best path if the fragment contains EPUB CFI or a stable anchor.
2. `href + position`
   - Good fallback when structural fragment resolution is unavailable.
3. `href + progression`
   - Acceptable fallback within the current spine item.
4. `totalProgression`
   - Weakest fallback.
5. `textBefore/textHighlight/textAfter`
   - Last-resort fallback or debugging aid.

## Current frontend behavior

- The reader itself already uses the Readium locator as the truth for ebook position.
- Resume/persistence already stores this locator payload.
- Ask now sends this locator payload directly.
- The UI page number is only a display artifact and should not be used as backend truth.

## Important notes

- The old snippet-based ask path has been removed from the frontend.
- If the backend still only accepts `ebook.kind = "snippet"`, ebook Ask will fail until the backend is updated.
- The audiobook request shape is unchanged from the previous frontend implementation.

## Suggested backend response shape

The frontend currently expects:

```json
{ "answer": "..." }
```

Error responses can remain FastAPI-style with `detail`, ideally either:

```json
{ "detail": "..." }
```

or

```json
{ "detail": { "code": "...", "message": "..." } }
```

## Example implementation note

If you already normalize EPUB text and track spine order on the backend, the cleanest approach is:

- resolve `href` to the matching spine item
- if `fragments` contains EPUB CFI, resolve that first
- otherwise map `position` / `progression` to your internal text boundary model
- use `textBefore/textHighlight/textAfter` only when needed to recover from ambiguity
