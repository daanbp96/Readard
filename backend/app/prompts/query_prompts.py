from llama_index.core import PromptTemplate


def build_retrieval_text_qa_template(context: str) -> PromptTemplate:
    """Template for retrieval-grounded answers.

    Retrieved nodes are the primary evidence.
    The local passage is only for resolving local references such as
    "this", "he", "she", "they", "here", or "in this scene".
    """
    cleaned_context = context.strip()

    passage_block = ""
    if cleaned_context:
        passage_block = (
            "Local passage (use only to resolve local references like "
            '"this", "he", "she", "they", "here", or "in this scene"):\n'
            "---------------------\n"
            f"{cleaned_context}\n"
            "---------------------\n\n"
        )

    template = (
        "Retrieved evidence is below.\n"
        "---------------------\n"
        "{context_str}\n"
        "---------------------\n\n"
        f"{passage_block}"
        "Instructions:\n"
        "- Answer using the retrieved evidence as the primary basis.\n"
        "- Use the local passage only to resolve local references.\n"
        "- Do not use outside knowledge.\n"
        "- If the retrieved evidence is insufficient, say so.\n"
        "- If answering would require later events in the story, say that you "
        "cannot answer without spoilers.\n\n"
        "User question: {query_str}\n"
        "Answer:"
    )
    return PromptTemplate(template)


def build_retrieval_refine_template(context: str) -> PromptTemplate:
    """Template used when the synthesizer refines across multiple chunks."""
    cleaned_context = context.strip()

    passage_block = ""
    if cleaned_context:
        passage_block = (
            "Local passage (use only to resolve local references like "
            '"this", "he", "she", "they", "here", or "in this scene"):\n'
            "---------------------\n"
            f"{cleaned_context}\n"
            "---------------------\n\n"
        )

    template = (
        "The original user question is: {query_str}\n"
        "An existing answer is: {existing_answer}\n\n"
        "Additional retrieved evidence is below.\n"
        "---------------------\n"
        "{context_msg}\n"
        "---------------------\n\n"
        f"{passage_block}"
        "Instructions:\n"
        "- Refine the existing answer only if the new retrieved evidence helps.\n"
        "- Retrieved evidence remains the primary basis.\n"
        "- Use the local passage only to resolve local references.\n"
        "- Do not use outside knowledge.\n"
        "- If the evidence is still insufficient, say so.\n"
        "- If answering would require later events in the story, say that you "
        "cannot answer without spoilers.\n\n"
        "Refined answer:"
    )
    return PromptTemplate(template)


def build_passage_only_prompt(question: str, context: str) -> str:
    """Prompt for passage-only mode when retrieval returns no nodes."""
    cleaned_context = context.strip()

    return (
        "Local passage is below.\n"
        "---------------------\n"
        f"{cleaned_context}\n"
        "---------------------\n\n"
        "Instructions:\n"
        "- Answer using only the local passage above.\n"
        "- Do not use outside knowledge.\n"
        "- Do not infer facts not supported by the passage.\n"
        "- If the passage is insufficient, say so.\n"
        "- If answering would require later events in the story, say that you "
        "cannot answer without spoilers.\n\n"
        f"User question: {question}\n"
        "Answer:"
    )