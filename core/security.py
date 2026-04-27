import time
from collections import defaultdict
from fastapi import HTTPException, Security, status
from fastapi.security.api_key import APIKeyHeader
from core.config import get_settings
from core.logging import logger

settings = get_settings()
api_key_header = APIKeyHeader(name=settings.api_key_header, auto_error=False)

# In-memory rate limiter (use Redis in multi-instance deployments)
_request_counts: dict[str, list[float]] = defaultdict(list)


def verify_api_key(key: str = Security(api_key_header)) -> str:
    """Validate API key. Skip if no keys configured (dev mode)."""
    if not settings.api_key_list:
        return "dev"
    if key not in settings.api_key_list:
        logger.warning("Unauthorized access attempt", extra={"key_prefix": str(key)[:8] if key else "none"})
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key")
    return key


def check_rate_limit(client_id: str) -> None:
    """Sliding window rate limiter."""
    now = time.time()
    window_start = now - settings.rate_limit_window
    requests = _request_counts[client_id]

    # Purge old entries
    _request_counts[client_id] = [t for t in requests if t > window_start]

    if len(_request_counts[client_id]) >= settings.rate_limit_requests:
        logger.warning("Rate limit exceeded", extra={"client_id": client_id})
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Rate limit: {settings.rate_limit_requests} requests per {settings.rate_limit_window}s",
            headers={"Retry-After": str(settings.rate_limit_window)},
        )

    _request_counts[client_id].append(now)
