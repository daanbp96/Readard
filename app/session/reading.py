from pathlib import Path
from typing import Optional, Sequence

from llama_index.core.llms import LLM
from llama_index.core import Settings, VectorStoreIndex
from llama_index.core.schema import BaseNode

from ..book import (
    DEFAULT_POSITION_SYSTEM,
    LoadedBook,
    ReaderPosition,
    ReadingPositionSystem,
    load_book,
    reader_passage_for_llm,
)
from ..config import SIMILARITY_TOP_K
from ..environment import get_book_persist_path
from ..index import build_default_transformations, get_or_create_index
from .query import run_query
from .retrieve import retrieve_allowed_nodes


class ReadingSession:
    """
    Single-open-book session.

    Flow: ``load_book`` → ``set_position`` (snippet) → ``ask`` (repeat).

    Pass ``position_system`` (from ``app.book``) to swap coordinate models later.
    """

    def __init__(
        self,
        llm: LLM,
        position_system: ReadingPositionSystem | None = None,
    ):
        self.llm = llm
        self._position_system: ReadingPositionSystem = (
            position_system or DEFAULT_POSITION_SYSTEM
        )

        self.book: Optional[LoadedBook] = None
        self.index: Optional[VectorStoreIndex] = None
        self.nodes: Optional[Sequence[BaseNode]] = None
        self.position: Optional[ReaderPosition] = None

    def load_book(self, book_path: Path, force_reindex: bool = False) -> None:
        book = load_book(book_path.parent)

        persist_path = get_book_persist_path(book.book_path)
        transformations = build_default_transformations()

        index, nodes = get_or_create_index(
            documents=book.documents,
            persist_path=persist_path,
            transformations=transformations,
            position_system=self._position_system,
            force_reindex=force_reindex,
            callback_manager=Settings.callback_manager,
        )

        self.book = book
        self.index = index
        self.nodes = nodes
        self.position = None

    def set_position(self, snippet: str) -> ReaderPosition:
        if self.book is None:
            raise ValueError("No book loaded.")

        position = self._position_system.resolve_snippet(self.book.documents, snippet)

        if position is None:
            raise ValueError("Could not resolve reader position safely.")

        self.position = position
        return position

    def ask(self, question: str) -> str:
        """Answer a question based on the book up to the current reader position."""
        if self.book is None or self.index is None or self.position is None:
            raise ValueError("Book and reader position must be set before asking.")

        boundary = self.position.as_retrieval_boundary()
        reader_passage = reader_passage_for_llm(self.book.documents, self.position)

        retrieved_nodes_with_scores = retrieve_allowed_nodes(
            index=self.index,
            question=question,
            boundary=boundary,
            similarity_top_k=SIMILARITY_TOP_K,
        )

        return run_query(
            question,
            retrieved_nodes_with_scores,
            llm=self.llm,
            reader_passage=reader_passage or None,
        )
