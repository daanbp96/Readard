"""
Pluggable reading-position model (coordinate system + how chunks get metadata).

Implementations live under ``app.book``; session/index import these types from
``app.book`` only.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, Protocol, Sequence, runtime_checkable

if TYPE_CHECKING:
    from llama_index.core.schema import BaseNode, Document


@dataclass(frozen=True)
class ReaderBoundary:
    """
    Minimal input for spoiler-safe retrieval: compare node end metadata to this value.

    ``end_metadata_key`` is the node metadata field storing the comparable end marker.
    """

    end_metadata_key: str
    lte_value: str


@runtime_checkable
class ReaderPosition(Protocol):
    """Resolved reader location; must produce a boundary for vector-store filtering."""

    def as_retrieval_boundary(self) -> ReaderBoundary: ...


class ReadingPositionSystem(Protocol):
    """
    One implementation = one coordinate model for ingest, resolve, and retrieve.

    Replace the default from ``app.book`` to swap systems without editing session/index.
    """

    def enrich_chunk_nodes(
        self,
        nodes: Sequence["BaseNode"],
        doc_metadata_by_id: dict[str, dict],
    ) -> None:
        """After chunking, attach model-specific metadata to each node."""
        ...

    def index_nodes_are_compatible(self, nodes: Sequence["BaseNode"]) -> bool:
        """Whether a loaded index was built with this system's chunk metadata."""
        ...

    def resolve_snippet(
        self, documents: Sequence["Document"], snippet: str
    ) -> ReaderPosition | None:
        ...
