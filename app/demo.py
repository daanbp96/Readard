"""Local CLI demo (no HTTP). Run: ``python -m app.demo``."""

from app.config import BOOK_FILENAME, LLM_PROVIDER, OPENAI_MODEL
from app.environment import DATA_DIR, initialize_environment
from app.llm import create_llm
from app.session import ReadingSession


LAST_READ_SENTENCE = "I bet he asked Dumbledore to keep it safe for him"
QUERY = "what happens in the fourth chapter of the book?"


def main() -> None:
    initialize_environment()

    llm = create_llm(model=OPENAI_MODEL, provider=LLM_PROVIDER)
    session = ReadingSession(llm=llm)

    session.load_book(DATA_DIR / BOOK_FILENAME, force_reindex=True)
    session.set_position(LAST_READ_SENTENCE)

    print(session.ask(QUERY))


if __name__ == "__main__":
    main()
