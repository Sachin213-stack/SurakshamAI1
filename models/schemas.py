from pydantic import BaseModel, Field, field_validator
from typing import Literal, Optional
from datetime import datetime, timezone
import uuid


# ─── Incoming ─────────────────────────────────────────────────────────────────

class IncomingMessage(BaseModel):
    type: Literal["sms", "call_transcript"]
    raw_text: str = Field(..., min_length=1, max_length=2000)
    source_number: Optional[str] = Field(default=None)
    device_id: Optional[str] = Field(default=None, description="Android device ID")

    @field_validator("raw_text")
    @classmethod
    def strip_text(cls, v: str) -> str:
        return v.strip()


# ─── Agent Decision ───────────────────────────────────────────────────────────

class AgentDecision(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    score: int = Field(..., ge=0, le=100)
    action: Literal["BLOCK_CALL", "OVERLAY_WARNING", "IGNORE"]
    reasoning: str = Field(..., min_length=1, max_length=500)
    masked_text: str
    message_type: Optional[str] = None
    source_number: Optional[str] = None
    device_id: Optional[str] = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


# ─── Alert History ────────────────────────────────────────────────────────────

class AlertHistoryItem(BaseModel):
    id: str
    score: int
    action: str
    reasoning: str
    masked_text: str
    message_type: Optional[str]
    source_number: Optional[str]
    device_id: Optional[str]
    timestamp: datetime
    user_feedback: Optional[Literal["confirmed_scam", "false_positive"]] = None


class AlertHistoryResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[AlertHistoryItem]


# ─── Analytics ────────────────────────────────────────────────────────────────

class AnalyticsSummary(BaseModel):
    total_analyzed: int
    total_blocked: int
    total_warned: int
    total_ignored: int
    avg_score: float
    top_threat_type: Optional[str]
    scams_last_24h: int
    scams_last_7d: int
    block_rate_percent: float


# ─── Device Registration (FCM Push) ──────────────────────────────────────────

class DeviceRegisterRequest(BaseModel):
    device_id: str = Field(..., min_length=1, max_length=200)
    fcm_token: str = Field(..., min_length=10, max_length=500)
    platform: Literal["android"] = "android"
    app_version: Optional[str] = None


class DeviceRegisterResponse(BaseModel):
    registered: bool
    device_id: str


# ─── Manual Report ────────────────────────────────────────────────────────────

class ManualReportRequest(BaseModel):
    raw_text: str = Field(..., min_length=5, max_length=2000)
    source_number: Optional[str] = None
    report_type: Literal["sms", "call_transcript", "whatsapp", "other"] = "sms"
    device_id: Optional[str] = None
    user_note: Optional[str] = Field(default=None, max_length=500)


# ─── User Feedback ────────────────────────────────────────────────────────────

class FeedbackRequest(BaseModel):
    alert_id: str
    feedback: Literal["confirmed_scam", "false_positive"]
    device_id: Optional[str] = None


# ─── Misc ─────────────────────────────────────────────────────────────────────

class MaskDemoResponse(BaseModel):
    raw: str
    masked: str
    changed: bool


class HealthResponse(BaseModel):
    status: str
    version: str
    environment: str
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class StorePatternRequest(BaseModel):
    text: str = Field(..., min_length=5, max_length=1000)
    label: Literal["scam", "phishing", "vishing", "smishing"] = "scam"


class WebSocketAlert(BaseModel):
    event: Literal["fraud_alert", "ping"] = "fraud_alert"
    score: Optional[int] = None
    action: Optional[str] = None
    reasoning: Optional[str] = None
    masked_text: Optional[str] = None
    alert_id: Optional[str] = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
