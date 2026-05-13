"""Resolve Readium locator payloads to internal spoiler-boundary positions."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Sequence

from llama_index.core.schema import Document

from .position import ResolvedPosition, resolve_position_from_snippet


@dataclass(frozen=True)
class ReadiumLocatorPayload:
    """Transport-agnostic Readium locator payload."""

    href: str | None = None
    title: str | None = None
    fragments: list[str] = field(default_factory=list)
    position: int | None = None
    progression: float | None = None
    total_progression: float | None = None
    text_highlight: str | None = None


def create_snippet(locator: ReadiumLocatorPayload) -> str:
    """Build the snippet used as authoritative ebook position signal.

    MVP policy: use `text_highlight` when present.
    """
    highlight = _normalize_whitespace(locator.text_highlight or "")
    if highlight:
        return highlight
    raise ValueError("Locator is missing textHighlight; cannot resolve reading position.")


def resolve_position_from_locator(
    documents: Sequence[Document],
    locator: ReadiumLocatorPayload,
) -> ResolvedPosition:
    """Resolve position from locator by converting it to snippet first."""
    snippet = create_snippet(locator)
    return resolve_position_from_snippet(documents, snippet)


def _normalize_whitespace(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()
