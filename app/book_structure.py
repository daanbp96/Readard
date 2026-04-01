from dataclasses import dataclass
import re
from typing import Optional


@dataclass(frozen=True)
class ResolvedPosition:
    """Resolved reader position in original full-book character coordinates."""
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
    Resolve a reader snippet and return original-string character coordinates.

    Returns:
        ResolvedPosition if exactly one match is found.
        None if no match is found or if the match is ambiguous.
    """
    normalized_snippet = normalize_text(snippet)

    if not normalized_snippet:
        return None

    token_pattern = _normalized_snippet_to_pattern(normalized_snippet)
    matches = list(re.finditer(token_pattern, full_book_text, flags=re.IGNORECASE))

    if len(matches) != 1:
        return None

    match_start = matches[0].start()
    match_end = matches[0].end()

    return ResolvedPosition(
        snippet=snippet,
        normalized_snippet=normalized_snippet,
        start_char=match_start,
        end_char=match_end,
    )


def _normalized_snippet_to_pattern(normalized_snippet: str) -> str:
    tokens = [re.escape(token) for token in normalized_snippet.split(" ") if token]
    if not tokens:
        return r"$a"  # impossible match
    return r"\s+".join(tokens)