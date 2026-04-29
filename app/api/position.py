"""HTTP-shape -> domain-shape adapter for /ask request positions."""

from __future__ import annotations

from typing import TYPE_CHECKING

from ..book.locator import ReadiumLocatorPayload, resolve_position_from_locator
from ..book.position import ResolvedPosition
from ..session.audiobook_mapping import (
    AudiobookTimestampMappingNotImplemented,
    resolve_position_from_audiobook_timestamp,
)

if TYPE_CHECKING:
    from ..session.reading import ReadingSession
    from .schemas import AskRequest


def resolve_request_position(
    body: "AskRequest", session: "ReadingSession"
) -> ResolvedPosition:
    if body.source == "ebook" and body.ebook is not None:
        loc = body.ebook.locator
        payload = ReadiumLocatorPayload(
            href=loc.href,
            title=loc.title,
            fragments=list(loc.fragments),
            position=loc.position,
            progression=loc.progression,
            total_progression=loc.totalProgression,
            text_highlight=loc.textHighlight,
        )
        return resolve_position_from_locator(session.book.documents, payload)
    if body.source == "audiobook" and body.audiobook is not None:
        resolved, _meta = resolve_position_from_audiobook_timestamp(
            session=session,
            timestamp_sec=body.audiobook.timestamp_sec,
        )
        return resolved
    raise ValueError(f"unsupported source: {body.source!r}")
