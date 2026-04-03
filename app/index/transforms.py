from llama_index.core import Settings
from llama_index.core.node_parser import SentenceSplitter

from ..config import CHUNK_OVERLAP, CHUNK_SIZE


def build_default_transformations():
    """Return the default transformation pipeline for ingestion."""

    callback_manager = Settings.callback_manager

    splitter = SentenceSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP,
        include_metadata=True,
        include_prev_next_rel=True,
        callback_manager=callback_manager,
    )

    return [splitter]
