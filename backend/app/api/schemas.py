"""Request/response models for the public API."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, model_validator


class ReadiumLocator(BaseModel):
    """Locator payload sent by Readium-based ebook reader."""

    href: str | None = None
    title: str | None = None
    fragments: list[str] = Field(default_factory=list)
    position: int | None = None
    progression: float | None = None
    totalProgression: float | None = None
    otherLocations: dict[str, float | int | str | None] = Field(default_factory=dict)
    textBefore: str | None = None
    textHighlight: str | None = None
    textAfter: str | None = None


class EbookPositionLocator(BaseModel):
    """Ebook progress represented by a Readium locator."""

    kind: Literal["locator"] = "locator"
    locator: ReadiumLocator


class AudiobookPosition(BaseModel):
    """Audiobook progress; mapped to ebook coordinates in a later phase."""

    timestamp_sec: float = Field(..., ge=0)


class AskRequest(BaseModel):
    """Ask a spoiler-safe question at the current media position."""

    book_id: str = Field(
        ...,
        min_length=1,
        description="Book id: directory name under data/books/<book_id>/ on the server.",
    )
    source: Literal["ebook", "audiobook"]
    question: str = Field(..., min_length=1)
    ebook: EbookPositionLocator | None = None
    audiobook: AudiobookPosition | None = None

    @model_validator(mode="after")
    def branch_matches_source(self) -> AskRequest:
        if self.source == "ebook":
            if self.ebook is None:
                raise ValueError("ebook is required when source is 'ebook'")
            if self.ebook.kind != "locator":
                raise ValueError("ebook.kind must be 'locator' when source is 'ebook'")
        elif self.source == "audiobook":
            if self.audiobook is None:
                raise ValueError("audiobook is required when source is 'audiobook'")
        return self


class AskResponse(BaseModel):
    answer: str


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    ready: bool


class BookListItem(BaseModel):
    id: str
    directory_id: str = Field(
        ...,
        description="Canonical folder name under data/books/ (for debugging; prefer id in clients).",
    )
    epub_filename: str
    title: str | None = None


class BookListResponse(BaseModel):
    books: list[BookListItem]
