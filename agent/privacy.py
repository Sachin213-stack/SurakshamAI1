import re
import spacy
from functools import lru_cache
from core.logging import logger
from core.exceptions import PrivacyScrubError

# ─── Compiled Regex Patterns (Indian financial context) ───────────────────────
_RAW_PATTERNS: list[tuple[str, str]] = [
    (r"https?://\S+", "[URL]"),                                      # URLs first (before number patterns)
    (r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", "[EMAIL]"),
    (r"\b[A-Z]{4}0[A-Z0-9]{6}\b", "[IFSC]"),                        # IFSC codes
    (r"\b\d{16}\b", "[CARD_NUM]"),                                   # Card numbers
    (r"\b\d{9,15}\b", "[ACCOUNT_NUM]"),                              # Account numbers
    (r"\b\d{10}\b", "[PHONE]"),                                      # Phone numbers
    (r"\b\d{4,6}\b", "[SENSITIVE_NUM]"),                             # OTPs / short codes
    (r"\b(?:HDFC|SBI|ICICI|Axis|Kotak|Paytm|PhonePe|GPay|UPI|NEFT|RTGS|IMPS)\b", "[INSTITUTION]"),
    (r"\b\d{1,3}(?:,\d{3})*(?:\.\d{2})?\b", "[AMOUNT]"),            # Currency amounts
    (r"\b[A-Z]{2}\d{2}[A-Z]{2}\d{4}\b", "[VEHICLE_NUM]"),           # Vehicle numbers
]

COMPILED_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(p, re.IGNORECASE), r) for p, r in _RAW_PATTERNS
]

_NER_LABEL_MAP = {
    "PERSON": "[USER]",
    "ORG": "[INSTITUTION]",
    "GPE": "[LOCATION]",
    "LOC": "[LOCATION]",
    "MONEY": "[AMOUNT]",
    "CARDINAL": "[SENSITIVE_NUM]",
}


@lru_cache(maxsize=1)
def _load_nlp():
    """Load spaCy model once, cached."""
    try:
        nlp = spacy.load("en_core_web_sm")
        logger.info("spaCy model loaded successfully")
        return nlp
    except OSError:
        logger.warning("spaCy model not found. Run: python -m spacy download en_core_web_sm")
        return None


def scrub_pii(text: str) -> str:
    """
    Remove PII using SpaCy NER + custom regex patterns.
    Raises PrivacyScrubError on unexpected failure.
    """
    if not text or not text.strip():
        return text

    try:
        masked = text
        nlp = _load_nlp()

        # Pass 1: SpaCy NER (process on original to get correct char offsets)
        if nlp:
            doc = nlp(masked)
            replacements = []
            for ent in doc.ents:
                if ent.label_ in _NER_LABEL_MAP:
                    replacements.append((ent.start_char, ent.end_char, _NER_LABEL_MAP[ent.label_]))

            # Apply in reverse to preserve offsets
            for start, end, label in sorted(replacements, reverse=True):
                masked = masked[:start] + label + masked[end:]

        # Pass 2: Regex patterns
        for pattern, replacement in COMPILED_PATTERNS:
            masked = pattern.sub(replacement, masked)

        return masked

    except Exception as exc:
        logger.exception("PII scrubbing failed", extra={"error": str(exc)})
        raise PrivacyScrubError(f"Privacy scrubbing failed: {exc}") from exc


def scrub_pii_with_diff(text: str) -> dict:
    """Returns both raw and masked text for demo/audit purposes."""
    masked = scrub_pii(text)
    return {"raw": text, "masked": masked, "changed": text != masked}
