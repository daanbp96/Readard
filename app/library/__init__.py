"""On-disk book layout, discovery, and EPUB paths."""

from .books import (
    BookRecord,
    get_epub_path,
    list_books,
    resolve_to_directory_id,
    validate_book_id,
)

__all__ = [
    "BookRecord",
    "get_epub_path",
    "list_books",
    "resolve_to_directory_id",
    "validate_book_id",
]
