from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

from llama_index.core import SimpleDirectoryReader
from llama_index.core.schema import Document


@dataclass(frozen=True)
class LoadedBook:
    """Container for the loaded EPUB and its derived text."""
    book_path: Path
    documents: Sequence[Document]
    full_book_text: str


def load_book(data_dir: Path) -> LoadedBook:
    """
    Load a single EPUB from the data directory and build its full text.

    Assumptions:
    - exactly one EPUB exists in data_dir
    - loaded documents are already in EPUB reading order
    """
    book_path = _get_single_epub_path(data_dir)
    documents = _load_documents(data_dir)
    full_book_text = _build_full_book_text(documents)

    return LoadedBook(
        book_path=book_path,
        documents=documents,
        full_book_text=full_book_text,
    )


def _get_single_epub_path(data_dir: Path) -> Path:
    """Return the single EPUB file in the data directory."""
    epub_files = sorted(data_dir.glob("*.epub"))

    if not epub_files:
        raise ValueError(f"No EPUB files found in {data_dir}")

    if len(epub_files) > 1:
        raise ValueError(
            f"Expected exactly 1 EPUB file in {data_dir}, found {len(epub_files)}"
        )

    return epub_files[0]


def _load_documents(data_dir: Path) -> Sequence[Document]:
    """Load documents from the configured data directory."""
    documents = SimpleDirectoryReader(
        input_dir=str(data_dir)
    ).load_data()

    if not documents:
        raise ValueError("No documents loaded.")

    return documents


def _build_full_book_text(documents: Sequence[Document]) -> str:
    """
    Concatenate loaded documents into one full-book text string.

    Assumption:
    - documents are already in EPUB reading order
    """
    parts: list[str] = []

    for doc in documents:
        text = doc.text.strip()
        if text:
            parts.append(text)

    if not parts:
        raise ValueError("No usable text found in loaded documents.")

    return "\n\n".join(parts)