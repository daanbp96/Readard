"""
Reader position in the book: spine index + offset into that spine item's ``doc.text``.

Includes the fixed-width sort key used for spoiler-safe retrieval and
snippet-based position resolution.
"""

from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Optional, Sequence

from llama_index.core.schema import Document


def spine_local_sort_key(spine_idx: int, local_plain_offset: int) -> str:
    """
    Fixed-width string so lexicographic order matches (spine_idx, local_plain_offset).

    Safe for MetadataFilter LTE on persisted stores.
    """
    return f"{spine_idx:04d}{local_plain_offset:010d}"


@dataclass(frozen=True)
class ResolvedPosition:
    """Resolved reader position: spine item + offset into that item's plain ``doc.text``."""

    snippet: str
    normalized_snippet: str
    spine_idx: int
    local_plain_offset: int
    reader_boundary_key: str


def resolve_position_from_snippet(
    documents: Sequence[Document],
    snippet: str,
) -> Optional[ResolvedPosition]:
    """
    Match a reader snippet against spine-ordered ``doc.text`` strings.

    Returns a position only if there is exactly one match across all documents.
    """
    if not snippet:
        return None

    token_pattern = _snippet_to_pattern(snippet)

    candidates: list[tuple[int, int]] = []
    for doc in documents:
        spine_idx = doc.metadata.get("spine_idx")
        if not isinstance(spine_idx, int):
            continue

        for match in re.finditer(token_pattern, doc.text, flags=re.IGNORECASE):
            last_plain = match.end() - 1
            candidates.append((spine_idx, last_plain))

    if len(candidates) != 1:
        return None

    spine_idx, last_plain = candidates[0]
    return ResolvedPosition(
        snippet=snippet,
        normalized_snippet=snippet,
        spine_idx=spine_idx,
        local_plain_offset=last_plain,
        reader_boundary_key=spine_local_sort_key(spine_idx, last_plain),
    )


def _snippet_to_pattern(snippet: str) -> str:
    tokens = [re.escape(token) for token in snippet.split(" ") if token]
    if not tokens:
        return r"$a"  # impossible match
    return r"\s+".join(tokens)
