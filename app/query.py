from typing import Sequence

from llama_index.core.llms import LLM
from llama_index.core.response_synthesizers import (
    ResponseMode,
    get_response_synthesizer,
)
from llama_index.core.schema import BaseNode


# Engine configuration
RESPONSE_MODE = ResponseMode.COMPACT

# Prompt configuration
SYSTEM_PROMPT = (
    "You are a careful reading companion. Answer the question based only on the "
    "provided context, which covers events up to the reader's current position in "
    "the book. If the question requires knowledge of events that happen later in the "
    "story, explicitly say that you cannot answer without revealing spoilers, and do "
    "not reveal those spoilers."
)

INSTRUCTION_TEMPLATE = "{question}"


def run_query(question: str, nodes: Sequence[BaseNode], llm: LLM) -> str:
    """Execute a query against the provided nodes using synthesis.

    Args:
        question: The question to ask
        nodes: The boundary-filtered nodes to synthesize from
        llm: Explicit LLM instance used for synthesis

    Returns:
        String response synthesized from the provided nodes
    """
    spoiler_aware_question = (
        f"{SYSTEM_PROMPT}\n\nUser question (answer without future spoilers):\n"
        f"{question}"
    )

    synthesizer = get_response_synthesizer(response_mode=RESPONSE_MODE, llm=llm)
    response = synthesizer.synthesize(spoiler_aware_question, nodes=nodes)
    return str(response)

