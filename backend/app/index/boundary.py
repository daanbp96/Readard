"""Spoiler-safe vector-store filter from a resolved reader position (enrich metadata keys)."""

from __future__ import annotations

from dataclasses import dataclass

from ..book.position import ResolvedPosition
from .enrich import SPINE_LOCAL_POS_END_KEY


@dataclass(frozen=True)
class ReaderBoundary:
    """Compare node ``end_metadata_key`` to ``lte_value`` (metadata LTE filter)."""

    end_metadata_key: str
    lte_value: str


def reader_boundary_for_resolved(resolved: ResolvedPosition) -> ReaderBoundary:
    """Boundary for chunks at or before the reader (same encoding as ``pos_end_key``)."""
    return ReaderBoundary(
        end_metadata_key=SPINE_LOCAL_POS_END_KEY,
        lte_value=resolved.reader_boundary_key,
    )
