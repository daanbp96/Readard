"""Layout: ``data/books/<book_id>/*.epub`` (exactly one EPUB per directory)."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from app.environment import DATA_DIR

BOOKS_ROOT = DATA_DIR / "books"

# Safe id for directory names (no path traversal)
_BOOK_ID_RE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._-]*$")


@dataclass(frozen=True)
class BookRecord:
    """``id`` is what clients send (bundle folder name or alias); ``directory_id`` is ``data/books/<dir>/``."""

    id: str
    directory_id: str
    epub_filename: str
    title: str | None


def validate_book_id(book_id: str) -> str:
    """Reject empty, unsafe, or path-like ids (directory name under ``books/``)."""
    if not book_id or not _BOOK_ID_RE.match(book_id):
        raise ValueError(f"Invalid book_id: {book_id!r}")
    return book_id


def _single_epub_in_dir(book_dir: Path) -> Path:
    epubs = sorted(book_dir.glob("*.epub"))
    if not epubs:
        raise ValueError(f"No EPUB in {book_dir}")
    if len(epubs) > 1:
        raise ValueError(f"Expected exactly one *.epub in {book_dir}, found {len(epubs)}")
    return epubs[0]


def _read_book_metadata(book_dir: Path) -> dict[str, Any]:
    meta_path = book_dir / "metadata.json"
    if not meta_path.is_file():
        return {}
    try:
        raw = json.loads(meta_path.read_text(encoding="utf-8"))
        return raw if isinstance(raw, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def _optional_title(book_dir: Path) -> str | None:
    data = _read_book_metadata(book_dir)
    title = data.get("title")
    return title if isinstance(title, str) and title.strip() else None


def _load_book_aliases_file() -> dict[str, str]:
    """Map client-facing id -> canonical directory name under ``books/``."""
    path = BOOKS_ROOT / "book_aliases.json"
    if not path.is_file():
        return {}
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(raw, dict):
        return {}
    out: dict[str, str] = {}
    for k, v in raw.items():
        if isinstance(k, str) and isinstance(v, str) and k.strip() and v.strip():
            out[k.strip()] = v.strip()
    return out


def _client_ids_from_metadata(data: dict[str, Any]) -> list[str]:
    out: list[str] = []
    raw = data.get("client_book_ids")
    if isinstance(raw, list):
        for x in raw:
            if isinstance(x, str) and x.strip():
                out.append(x.strip())
    one = data.get("client_book_id")
    if isinstance(one, str) and one.strip():
        out.append(one.strip())
    return out


def resolve_to_directory_id(book_id: str) -> str:
    """Map a client ``book_id`` (bundle name or alias) to ``data/books/<dir>/`` folder name."""
    validate_book_id(book_id)
    direct = BOOKS_ROOT / book_id
    if direct.is_dir():
        return book_id

    aliases = _load_book_aliases_file()
    if book_id in aliases:
        target = aliases[book_id]
        if (BOOKS_ROOT / target).is_dir():
            return target

    if not BOOKS_ROOT.is_dir():
        raise FileNotFoundError(f"Unknown book_id (no directory): {book_id}")

    for child in sorted(BOOKS_ROOT.iterdir()):
        if not child.is_dir():
            continue
        meta = _read_book_metadata(child)
        for cid in _client_ids_from_metadata(meta):
            if cid == book_id:
                return child.name

    raise FileNotFoundError(f"Unknown book_id (no directory): {book_id}")


def _display_id_for_directory(canonical_dir: str) -> str:
    """Prefer client_book_ids from metadata, then book_aliases.json key, else folder name."""
    book_dir = BOOKS_ROOT / canonical_dir
    meta = _read_book_metadata(book_dir)
    client_ids = _client_ids_from_metadata(meta)
    if client_ids:
        return client_ids[0]

    aliases = _load_book_aliases_file()
    for client_key, target in sorted(aliases.items()):
        if target == canonical_dir:
            return client_key

    return canonical_dir


def get_epub_path(book_id: str) -> Path:
    """Absolute path to the EPUB file for ``book_id`` (after alias / metadata resolution)."""
    directory_id = resolve_to_directory_id(book_id)
    book_dir = BOOKS_ROOT / directory_id
    epub = _single_epub_in_dir(book_dir)
    return epub


def list_books() -> list[BookRecord]:
    """Scan ``data/books/*/`` for valid single-EPUB directories."""
    if not BOOKS_ROOT.is_dir():
        return []
    out: list[BookRecord] = []
    for child in sorted(BOOKS_ROOT.iterdir()):
        if not child.is_dir():
            continue
        bid = child.name
        if not _BOOK_ID_RE.match(bid):
            continue
        try:
            epub = _single_epub_in_dir(child)
        except ValueError:
            continue
        display_id = _display_id_for_directory(bid)
        out.append(
            BookRecord(
                id=display_id,
                directory_id=bid,
                epub_filename=epub.name,
                title=_optional_title(child),
            )
        )
    return out
