from uuid import uuid4

from llama_index.core import Settings, VectorStoreIndex
from llama_index.core.schema import NodeWithScore, TextNode
from llama_index.core.vector_stores import (
    MetadataFilter,
    MetadataFilters,
    FilterOperator,
)

from ..index.boundary import ReaderBoundary


def _merge_partial_chunk_text(
    question: str,
    partial_chunk_text: str,
    retrieved: list[NodeWithScore],
    top_k: int,
) -> list[NodeWithScore]:
    embed = Settings.embed_model
    q_emb = embed.get_query_embedding(question)
    doc_emb = embed.get_text_embedding(partial_chunk_text)
    score = embed.similarity(q_emb, doc_emb)

    node = TextNode(
        text=partial_chunk_text,
        id_=f"readtard-partial-chunk-{uuid4().hex}",
        metadata={"readtard_role": "partial_chunk"},
    )
    combined = list[NodeWithScore](retrieved) + [NodeWithScore(node=node, score=score)]
    combined.sort(key=lambda ns: ns.score, reverse=True)
    return combined[:top_k]


def retrieve_allowed_nodes(
    index: VectorStoreIndex,
    question: str,
    boundary: ReaderBoundary,
    similarity_top_k: int = 5,
    *,
    partial_chunk_text: str | None = None,
) -> list[NodeWithScore]:
    """
    Filtered vector search up to ``boundary``.

    If ``partial_chunk_text`` is set, embed it with ``Settings.embed_model`` and merge
    with the filtered hits by score.
    """
    filters = MetadataFilters(
        filters=[
            MetadataFilter(
                key=boundary.end_metadata_key,
                value=boundary.lte_value,
                operator=FilterOperator.LTE,
            )
        ]
    )

    filtered_retriever = index.as_retriever(
        similarity_top_k=similarity_top_k,
        filters=filters,
    )
    filtered_nodes = filtered_retriever.retrieve(question)

    if partial_chunk_text and partial_chunk_text.strip():
        return _merge_partial_chunk_text(
            question,
            partial_chunk_text.strip(),
            filtered_nodes,
            similarity_top_k,
        )
    return filtered_nodes
