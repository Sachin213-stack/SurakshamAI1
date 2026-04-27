import time
import asyncio
from functools import lru_cache
from groq import Groq, APITimeoutError, APIConnectionError, RateLimitError
from agent.privacy import scrub_pii
from agent.memory import search_similar_patterns
from models.schemas import AgentDecision
from core.config import get_settings
from core.logging import logger
from core.exceptions import GroqInferenceError

settings = get_settings()

SYSTEM_PROMPT = """You are the "Sentinel-Agent," an elite cybersecurity autonomous guard.
Your task is to analyze incoming communication (Masked SMS/Transcripts) and neutralize fraud threats in real-time.

Operational Constraints:
- Data Handling: You will ONLY receive masked data (no real names, no actual OTPs).
- Reasoning: Analyze the 'Vibe' and 'Intent'. Is there fake urgency? Is there a request for sensitive actions (transfer, click, share)?
- Memory Context: You will be given similar known scam patterns from the vector database.
- Action Output must be EXACTLY in this format (no extra text, no markdown):
  Score: <0-100>
  Action: <BLOCK_CALL|OVERLAY_WARNING|IGNORE>
  Reasoning: <one concise sentence>

Decision Logic:
- Score > 80 → BLOCK_CALL (active threat, block immediately)
- Score 50-80 → OVERLAY_WARNING (suspicious, warn user)
- Score < 50 → IGNORE (likely legitimate)
"""


@lru_cache(maxsize=1)
def _get_client() -> Groq:
    return Groq(
        api_key=settings.groq_api_key,
        timeout=settings.groq_timeout,
        max_retries=0,  # We handle retries manually with backoff
    )


def _parse_response(raw: str, masked_text: str) -> AgentDecision:
    """Parse LLM structured output into AgentDecision. Defaults to safe IGNORE on parse failure."""
    score = 0
    action = "IGNORE"
    reasoning = "Could not parse agent response."

    for line in raw.strip().splitlines():
        line = line.strip()
        lower = line.lower()

        if lower.startswith("score:"):
            try:
                val = int(line.split(":", 1)[1].strip().split()[0])
                score = max(0, min(100, val))  # Clamp to [0, 100]
            except (ValueError, IndexError):
                pass

        elif lower.startswith("action:"):
            candidate = line.split(":", 1)[1].strip().upper()
            if candidate in ("BLOCK_CALL", "OVERLAY_WARNING", "IGNORE"):
                action = candidate

        elif lower.startswith("reasoning:"):
            reasoning = line.split(":", 1)[1].strip()

    # Enforce consistency: score must align with action
    if score > settings.block_threshold and action == "IGNORE":
        action = "OVERLAY_WARNING"

    return AgentDecision(score=score, action=action, reasoning=reasoning, masked_text=masked_text)


async def _call_groq_with_retry(user_message: str) -> str:
    """Call Groq API with exponential backoff retry."""
    client = _get_client()
    last_exc = None

    for attempt in range(1, settings.groq_max_retries + 1):
        try:
            response = client.chat.completions.create(
                model=settings.groq_model,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_message},
                ],
                temperature=settings.groq_temperature,
                max_tokens=settings.groq_max_tokens,
            )
            return response.choices[0].message.content

        except RateLimitError as exc:
            wait = 2 ** attempt
            logger.warning(f"Groq rate limited, retrying in {wait}s", extra={"attempt": attempt})
            await asyncio.sleep(wait)
            last_exc = exc

        except (APITimeoutError, APIConnectionError) as exc:
            wait = 2 ** attempt
            logger.warning(f"Groq connection error, retrying in {wait}s", extra={"attempt": attempt, "error": str(exc)})
            await asyncio.sleep(wait)
            last_exc = exc

        except Exception as exc:
            logger.error("Groq unexpected error", extra={"error": str(exc)})
            raise GroqInferenceError(f"Groq API error: {exc}") from exc

    raise GroqInferenceError(f"Groq failed after {settings.groq_max_retries} retries: {last_exc}")


async def analyze(
    raw_text: str,
    message_type: str = "sms",
    source_number: str = None,
    device_id: str = None,
) -> AgentDecision:
    """
    Full pipeline: scrub PII → memory search → LLM inference → structured decision.
    """
    start = time.perf_counter()

    # Step 1: Privacy scrub (raises PrivacyScrubError on failure)
    masked = scrub_pii(raw_text)
    logger.debug("PII scrubbed", extra={"original_len": len(raw_text), "masked_len": len(masked)})

    # Step 2: Hybrid memory search (non-blocking, degrades gracefully)
    similar = await search_similar_patterns(masked)
    memory_context = ""
    if similar:
        memory_context = "\n\nKnown similar scam patterns from memory:\n"
        for p in similar:
            memory_context += f"- [{p['score'] * 100:.0f}% match] {p['pattern']}\n"

    # Step 3: LLM inference via Groq
    user_message = f'Analyze this masked communication:\n\n"{masked}"{memory_context}'
    raw_output = await _call_groq_with_retry(user_message)

    # Step 4: Parse and return
    decision = _parse_response(raw_output, masked)
    decision.message_type = message_type
    decision.source_number = source_number
    decision.device_id = device_id

    elapsed_ms = (time.perf_counter() - start) * 1000
    logger.info(
        "Analysis complete",
        extra={
            "score": decision.score,
            "action": decision.action,
            "latency_ms": round(elapsed_ms, 2),
            "memory_hits": len(similar),
        },
    )

    return decision
