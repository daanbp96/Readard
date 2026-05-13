# Readtard

SwiftUI demo app for:

- a local audiobook player
- a local EPUB reader
- a shared "Ask me" flow that sends the current book position to a backend

## Project Layout

### App shell

- `ContentView.swift`
  Main app flow. Owns library state, selected book, audiobook vs ebook mode, and ask-sheet presentation.
- `ReadtardApp.swift`
  SwiftUI app entry point.

### Models

- `Models/Audiobook.swift`
  Core book model. Resolves bundled file URLs and backend-synced IDs/EPUB cache paths.
- `Models/AudiobookMetadata.swift`
  `metadata.json` decoding model.
- `Models/AudiobookLoader.swift`
  Loads all bundled books from the `Book/` directory.
- `Models/PlayerTheme.swift`
  Player color theme decoded from metadata.
- `Models/ReadingProgressStore.swift`
  Persists audiobook progress and ebook progress in `UserDefaults`.
- `Models/EbookLocator.swift`
  Durable ebook position payload. This is the canonical ebook position used for resume and backend asks.
- `Models/ReadtardAPIClient.swift`
  Backend client for `/health`, `/books`, `/books/{id}/epub`, and `/ask`.

### Audiobook UI

- `Player/AudioPlayerController.swift`
  Local MP3/M4B playback using `AVAudioPlayer`.
- `Player/AudiobookPlayerView.swift`
  Audiobook player screen.
- `Player/ArtworkCard.swift`
  Cover-art card used by the audiobook player.

### Ebook UI

- `Player/EbookReaderController.swift`
  Opens the EPUB with Readium, tracks the current `Locator`, resolves TOC chapter targets, and restores/sends ebook position.
- `Player/EbookReaderView.swift`
  Ebook reading UI around the Readium navigator.
- `Player/EbookContentsSheet.swift`
  Table of contents sheet.
- `Player/EbookReaderSettingsSheet.swift`
  Reader theme/font controls.

### Ask flow

- `Player/AskConversationController.swift`
  Ask-sheet state and backend request construction.
- `Player/AskConversationSheet.swift`
  Ask-sheet UI for both audiobook and ebook.

### Library

- `Player/LibraryView.swift`
  Library grid for bundled books.

## Backend Book Sync (Current)

- On launch, app loads bundled `Book/*` metadata, then calls `GET /books`.
- Backend `books[].id` is treated as canonical `book_id` when available.
- For ebook-only books missing a bundled EPUB, app downloads `GET /books/{book_id}/epub` and caches to:
  - `Application Support/Readtard/books/<book_id>/<epub_filename>`

### Backend docs

- `docs/BACKEND_OVERVIEW.md`
- `docs/FRONTEND_INTEGRATION.md`
- `docs/BACKEND_LOCATOR_HANDOVER.md`

These describe the backend contract and the locator-based ebook payload.

## Book Bundle Format

The app expects:

- `Book/<BookFolder>/metadata.json`
- optional `Book/<BookFolder>/cover.jpg`
- optional `Book/<BookFolder>/audiobook.mp3` or `.m4b`
- optional `Book/<BookFolder>/ebook.epub`

At least one of audiobook or ebook should exist.

`metadata.json` is mandatory.

## Position Model

### Audiobook

- Canonical position: `currentTime` in seconds
- Sent to backend as `audiobook.timestamp_sec`
- Persisted in `ReadingProgressStore`

### Ebook

- Canonical position: `EbookLocator`
- Source of truth: current Readium `Locator`
- Sent to backend as `ebook.kind = "locator"` and `ebook.locator = {...}`
- Persisted in `ReadingProgressStore` as JSON

Important: the ebook API should treat the locator as the real position, not the displayed page label.

## Current Ask Behavior

### Ebook Ask (`Ask me`)

- On tap, the reader extracts the **last visible words** from the current rendered ebook page.
- The app uses locator-based requests:
  - `ebook.kind = "locator"`
  - `ebook.locator` includes `href/progression/position` and `textHighlight` (tail snippet).
- Ask requests are debug-printed in debug builds only.

### Audiobook Ask

- Uses `audiobook.timestamp_sec` as the current position.
- Request shape stays unchanged for audiobook source.

## Current Ebook Navigation Design

The ebook chapter jump path is intentionally simple:

1. Read TOC from the EPUB through Readium
2. Resolve each TOC entry to a single Readium `Locator`
3. Store that resolved locator as the chapter target
4. When a chapter is tapped, rebuild the navigator with that locator as `initialLocation`

This is simpler than the earlier mixed approach and is easier to debug.

## Current Caveats

### Stable

- Audiobook playback and timestamp progress
- Ebook locator resume
- Ebook locator payload for backend asks
- Bundled + backend-synced multi-book library loading

### Still fragile / needs follow-up

- EPUB chapter navigation can vary by EPUB quality
  Some EPUBs have clean TOC anchors; others only expose coarse position-based targets.
- Ebook page numbers are currently Readium-position-based UI labels
  They are not yet trustworthy as "real screen pages under current font settings".
- `pages left in chapter` is still derived from chapter start positions
  It should not be treated as final product behavior yet.

In short: backend position is reliable through locators; ebook page labels are not final.

## Backend Ask Contract

### Audiobook ask

The app sends:

- `book_id`
- `source = "audiobook"`
- `question`
- `audiobook.timestamp_sec`

### Ebook ask

The app sends:

- `book_id`
- `source = "ebook"`
- `question`
- `ebook.kind = "locator"`
- `ebook.locator`
  - `href`
  - `fragments`
  - `position`
  - `progression`
  - `totalProgression`
  - nearby text fields when available

See `docs/BACKEND_LOCATOR_HANDOVER.md` for the expected payload shape.

## Validation Checklist

Use these as the default smoke tests:

1. Launch app
   Expected: library opens first.

2. Open audiobook book
   Expected: audiobook player opens and resumes near previous timestamp.

3. Open ebook book
   Expected: ebook opens and resumes from saved locator.

4. Ask from audiobook
   Expected: request includes `timestamp_sec`.

5. Ask from ebook
   Expected: request includes locator payload, not snippet text.

6. Tap a few ebook chapters in `Contents`
   Expected: the visible reading position changes to a different chapter target.

7. Close and reopen ebook
   Expected: resume returns to the same locator-based reading position.

## Recommended Next Work

1. Add automated tests around ebook locator persistence and ask payload generation.
2. Add explicit logging for chapter target resolution in debug builds.
3. Revisit ebook page-number UX separately from locator correctness.
4. Only after chapter jumping is stable, improve `pages left in chapter`.
