from dataclasses import dataclass
import re
from typing import Optional


@dataclass(frozen=True)
class ResolvedPosition:
    """Resolved reader position in the normalized full book text."""
    snippet: str
    normalized_snippet: str
    start_char: int
    end_char: int


def normalize_text(text: str) -> str:
    """
    Normalize text for matching.

    Current rules:
    - lowercase
    - collapse all whitespace to single spaces
    - strip leading/trailing whitespace
    """
    text = text.lower()
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def resolve_position_from_snippet(
    full_book_text: str,
    snippet: str,
) -> Optional[ResolvedPosition]:
    """
    Resolve a reader's last-read snippet against the normalized full book text.

    Returns:
        ResolvedPosition if exactly one match is found.
        None if no match is found or if the match is ambiguous.
    """
    normalized_book = normalize_text(full_book_text)
    normalized_snippet = normalize_text(snippet)

    if not normalized_snippet:
        return None

    matches = []
    start = 0

    while True:
        idx = normalized_book.find(normalized_snippet, start)
        if idx == -1:
            break
        matches.append(idx)
        start = idx + 1

    if len(matches) != 1:
        return None

    match_start = matches[0]
    match_end = match_start + len(normalized_snippet)

    return ResolvedPosition(
        snippet=snippet,
        normalized_snippet=normalized_snippet,
        start_char=match_start,
        end_char=match_end,
    )