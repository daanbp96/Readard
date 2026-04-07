"""FastAPI application entrypoint."""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes import router
from app.config import BOOK_FILENAME, LLM_PROVIDER, OPENAI_MODEL
from app.environment import DATA_DIR, initialize_environment
from app.llm import create_llm
from app.session import ReadingSession


@asynccontextmanager
async def lifespan(app: FastAPI):
    initialize_environment()
    llm = create_llm(model=OPENAI_MODEL, provider=LLM_PROVIDER)
    session = ReadingSession(llm=llm)
    book_path = DATA_DIR / BOOK_FILENAME
    session.load_book(book_path, force_reindex=False)
    app.state.reading_session = session
    app.state.ready = True
    yield


app = FastAPI(
    title="Readtard API",
    description="Spoiler-aware reading companion backend.",
    lifespan=lifespan,
)
app.include_router(router)
