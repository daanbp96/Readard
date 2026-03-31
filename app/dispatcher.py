from pathlib import Path
from typing import Dict, Optional, Sequence

from llama_index.core.llms import LLM
from llama_index.core import Settings, VectorStoreIndex
from llama_index.core.schema import BaseNode

from loaders import load_book, LoadedBook
from environment import get_book_persist_path
from transformations import build_default_transformations
from index_functions import get_or_create_index
from book_structure import resolve_position_from_snippet, ResolvedPosition
from retrieval import retrieve_allowed_nodes
from query import run_query
from config import SIMILARITY_TOP_K


class ReadingSession:

    def __init__(self, llm: LLM):
        self.llm = llm

        self.books: Dict[str, LoadedBook] = {}
        self.indexes: Dict[str, VectorStoreIndex] = {}
        self.positions: Dict[str, ResolvedPosition] = {}
        self.nodes: Dict[str, Sequence[BaseNode]] = {}
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


    def ask(self, question: str) -> str:
        """Answer a question based on the book up to the current reader position."""
        if self.active_book_id is None:
            raise ValueError("No active book selected.")

        if self.active_book_id not in self.positions:
            raise ValueError("Reader position not set.")

        index = self.indexes[self.active_book_id]
        boundary = self.positions[self.active_book_id].end_char

        retrieved_nodes_with_scores = retrieve_allowed_nodes(
            index=index,
            question=question,
            boundary=boundary,
            similarity_top_k=SIMILARITY_TOP_K,
        )
        retrieved_nodes = [item.node for item in retrieved_nodes_with_scores]

        if not retrieved_nodes:
            return (
                "I don’t yet know enough based on what you’ve read so far to answer "
                "that without spoilers."
            )

        return run_query(question, retrieved_nodes, llm=self.llm)