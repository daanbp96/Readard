from pathlib import Path
from typing import Optional, Sequence

from llama_index.core.llms import LLM
from llama_index.core import Settings, VectorStoreIndex
from llama_index.core.schema import BaseNode

from .book_structure import ResolvedPosition, resolve_position_from_snippet
from .config import SIMILARITY_TOP_K
from .environment import get_book_persist_path
from .index_functions import get_or_create_index
from .loaders import LoadedBook, load_book
from .query import run_query
from .retrieval import retrieve_allowed_nodes
from .transformations import build_default_transformations


class ReadingSession:
    """
    Single-open-book session.

    The intended proof-of-concept flow is:
    load_book(...) -> set_position(...) -> ask(...) (repeat) until the caller closes the book.
    """

    def __init__(self, llm: LLM):
        self.llm = llm

        self.book: Optional[LoadedBook] = None
        self.index: Optional[VectorStoreIndex] = None
        self.nodes: Optional[Sequence[BaseNode]] = None
        self.position: Optional[ResolvedPosition] = None

    def load_book(self, book_path: Path, force_reindex: bool = False) -> None:
        book = load_book(book_path.parent)

        persist_path = get_book_persist_path(book.book_path)
        transformations = build_default_transformations()

        index, nodes = get_or_create_index(
            documents=book.documents,
            persist_path=persist_path,
            transformations=transformations,
            force_reindex=force_reindex,
            callback_manager=Settings.callback_manager,
        )

        self.book = book
        self.index = index
        self.nodes = nodes
        self.position = None

    def set_position(self, snippet: str) -> ResolvedPosition:
        if self.book is None:
            raise ValueError("No book loaded.")

        position = resolve_position_from_snippet(
            self.book.full_book_text,
            snippet,
        )

        if position is None:
            raise ValueError("Could not resolve reader position safely.")

        self.position = position
        return position

    def ask(self, question: str) -> str:
        """Answer a question based on the book up to the current reader position."""
        if self.index is None or self.position is None:
            raise ValueError("Book and reader position must be set before asking.")

        retrieved_nodes_with_scores = retrieve_allowed_nodes(
            index=self.index,
            question=question,
            boundary=self.position.end_char,
            similarity_top_k=SIMILARITY_TOP_K,
        )
        retrieved_nodes = [item.node for item in retrieved_nodes_with_scores]

        if not retrieved_nodes:
            return (
                "I don’t yet know enough based on what you’ve read so far to answer "
                "that without spoilers."
            )

        return run_query(question, retrieved_nodes, llm=self.llm)