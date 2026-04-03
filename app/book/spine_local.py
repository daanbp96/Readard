"""
Default position model: ``spine_idx`` + local offset in ``doc.text``, fixed-width sort key.

Coordinate space matches loaders' flattened body text per spine item.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

from llama_index.core.schema import BaseNode, Document

from .contracts import ReaderBoundary, ReaderPosition, ReadingPositionSystem
from .position import (
    ResolvedPosition,
    resolve_position_from_snippet as _resolve_snippet,
    spine_local_sort_key,
)


@dataclass(frozen=True)
class SpineLocalReaderPosition:
    """Wraps :class:`ResolvedPosition` for spine + local plain-text offset."""

    resolved: ResolvedPosition

    def as_retrieval_boundary(self) -> ReaderBoundary:
        return ReaderBoundary(
            end_metadata_key=SpineLocalReadingPositionSystem.END_METADATA_KEY,
            lte_value=self.resolved.reader_boundary_key,
        )

    def __getattr__(self, name: str):
        return getattr(self.resolved, name)


class SpineLocalReadingPositionSystem:
    """Spine index + local plain-text offset; LTE on ``pos_end_key`` sort string."""

    END_METADATA_KEY = "pos_end_key"

    def enrich_chunk_nodes(
        self,
        nodes: Sequence[BaseNode],
        doc_metadata_by_id: dict[str, dict],
    ) -> None:
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
                node.metadata[self.END_METADATA_KEY] = spine_local_sort_key(
                    spine_idx, last_plain
                )

            if isinstance(node_end, int):
                node.metadata["end_char_idx"] = node_end

    def index_nodes_are_compatible(self, nodes: Sequence[BaseNode]) -> bool:
        for node in nodes:
            if node.metadata.get(self.END_METADATA_KEY) is None:
                return False
        return True

    def resolve_snippet(
        self, documents: Sequence[Document], snippet: str
    ) -> ReaderPosition | None:
        r = _resolve_snippet(documents, snippet)
        if r is None:
            return None
        return SpineLocalReaderPosition(resolved=r)


DEFAULT_POSITION_SYSTEM: ReadingPositionSystem = SpineLocalReadingPositionSystem()
