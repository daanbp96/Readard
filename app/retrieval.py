from llama_index.core import VectorStoreIndex
from llama_index.core.vector_stores import (
    MetadataFilter,
    MetadataFilters,
    FilterOperator,
)


def retrieve_allowed_nodes(
    index: VectorStoreIndex,
    question: str,
    boundary: int,
    similarity_top_k: int = 5,
):
    unfiltered_retriever = index.as_retriever(
        similarity_top_k=similarity_top_k,
    )
    unfiltered_nodes = unfiltered_retriever.retrieve(question)

    filters = MetadataFilters(
        filters=[
            MetadataFilter(
                key="end_char_idx",
                value=boundary,
                operator=FilterOperator.LTE,
            )
        ]
    )

    filtered_retriever = index.as_retriever(
        similarity_top_k=similarity_top_k,
        filters=filters,
    )
    filtered_nodes = filtered_retriever.retrieve(question)

    return filtered_nodes