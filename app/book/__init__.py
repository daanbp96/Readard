"""
EPUB loading, spine+local coordinates, snippet resolution, and pluggable position systems.

Coordinate logic and defaults live here so you can swap implementations by editing
only ``app.book`` (e.g. add a new ``ReadingPositionSystem`` and change
``DEFAULT_POSITION_SYSTEM``).
"""

from .context import narrow_window_from_resolved, reader_passage_for_llm
from .contracts import ReaderBoundary, ReaderPosition, ReadingPositionSystem
from .loaders import LoadedBook, load_book
from .position import ResolvedPosition, resolve_position_from_snippet, spine_local_sort_key
from .spine_local import (
    DEFAULT_POSITION_SYSTEM,
    SpineLocalReaderPosition,
    SpineLocalReadingPositionSystem,
)

__all__ = [
    "DEFAULT_POSITION_SYSTEM",
    "LoadedBook",
    "ReaderBoundary",
    "ReaderPosition",
    "ReadingPositionSystem",
    "ResolvedPosition",
    "SpineLocalReaderPosition",
    "SpineLocalReadingPositionSystem",
    "load_book",
    "narrow_window_from_resolved",
    "reader_passage_for_llm",
    "resolve_position_from_snippet",
    "spine_local_sort_key",
]
