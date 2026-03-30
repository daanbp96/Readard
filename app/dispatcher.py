from pathlib import Path
from typing import Dict, Optional, Sequence

from llama_index.core import Settings, VectorStoreIndex
from llama_index.core.schema import BaseNode

from loaders import load_book, LoadedBook
from settings import get_book_persist_path
from transformations import build_default_transformations
from index_functions import get_or_create_index
from book_structure import resolve_position_from_snippet, ResolvedPosition
from retrieval import retrieve_allowed_nodes
from query import build_query_engine, run_query
from config import SIMILARITY_TOP_K


class ReadingSession:

    def __init__(self):

        self.books: Dict[str, LoadedBook] = {}
        self.indexes: Dict[str, VectorStoreIndex] = {}
        self.positions: Dict[str, ResolvedPosition] = {}
        self.nodes: Dict[str, Sequence[BaseNode]] = {}
        self.query_engine = None
        self.active_book_id: Optional[str] = None


    def load_book(self, book_path: Path, force_reindex: bool = False) -> str:

        book = load_book(book_path.parent)

        book_id = book.book_path.stem.lower()

        persist_path = get_book_persist_path(book.book_path)

        transformations = build_default_transformations()

        index, nodes = get_or_create_index(
            documents=book.documents,
            persist_path=persist_path,
            transformations=transformations,
            force_reindex=force_reindex,
            callback_manager=Settings.callback_manager,
        )

        self.books[book_id] = book
        self.indexes[book_id] = index

        self.nodes[book_id] = nodes

        self.active_book_id = book_id

        return book_id


    def open_book(self, book_id: str):

        if book_id not in self.books:
            raise ValueError(f"Book '{book_id}' not loaded.")

        self.active_book_id = book_id


    def set_position(self, snippet: str) -> ResolvedPosition:

        if self.active_book_id is None:
            raise ValueError("No active book selected.")

        book = self.books[self.active_book_id]

        position = resolve_position_from_snippet(
            book.full_book_text,
            snippet,
        )

        if position is None:
            raise ValueError("Could not resolve reader position safely.")

        self.positions[self.active_book_id] = position

        return position


    def build_engine(self) -> None:
        """Build query engine for the current index."""
        if self.active_book_id is None:
            raise ValueError("No active book selected.")

        if self.active_book_id not in self.indexes:
            raise RuntimeError("Index unavailable.")

        index = self.indexes[self.active_book_id]
        self.query_engine = build_query_engine(index)


    def ask(self, question: str) -> str:
        """Answer a question based on the book up to the current reader position."""
        if self.active_book_id is None:
            raise ValueError("No active book selected.")

        if self.active_book_id not in self.positions:
            raise ValueError("Reader position not set.")

        if self.query_engine is None:
            raise RuntimeError("Query engine not built. Call build_engine() first.")

        index = self.indexes[self.active_book_id]
        boundary = self.positions[self.active_book_id].end_char

        retrieved_nodes = retrieve_allowed_nodes(
            index=index,
            question=question,
            boundary=boundary,
            similarity_top_k=SIMILARITY_TOP_K,
        )

        if not retrieved_nodes:
            raise RuntimeError("No allowed nodes before reader position.")

        return run_query(self.query_engine, question)