# Document chunking
from operator import index


CHUNK_SIZE = 1024
CHUNK_OVERLAP = 200

# Node retrieval
SIMILARITY_TOP_K = 5

READER_CONTEXT_CHARS_BEFORE = 400
READER_CONTEXT_CHARS_AFTER = 50

# LLM configuration
LLM_PROVIDER = "openai"
OPENAI_MODEL = "gpt-4.1-mini"
TEMPERATURE = 1.0

