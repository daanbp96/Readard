"""Configuration for the reading pipeline."""

# Document chunking
CHUNK_SIZE = 1024
CHUNK_OVERLAP = 200

# Node retrieval
SIMILARITY_TOP_K = 5

# Local text around the reader position (for deictic questions: "what are they talking about").
READER_CONTEXT_CHARS_BEFORE = 400
READER_CONTEXT_CHARS_AFTER = 50

# LLM configuration
LLM_PROVIDER = "openai"
OPENAI_MODEL = "gpt-3.5-turbo"
