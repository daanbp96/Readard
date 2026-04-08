"""Local CLI demo (no HTTP). Run: ``python -m app.demo``."""

from app.config import LLM_PROVIDER, OPENAI_MODEL
from app.environment import initialize_environment
from app.library.books import get_epub_path
from app.llm import create_llm
from app.session import ReadingSession

# Pick any folder under data/books/<id>/ that contains exactly one .epub
DEMO_BOOK_ID = "hp_philosophers_stone"

LAST_READ_SENTENCE = "I bet he asked Dumbledore to keep it safe for him"
QUERY = "what happens in the fourth chapter of the book?"


def main() -> None:
    initialize_environment()

    llm = create_llm(model=OPENAI_MODEL, provider=LLM_PROVIDER)
    session = ReadingSession(llm=llm)

    session.load_book(get_epub_path(DEMO_BOOK_ID), force_reindex=True)
    session.set_position(LAST_READ_SENTENCE)

    print(session.ask(QUERY))


if __name__ == "__main__":
    main()
