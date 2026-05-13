from pathlib import Path
from typing import Sequence

from llama_index.core.llms import LLM
from llama_index.core import Settings, VectorStoreIndex
from llama_index.core.schema import BaseNode

from ..book import LoadedBook, load_book
from ..book.context import create_context_for_question
from ..book.position import ResolvedPosition, resolve_position_from_snippet
from ..index.boundary import reader_boundary_for_resolved
from ..config import READER_CONTEXT_CHARS_BEFORE, SIMILARITY_TOP_K
from ..environment import get_book_persist_path
from ..index import build_default_transformations, get_or_create_index
from .partial_chunk import partial_text_in_covering_chunk
from .query import run_query
from .retrieve import retrieve_allowed_nodes


class ReadingSession:
    """
    Single-open-book session.

    Flow: ``load_book`` → ``set_position`` (snippet) → ``ask`` (repeat).
    """

    def __init__(
        self,
        llm: LLM,
        ):
        self.llm = llm

        self.book: LoadedBook
        self.index: VectorStoreIndex
        self.nodes: Sequence[BaseNode]
        self.position: ResolvedPosition

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

    def set_position(self, snippet: str) -> ResolvedPosition:
        self.position = resolve_position_from_snippet(self.book.documents, snippet)
        return self.position

    def set_resolved_position(self, position: ResolvedPosition) -> ResolvedPosition:
        """Set the reader position directly from an external resolver."""
        self.position = position
        return self.position

    def ask(self, question: str) -> str:
        """Answer a question based on the book up to the current reader position."""
        boundary = reader_boundary_for_resolved(self.position)
        context = create_context_for_question(self.book.documents, self.position)

        partial = partial_text_in_covering_chunk(
            self.nodes,
            self.position.spine_idx,
            self.position.local_plain_offset,
        )
        partial_chunk_text = None
        if len(partial) > READER_CONTEXT_CHARS_BEFORE:
            partial_chunk_text = partial

        retrieved_nodes_with_scores = retrieve_allowed_nodes(
            index=self.index,
            question=question,
            boundary=boundary,
            similarity_top_k=SIMILARITY_TOP_K,
            partial_chunk_text=partial_chunk_text,
        )

        return run_query(
            question,
            retrieved_nodes_with_scores,
            llm=self.llm,
            context=context,
        )
