"""
Reader-local text for the LLM: narrow window around the resolved spine position.

Tune window size via :mod:`app.config` (``READER_CONTEXT_CHARS_*``).
"""

from __future__ import annotations

from typing import Sequence

from llama_index.core.schema import Document

from ..config import READER_CONTEXT_CHARS_AFTER, READER_CONTEXT_CHARS_BEFORE
from .position import ResolvedPosition


def narrow_window_from_resolved(
    documents: Sequence[Document],
    position: ResolvedPosition,
    chars_before: int,
    chars_after: int,
) -> str:
    """
    Slice ``doc.text`` for the spine item containing ``position``, around ``local_plain_offset``.

    ``local_plain_offset`` is treated as an inclusive character index in ``doc.text``.
    """
    for doc in documents:
        if doc.metadata.get("spine_idx") != position.spine_idx:
            continue
        text = doc.text
        lo = position.local_plain_offset
        start = max(0, lo - chars_before)
        end = min(len(text), lo + 1 + chars_after)
        return text[start:end]
    return ""


def create_context_for_question(
    documents: Sequence[Document],
    position: ResolvedPosition,
) -> str:
    """Short passage around the reader position for deictic questions (uses config window size)."""
    return narrow_window_from_resolved(
        documents,
        position,
        READER_CONTEXT_CHARS_BEFORE,
        READER_CONTEXT_CHARS_AFTER,
    )
