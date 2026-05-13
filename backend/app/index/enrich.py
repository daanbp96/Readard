"""Chunk/node metadata for spine-local spoiler-safe retrieval (``pos_end_key``, etc.)."""

from __future__ import annotations

from typing import Sequence

from llama_index.core.schema import BaseNode

from ..book.position import spine_local_sort_key

# Metadata field storing the end of each chunk in spine-local sort space (for LTE filter).
SPINE_LOCAL_POS_END_KEY = "pos_end_key"


def enrich_spine_local_chunk_nodes(
    nodes: Sequence[BaseNode],
    doc_metadata_by_id: dict[str, dict],
) -> None:
    """After chunking, attach spine index, ``pos_end_key``, and char indices for retrieval."""
    for chunk_seq_global, node in enumerate(nodes):
        node.metadata["chunk_seq_global"] = chunk_seq_global

        source_meta = doc_metadata_by_id.get(getattr(node, "ref_doc_id", ""), {})
        spine_idx = source_meta.get("spine_idx")
        if isinstance(spine_idx, int):
            node.metadata.setdefault("spine_idx", spine_idx)

        node_start = getattr(node, "start_char_idx", None)
        node_end = getattr(node, "end_char_idx", None)

        if isinstance(spine_idx, int) and isinstance(node_end, int):
            if isinstance(node_start, int):
                last_plain = (
                    node_end - 1 if node_end > node_start else node_start
                )
            else:
                last_plain = max(0, node_end - 1)
            node.metadata[SPINE_LOCAL_POS_END_KEY] = spine_local_sort_key(
                spine_idx, last_plain
            )

        if isinstance(node_end, int):
            node.metadata["end_char_idx"] = node_end


def spine_local_index_nodes_are_compatible(nodes: Sequence[BaseNode]) -> bool:
    """Whether persisted nodes were built with :func:`enrich_spine_local_chunk_nodes`."""
    for node in nodes:
        if node.metadata.get(SPINE_LOCAL_POS_END_KEY) is None:
            return False
    return True
