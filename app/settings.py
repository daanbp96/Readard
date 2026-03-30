from pathlib import Path

from dotenv import load_dotenv
from llama_index.core import Settings


def initialize_environment() -> None:
    """Load environment variables and initialize global settings."""
    load_dotenv()



BASE_DIR = Path("/Users/daanbarsukoffponiatowsky/Projects/Readtard")
DATA_DIR = BASE_DIR / "data"
PERSIST_DIR = BASE_DIR / "persist_dir"


def get_book_persist_path(book_path: Path) -> Path:
    """Return the persist directory for a specific book."""
    book_id = book_path.stem.lower().replace(" ", "_")
    return PERSIST_DIR / book_id