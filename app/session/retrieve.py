from llama_index.core import VectorStoreIndex
from llama_index.core.schema import NodeWithScore
from llama_index.core.vector_stores import (
    MetadataFilter,
    MetadataFilters,
    FilterOperator,
)

from ..book import ReaderBoundary


def retrieve_allowed_nodes(
    index: VectorStoreIndex,
    question: str,
    boundary: ReaderBoundary,
    similarity_top_k: int = 5,
) -> list[NodeWithScore]:
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

    return filtered_nodes
