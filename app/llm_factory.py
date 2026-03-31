from llama_index.llms.openai import OpenAI


def create_llm(model: str, provider: str = "openai"):
    """Create a configured LLM instance for the selected provider."""
    normalized_provider = provider.strip().lower()

    if normalized_provider == "openai":
        return OpenAI(model=model)

    raise ValueError(f"Unsupported LLM provider: {provider}")

