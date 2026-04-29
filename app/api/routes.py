"""API routes."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse

from app.api.sessions import get_or_create_reading_session
from app.library.books import BookRecord, get_epub_path, list_books, validate_book_id
from app.session.audiobook_mapping import AudiobookTimestampMappingNotImplemented

from .position import resolve_request_position
from .schemas import AskRequest, AskResponse, BookListItem, BookListResponse, HealthResponse

router = APIRouter()


def _record_to_item(rec: BookRecord) -> BookListItem:
    return BookListItem(
        id=rec.id,
        directory_id=rec.directory_id,
        epub_filename=rec.epub_filename,
        title=rec.title,
    )


@router.get("/health", response_model=HealthResponse)
def health(request: Request) -> HealthResponse:
    ready = bool(getattr(request.app.state, "ready", False))
    return HealthResponse(ready=ready)


@router.get("/books", response_model=BookListResponse)
def books_list() -> BookListResponse:
    records = list_books()
    return BookListResponse(books=[_record_to_item(r) for r in records])


@router.get("/books/{book_id}/epub")
def books_epub(book_id: str) -> FileResponse:
    """Download the canonical EPUB for ereader sync (same bytes the server indexes)."""
    try:
        validate_book_id(book_id)
        path = get_epub_path(book_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except FileNotFoundError as e:
        raise HTTPException(
            status_code=404,
            detail={"code": "BOOK_NOT_FOUND", "message": str(e)},
        ) from e
    return FileResponse(
        path=path,
        filename=path.name,
        media_type="application/epub+zip",
    )


@router.post("/ask", response_model=AskResponse)
def ask(request: Request, body: AskRequest) -> AskResponse:
    session = get_or_create_reading_session(request, body.book_id)
    try:
        position = resolve_request_position(body, session)
    except AudiobookTimestampMappingNotImplemented as e:
        raise HTTPException(
            status_code=501,
            detail={"code": "AUDIOBOOK_NOT_IMPLEMENTED", "message": str(e)},
        ) from e
    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail={"code": "BAD_POSITION", "message": str(e)},
        ) from e
    session.set_resolved_position(position)
    try:
        answer = session.ask(body.question)
    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail={"code": "BAD_POSITION", "message": str(e)},
        ) from e
    return AskResponse(answer=answer)
