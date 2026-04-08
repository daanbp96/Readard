"""Per-book ReadingSession cache (lazy, in-process)."""

from __future__ import annotations

from fastapi import HTTPException, Request

from app.library.books import get_epub_path, validate_book_id
from app.session import ReadingSession


def get_or_create_reading_session(request: Request, book_id: str) -> ReadingSession:
    try:
        validate_book_id(book_id)
        epub_path = get_epub_path(book_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail={"code": "BOOK_NOT_FOUND", "message": str(e)}) from e

    cache: dict[str, ReadingSession] = request.app.state.sessions
    if book_id not in cache:
        session = ReadingSession(llm=request.app.state.llm)
        session.load_book(epub_path, force_reindex=False)
        cache[book_id] = session
    return cache[book_id]
