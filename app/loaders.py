from dataclasses import dataclass
import hashlib
from pathlib import Path
from typing import Sequence

from ebooklib import epub
from ebooklib.utils import parse_html_string
from llama_index.core.schema import Document

from .config import EXTRACTION_VERSION


@dataclass(frozen=True)
class LoadedBook:
    """Container for the loaded EPUB and its derived text."""
    book_path: Path
    documents: Sequence[Document]
    full_book_text: str


def load_book(data_dir: Path) -> LoadedBook:
    """
    Load a single EPUB from the data directory and build its full text.

    Documents are emitted in **OPF spine order** (canonical EPUB reading order).
    """
    book_path = _get_single_epub_path(data_dir)
    documents = _load_documents_from_epub(book_path)
    _annotate_documents_with_book_coordinates(documents, book_path)
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


def _load_documents_from_epub(book_path: Path) -> Sequence[Document]:
    """Load one LlamaIndex Document per spine HTML item, in spine order."""
    epub_book = epub.read_epub(str(book_path))
    documents: list[Document] = []

    for spine_idx, spine_entry in enumerate(epub_book.spine):
        idref = spine_entry[0]
        linear = spine_entry[1] if len(spine_entry) > 1 else "yes"

        item = epub_book.get_item_with_id(idref)
        if item is None:
            continue

        if not isinstance(item, epub.EpubHtml):
            continue

        if isinstance(item, epub.EpubNav):
            continue

        if isinstance(item, epub.EpubCoverHtml):
            continue

        plain = _epub_html_to_plain_text(item)
        plain = plain.strip()
        if not plain:
            continue

        href = item.get_name()
        doc_id = f"spine-{spine_idx}-{href}"

        documents.append(
            Document(
                text=plain,
                id_=doc_id,
                metadata={
                    "file_name": href,
                    "spine_idx": spine_idx,
                    "spine_href": href,
                    "spine_linear": linear,
                },
            )
        )

    if not documents:
        raise ValueError("No usable text extracted from EPUB spine.")

    return documents


def _epub_html_to_plain_text(item: epub.EpubHtml) -> str:
    """Extract visible text from an XHTML spine item (body only)."""
    if not item.content:
        return ""

    try:
        tree = parse_html_string(item.content)
    except Exception:
        return ""

    bodies = tree.xpath("//*[local-name()='body']")
    if not bodies:
        return ""

    body = bodies[0]
    parts: list[str] = []
    for t in body.xpath(".//text()"):
        s = (t or "").strip()
        if s:
            parts.append(s)
    return " ".join(parts)


def _build_full_book_text(documents: Sequence[Document]) -> str:
    """
    Concatenate loaded documents into one full-book text string.

    Documents are in spine order.
    """
    parts: list[str] = []

    for doc in documents:
        text = doc.text.strip()
        if text:
            parts.append(text)

    if not parts:
        raise ValueError("No usable text found in loaded documents.")

    return "\n\n".join(parts)


def _annotate_documents_with_book_coordinates(
    documents: Sequence[Document],
    book_path: Path,
) -> None:
    """Attach deterministic book-level coordinates and version metadata."""
    book_hash = _sha256_file(book_path)
    book_id = f"sha256:{book_hash}"

    cursor = 0
    for doc in documents:
        text = doc.text.strip()
        text_len = len(text)

        start = cursor
        end = cursor + text_len

        doc.metadata["book_id"] = book_id
        doc.metadata["book_version"] = book_id
        doc.metadata["extraction_version"] = EXTRACTION_VERSION
        doc.metadata["global_char_start"] = start
        doc.metadata["global_char_end"] = end
        # spine_idx / spine_href already set in _load_documents_from_epub

        if text_len > 0:
            cursor = end + 2  # mirrors "\n\n" join in _build_full_book_text


def _sha256_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as infile:
        for chunk in iter(lambda: infile.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()
