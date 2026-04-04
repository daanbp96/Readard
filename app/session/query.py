from typing import Sequence

from llama_index.core.llms import LLM
from llama_index.core.response_synthesizers import (
    ResponseMode,
    get_response_synthesizer,
)
from llama_index.core.schema import NodeWithScore


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


def run_query(
    question: str,
    nodes: Sequence[NodeWithScore],
    llm: LLM,
    context: str,
) -> str:
    """Synthesize an answer from retrieval hits, optionally with a local reader passage prepended.

    When retrieval is empty but ``reader_passage`` is set, answers from the passage only
    via a direct completion (no vector hits).
    """
    passage_block = context.strip()
    passage_block = (
        "Passage near the reader's current position (for questions about "
        '"this" scene or who "they" refers to):\n---\n'
        f"{context.strip()}\n---\n\n"
    )

    user_block = f"User question (answer without future spoilers):\n{question}"
    spoiler_aware_question = f"{SYSTEM_PROMPT}\n\n{passage_block}{user_block}"

    if not nodes:
        if context:
            return str(llm.complete(spoiler_aware_question))
        return (
            "I don’t yet know enough based on what you’ve read so far to answer "
            "that without spoilers."
        )

    synthesizer = get_response_synthesizer(response_mode=RESPONSE_MODE, llm=llm)
    response = synthesizer.synthesize(spoiler_aware_question, nodes=nodes)
    return str(response)