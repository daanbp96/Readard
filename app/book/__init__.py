"""
EPUB loading, spine+local coordinates, snippet resolution.

Chunk metadata for retrieval is applied in :mod:`app.index.enrich`.
"""

from .context import create_context_for_question, narrow_window_from_resolved
from .loaders import LoadedBook, load_book
from .position import ResolvedPosition, resolve_position_from_snippet, spine_local_sort_key

__all__ = [
    "LoadedBook",
    "ResolvedPosition",
    "create_context_for_question",
    "load_book",
    "narrow_window_from_resolved",
    "resolve_position_from_snippet",
    "spine_local_sort_key",
]
