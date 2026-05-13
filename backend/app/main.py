"""FastAPI application entrypoint."""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.routes import router
from app.config import LLM_PROVIDER, OPENAI_MODEL
from app.environment import initialize_environment
from app.llm import create_llm


@asynccontextmanager
async def lifespan(app: FastAPI):
    initialize_environment()
    llm = create_llm(model=OPENAI_MODEL, provider=LLM_PROVIDER)
    app.state.llm = llm
    app.state.sessions = {}
    app.state.ready = True
    yield


app = FastAPI(
    title="Readtard API",
    description="Spoiler-aware reading companion backend.",
    lifespan=lifespan,
)
app.include_router(router)
