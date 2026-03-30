"""Query engine configuration and execution."""
from typing import Sequence

from llama_index.core import VectorStoreIndex
from llama_index.core.base.base_query_engine import BaseQueryEngine
from llama_index.core.response_synthesizers import get_response_synthesizer
from llama_index.core.schema import BaseNode


# Engine configuration
RESPONSE_MODE = "compact"

# Prompt configuration
SYSTEM_PROMPT = "Answer the question based only on the provided context. If you cannot answer from the context, say so."

INSTRUCTION_TEMPLATE = "{question}"


def build_query_engine(index: VectorStoreIndex) -> BaseQueryEngine:
    """Create a query engine with constrained answer behavior."""
    return index.as_query_engine(
        response_mode=RESPONSE_MODE
    )


def run_query(question: str, nodes: Sequence[BaseNode]) -> str:
    """Execute a query against the provided nodes using synthesis.

    Args:
        question: The question to ask
        nodes: The boundary-filtered nodes to synthesize from

    Returns:
        String response synthesized from the provided nodes
    """
    synthesizer = get_response_synthesizer(response_mode=RESPONSE_MODE)
    response = synthesizer.synthesize(question, nodes=nodes)
    return str(response)

