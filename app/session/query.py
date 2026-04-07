from typing import Sequence

from llama_index.core.response_synthesizers import (
    ResponseMode,
    get_response_synthesizer,
)
from llama_index.core.llms import LLM
from llama_index.core.schema import NodeWithScore

from app.prompts.query_prompts import (
    build_passage_only_prompt,
    build_retrieval_refine_template,
    build_retrieval_text_qa_template,
)


RESPONSE_MODE = ResponseMode.COMPACT


def run_query(
    question: str,
    nodes: Sequence[NodeWithScore],
    llm: LLM,
    context: str,
) -> str:
    """Answer a spoiler-safe reading question.

    Modes:
    - If retrieval returned nodes, answer from retrieved evidence, using the
      local passage only to resolve references like "this", "he", or "here".
    - If retrieval returned no nodes, answer only from the local passage.
    """
    cleaned_context = context.strip()

    if nodes:
        synthesizer = get_response_synthesizer(
            response_mode=RESPONSE_MODE,
            llm=llm,
            text_qa_template=build_retrieval_text_qa_template(cleaned_context),
            refine_template=build_retrieval_refine_template(cleaned_context),
        )
        response = synthesizer.synthesize(question, nodes=nodes)
        return str(response)

    prompt = build_passage_only_prompt(question=question, context=cleaned_context)
    return str(llm.complete(prompt))