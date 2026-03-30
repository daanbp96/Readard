from pathlib import Path
from typing import Optional, Sequence, Tuple, cast

from llama_index.core import (
    Settings,
    StorageContext,
    VectorStoreIndex,
    load_index_from_storage,
)
from llama_index.core.callbacks import CallbackManager
from llama_index.core.ingestion import IngestionPipeline
from llama_index.core.schema import BaseNode, Document
from llama_index.core.storage.docstore import SimpleDocumentStore
from llama_index.core.storage.index_store import SimpleIndexStore
from llama_index.core.vector_stores import SimpleVectorStore


def get_or_create_index(
    documents: Optional[Sequence[Document]],
    persist_path: Path,
    transformations,
    force_reindex: bool = False,
    callback_manager: Optional[CallbackManager] = None,
) -> Tuple[VectorStoreIndex, Sequence[BaseNode]]:
    """Load an existing index or create a new one from documents."""

    if _can_load_index(persist_path) and not force_reindex:
        return _load_index_with_nodes(persist_path)

    if documents is None:
        raise ValueError("Documents must be provided when creating a new index.")

    return _create_index(
        documents=documents,
        persist_path=persist_path,
        transformations=transformations,
        callback_manager=callback_manager or Settings.callback_manager,
    )


def _create_index(
    documents: Sequence[Document],
    persist_path: Path,
    transformations,
    callback_manager: CallbackManager,
) -> Tuple[VectorStoreIndex, Sequence[BaseNode]]:
    """Transform documents into nodes and build a persistent index."""

    persist_path.mkdir(parents=True, exist_ok=True)
    storage_context = _create_storage_context()

    nodes = _run_ingestion_pipeline(
        documents=documents,
        transformations=transformations,
    )

    index = VectorStoreIndex(
        nodes=nodes,
        storage_context=storage_context,
        callback_manager=callback_manager,
    )

    index.storage_context.persist(persist_dir=str(persist_path))
    return index, nodes


def _load_index_with_nodes(
    persist_path: Path,
) -> Tuple[VectorStoreIndex, Sequence[BaseNode]]:
    """Load a persisted index and recover its nodes from the docstore."""

    storage_context = StorageContext.from_defaults(
        persist_dir=str(persist_path)
    )

    index = cast(
        VectorStoreIndex,
        load_index_from_storage(storage_context),
    )

    nodes = _get_all_nodes_from_docstore(index)
    return index, nodes


def _get_all_nodes_from_docstore(index: VectorStoreIndex) -> Sequence[BaseNode]:
    """
    Recover all nodes stored in the docstore.

    Works with SimpleDocumentStore-backed persistence.
    """
    docstore = index.storage_context.docstore

    # Common/simple approach for SimpleDocumentStore-backed local persistence
    if hasattr(docstore, "docs"):
        return list(docstore.docs.values())

    raise TypeError(
        "This docstore does not expose .docs; use stored node IDs and "
        "docstore.get_node(...) / get_node_dict(...) instead."
    )


def _run_ingestion_pipeline(
    documents: Sequence[Document],
    transformations,
) -> Sequence[BaseNode]:
    pipeline = IngestionPipeline(transformations=transformations)
    nodes = pipeline.run(documents=list(documents))

    for node in nodes:
        if node.end_char_idx is not None:
            node.metadata["end_char_idx"] = node.end_char_idx

    return nodes

def _create_storage_context() -> StorageContext:
    """Create storage context backing the index."""

    return StorageContext.from_defaults(
        docstore=SimpleDocumentStore(),
        index_store=SimpleIndexStore(),
        vector_store=SimpleVectorStore(),
    )


def _can_load_index(
    persist_path: Path,
) -> bool:
    """Return True if a persisted index can be successfully loaded."""

    try:
        storage_context = StorageContext.from_defaults(
            persist_dir=str(persist_path)
        )
        load_index_from_storage(storage_context)
        return True
    except Exception:
        return False