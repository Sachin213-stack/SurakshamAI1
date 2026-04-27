from fastapi import Request
from fastapi.responses import JSONResponse
from core.logging import logger


class SentinelBaseError(Exception):
    def __init__(self, message: str, status_code: int = 500):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


class GroqInferenceError(SentinelBaseError):
    def __init__(self, message: str = "LLM inference failed"):
        super().__init__(message, status_code=503)


class MemoryUnavailableError(SentinelBaseError):
    def __init__(self, message: str = "Vector memory unavailable"):
        super().__init__(message, status_code=503)


class PrivacyScrubError(SentinelBaseError):
    def __init__(self, message: str = "Privacy scrubbing failed"):
        super().__init__(message, status_code=500)


async def sentinel_exception_handler(request: Request, exc: SentinelBaseError) -> JSONResponse:
    logger.error(
        "Sentinel error",
        extra={"path": request.url.path, "error": exc.message, "status_code": exc.status_code},
    )
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": exc.message, "type": type(exc).__name__},
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled exception", extra={"path": request.url.path})
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "type": "UnhandledError"},
    )
