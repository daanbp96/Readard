from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

from ebooklib import epub
from ebooklib.utils import parse_html_string
from llama_index.core.schema import Document


@dataclass(frozen=True)
class LoadedBook:
    """Container for the loaded EPUB and its derived text."""
    book_path: Path
    documents: Sequence[Document]


def load_book(data_dir: Path) -> LoadedBook:
    """
    Load a single EPUB from the data directory and build documents.

    Documents are emitted in **OPF spine order** (canonical EPUB reading order).
    """
    book_path = _get_single_epub_path(data_dir)
    documents = _load_documents_from_epub(book_path)

    return LoadedBook(
        book_path=book_path,
        documents=documents,
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
        if not plain.strip():
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
                },
            )
        )

    if not documents:
        raise ValueError("No usable text extracted from EPUB spine.")

    return documents


def _epub_html_to_plain_text(item: epub.EpubHtml) -> str:
    """
    Body text in document order: non-empty stripped text nodes, joined with spaces.

    Same flattening rules must be used anywhere you map a character offset into ``doc.text``.
    """
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

    if not parts:
        return ""

    return " ".join(parts)
