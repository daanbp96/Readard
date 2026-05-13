"""
Reader position in the book: spine index + offset into that spine item's ``doc.text``.

Includes the fixed-width sort key used for spoiler-safe retrieval and
snippet-based position resolution.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Sequence

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
) -> ResolvedPosition:
    """
    Match a reader snippet against spine-ordered ``doc.text`` strings.

    Raises ``ValueError`` if the snippet is empty or does not match exactly one location.
    """
    if not snippet:
        raise ValueError("Snippet is empty.")

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
        raise ValueError(
            "Expected exactly one match for the snippet in the book text, "
            f"found {len(candidates)}."
        )

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
        raise ValueError("Snippet has no tokens to match.")
    return r"\s+".join(tokens)
