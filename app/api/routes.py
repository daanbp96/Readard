"""API routes."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from .schemas import AskRequest, AskResponse, HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
def health(request: Request) -> HealthResponse:
    ready = bool(getattr(request.app.state, "ready", False))
    return HealthResponse(ready=ready)


@router.post("/ask", response_model=AskResponse)
def ask(request: Request, body: AskRequest) -> AskResponse:
    session = request.app.state.reading_session

    if body.source == "audiobook":
        raise HTTPException(
            status_code=501,
            detail={
                "code": "AUDIOBOOK_NOT_IMPLEMENTED",
                "message": (
                    "Audiobook timestamp → ebook position is not implemented yet. "
                    "Use source=ebook with a snippet for now."
                ),
            },
        )

    assert body.ebook is not None
    try:
        session.set_position(body.ebook.snippet)
        answer = session.ask(body.question)
    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail={"code": "BAD_POSITION", "message": str(e)},
        ) from e

    return AskResponse(answer=answer)
