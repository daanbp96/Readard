from app.config import LLM_PROVIDER, OPENAI_MODEL
from app.session import ReadingSession
from app.environment import DATA_DIR, initialize_environment
from app.llm import create_llm


BOOK_NAME = "Harry Potter and the Sorcerer's Stone.epub"
LAST_READ_SENTENCE = "I bet he asked Dumbledore to keep it safe for him"
QUERY = "what are they talking about? Who is him?"


def main() -> None:
    initialize_environment()

    llm = create_llm(model=OPENAI_MODEL, provider=LLM_PROVIDER)
    session = ReadingSession(llm=llm)

    session.load_book(DATA_DIR / BOOK_NAME, force_reindex=True)
    session.set_position(LAST_READ_SENTENCE)

    print(session.ask(QUERY))


if __name__ == "__main__":
    main()
