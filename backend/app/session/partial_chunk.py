"""Spoiler-safe text read so far within the index chunk that contains the reader offset."""

from __future__ import annotations

from typing import Sequence

from llama_index.core.schema import BaseNode


def partial_text_in_covering_chunk(
    nodes: Sequence[BaseNode],
    spine_idx: int,
    local_plain_offset: int,
) -> str:
    """Substring from chunk start through ``local_plain_offset`` (inclusive) on ``spine_idx``."""
    for node in nodes:
        if node.metadata.get("spine_idx") != spine_idx:
            continue
        start = getattr(node, "start_char_idx")
        end = getattr(node, "end_char_idx")
        if start <= local_plain_offset < end:
            return node.get_content()[: local_plain_offset - start + 1]
    return ""
