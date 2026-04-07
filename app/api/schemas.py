"""Request/response models for the public API."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, model_validator


class EbookPositionSnippet(BaseModel):
    """Ebook progress as a verbatim snippet (matched in spine plain text)."""

    kind: Literal["snippet"] = "snippet"
    snippet: str = Field(..., min_length=1)


class AudiobookPosition(BaseModel):
    """Audiobook progress; mapped to ebook coordinates in a later phase."""

    timestamp_sec: float = Field(..., ge=0)


class AskRequest(BaseModel):
    """Ask a spoiler-safe question at the current media position."""

    source: Literal["ebook", "audiobook"]
    question: str = Field(..., min_length=1)
    ebook: EbookPositionSnippet | None = None
    audiobook: AudiobookPosition | None = None

    @model_validator(mode="after")
    def branch_matches_source(self) -> AskRequest:
        if self.source == "ebook":
            if self.ebook is None:
                raise ValueError("ebook is required when source is 'ebook'")
        elif self.source == "audiobook":
            if self.audiobook is None:
                raise ValueError("audiobook is required when source is 'audiobook'")
        return self


class AskResponse(BaseModel):
    answer: str


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    ready: bool
