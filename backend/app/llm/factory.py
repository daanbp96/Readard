from llama_index.llms.openai import OpenAI

from ..config import TEMPERATURE, MAX_TOKENS, STRICT
from ..llm.system_prompts import READING_SYSTEM_PROMPT


def create_llm(model: str, provider: str = "openai"):
    """Create a configured LLM instance for the selected provider."""
    normalized_provider = provider.strip().lower()

    if normalized_provider == "openai":
        return OpenAI(
            model=model,
            temperature=TEMPERATURE,
            max_tokens=MAX_TOKENS,
            strict=STRICT,
            system_prompt=READING_SYSTEM_PROMPT,
        )

    raise ValueError(f"Unsupported LLM provider: {provider}")