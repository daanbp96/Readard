from app.config import LLM_PROVIDER, OPENAI_MODEL
from app.dispatcher import ReadingSession
from app.environment import DATA_DIR, initialize_environment
from app.llm_factory import create_llm


BOOK_NAME = "Harry Potter and the Sorcerer's Stone.epub"
LAST_READ_SENTENCE = "I bet he asked Dumbledore to keep it safe for him"
QUERY = "why did snape die? explain it to me like i am 85"


def main() -> None:
    initialize_environment()

    llm = create_llm(model=OPENAI_MODEL, provider=LLM_PROVIDER)
    session = ReadingSession(llm=llm)

    session.load_book(DATA_DIR / BOOK_NAME, force_reindex=False)

    session.set_position(LAST_READ_SENTENCE)

    print(session.ask(QUERY))


if __name__ == "__main__":
    main()
