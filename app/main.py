from pathlib import Path

from dispatcher import ReadingSession
from settings import (
    DATA_DIR,
    initialize_environment,
)


BOOK_NAME = "Harry Potter and the Sorcerer's Stone.epub"
LAST_READ_SENTENCE = "I bet he asked Dumbledore to keep it safe for him"
QUERY = "why did snape die? explain it to me like i am 85"


initialize_environment()

session = ReadingSession()

book_id = session.load_book(DATA_DIR / BOOK_NAME, force_reindex=False)

session.set_position(LAST_READ_SENTENCE)

session.build_engine()

print(session.ask(QUERY))