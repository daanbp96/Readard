"""Audiobook timestamp -> ebook position mapping (placeholder contract)."""

from __future__ import annotations

from dataclasses import dataclass

from ..book.position import ResolvedPosition
from .reading import ReadingSession


@dataclass(frozen=True)
class TimestampMappingMetadata:
    """Optional metadata for observability when mapping is implemented."""

    method: str


class AudiobookTimestampMappingNotImplemented(NotImplementedError):
    """Raised while audiobook timestamp mapping is still a stub."""


def resolve_position_from_audiobook_timestamp(
    *,
    session: ReadingSession,
    timestamp_sec: float,
) -> tuple[ResolvedPosition, TimestampMappingMetadata]:
    """Return a resolved ebook position for the provided audiobook timestamp.

    This is intentionally not implemented yet; it exists to lock the API and
    control flow while timestamp indexing is designed.
    """
    _ = session
    _ = timestamp_sec
    raise AudiobookTimestampMappingNotImplemented(
        "Audiobook timestamp mapping is not implemented yet."
    )
