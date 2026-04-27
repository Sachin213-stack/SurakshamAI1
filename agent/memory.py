import asyncio
import hashlib
from functools import lru_cache
from typing import Optional
from pinecone import Pinecone, ServerlessSpec
from sentence_transformers import SentenceTransformer
from core.config import get_settings
from core.logging import logger
from core.exceptions import MemoryUnavailableError

settings = get_settings()

DIMENSION = 384  # all-MiniLM-L6-v2


@lru_cache(maxsize=1)
def _get_embedder() -> SentenceTransformer:
    logger.info("Loading sentence transformer model")
    return SentenceTransformer("all-MiniLM-L6-v2")


@lru_cache(maxsize=1)
def _get_index() -> Optional[object]:
    """Initialize and cache Pinecone index. Returns None if unconfigured."""
    if not settings.pinecone_api_key:
        logger.warning("PINECONE_API_KEY not set — memory layer disabled")
        return None

    try:
        pc = Pinecone(api_key=settings.pinecone_api_key)
        existing = [i.name for i in pc.list_indexes()]

        if settings.pinecone_index not in existing:
            logger.info(f"Creating Pinecone index: {settings.pinecone_index}")
            pc.create_index(
                name=settings.pinecone_index,
                dimension=DIMENSION,
                metric="cosine",
                spec=ServerlessSpec(
                    cloud=settings.pinecone_cloud,
                    region=settings.pinecone_region,
                ),
            )

        index = pc.Index(settings.pinecone_index)
        logger.info("Pinecone index ready", extra={"index": settings.pinecone_index})
        return index

    except Exception as exc:
        logger.error("Failed to initialize Pinecone", extra={"error": str(exc)})
        return None


def _stable_id(text: str) -> str:
    """Generate a stable, collision-resistant vector ID from text."""
    return hashlib.sha256(text.encode()).hexdigest()[:32]


async def search_similar_patterns(text: str, top_k: int = 3) -> list[dict]:
    """
    Async-safe hybrid search: semantic similarity via Pinecone.
    Falls back to empty list if memory is unavailable.
    """
    index = _get_index()
    if not index:
        return []

    try:
        embedder = _get_embedder()
        # Run CPU-bound embedding in thread pool
        loop = asyncio.get_event_loop()
        embedding = await loop.run_in_executor(None, lambda: embedder.encode(text).tolist())

        results = index.query(vector=embedding, top_k=top_k, include_metadata=True)

        matches = [
            {
                "score": round(m.score, 3),
                "pattern": m.metadata.get("pattern", ""),
                "label": m.metadata.get("label", "unknown"),
            }
            for m in results.matches
            if m.score > 0.5  # Only return meaningful matches
        ]

        logger.debug("Memory search complete", extra={"matches": len(matches), "query_len": len(text)})
        return matches

    except Exception as exc:
        logger.error("Pinecone search failed", extra={"error": str(exc)})
        return []  # Degrade gracefully — don't block inference


async def store_pattern(text: str, label: str = "scam") -> bool:
    """Async store a confirmed scam pattern. Returns True on success."""
    index = _get_index()
    if not index:
        return False

    try:
        embedder = _get_embedder()
        loop = asyncio.get_event_loop()
        embedding = await loop.run_in_executor(None, lambda: embedder.encode(text).tolist())

        index.upsert(vectors=[{
            "id": _stable_id(text),
            "values": embedding,
            "metadata": {"pattern": text, "label": label},
        }])
        logger.info("Pattern stored in memory", extra={"label": label, "text_len": len(text)})
        return True

    except Exception as exc:
        logger.error("Failed to store pattern", extra={"error": str(exc)})
        return False
