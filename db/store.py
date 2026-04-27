"""
In-memory store for alert history, analytics, and device registry.
In production, replace with PostgreSQL / Redis.
"""
from collections import deque
from datetime import datetime, timezone, timedelta
from typing import Optional
from models.schemas import AgentDecision, AlertHistoryItem, AnalyticsSummary
import threading

_lock = threading.Lock()

# Max 1000 alerts in memory
_alerts: deque[AlertHistoryItem] = deque(maxlen=1000)

# device_id → fcm_token
_devices: dict[str, dict] = {}


# ─── Alerts ───────────────────────────────────────────────────────────────────

def save_alert(decision: AgentDecision) -> AlertHistoryItem:
    item = AlertHistoryItem(
        id=decision.id,
        score=decision.score,
        action=decision.action,
        reasoning=decision.reasoning,
        masked_text=decision.masked_text,
        message_type=decision.message_type,
        source_number=decision.source_number,
        device_id=decision.device_id,
        timestamp=decision.timestamp,
    )
    with _lock:
        _alerts.appendleft(item)
    return item


def get_alerts(
    page: int = 1,
    page_size: int = 20,
    device_id: Optional[str] = None,
    action_filter: Optional[str] = None,
) -> tuple[int, list[AlertHistoryItem]]:
    with _lock:
        filtered = list(_alerts)

    if device_id:
        filtered = [a for a in filtered if a.device_id == device_id]
    if action_filter:
        filtered = [a for a in filtered if a.action == action_filter]

    total = len(filtered)
    start = (page - 1) * page_size
    return total, filtered[start: start + page_size]


def update_feedback(alert_id: str, feedback: str) -> bool:
    with _lock:
        for alert in _alerts:
            if alert.id == alert_id:
                alert.user_feedback = feedback
                return True
    return False


def get_alert_by_id(alert_id: str) -> Optional[AlertHistoryItem]:
    with _lock:
        for alert in _alerts:
            if alert.id == alert_id:
                return alert
    return None


# ─── Analytics ────────────────────────────────────────────────────────────────

def get_analytics(device_id: Optional[str] = None) -> AnalyticsSummary:
    with _lock:
        alerts = list(_alerts)

    if device_id:
        alerts = [a for a in alerts if a.device_id == device_id]

    now = datetime.now(timezone.utc)
    last_24h = now - timedelta(hours=24)
    last_7d = now - timedelta(days=7)

    total = len(alerts)
    blocked = sum(1 for a in alerts if a.action == "BLOCK_CALL")
    warned = sum(1 for a in alerts if a.action == "OVERLAY_WARNING")
    ignored = sum(1 for a in alerts if a.action == "IGNORE")
    avg_score = round(sum(a.score for a in alerts) / total, 1) if total else 0.0
    scams_24h = sum(1 for a in alerts if a.timestamp >= last_24h and a.action != "IGNORE")
    scams_7d = sum(1 for a in alerts if a.timestamp >= last_7d and a.action != "IGNORE")
    block_rate = round((blocked / total) * 100, 1) if total else 0.0

    # Most common threat source number
    numbers = [a.source_number for a in alerts if a.source_number and a.action != "IGNORE"]
    top_threat = max(set(numbers), key=numbers.count) if numbers else None

    return AnalyticsSummary(
        total_analyzed=total,
        total_blocked=blocked,
        total_warned=warned,
        total_ignored=ignored,
        avg_score=avg_score,
        top_threat_type=top_threat,
        scams_last_24h=scams_24h,
        scams_last_7d=scams_7d,
        block_rate_percent=block_rate,
    )


# ─── Device Registry ──────────────────────────────────────────────────────────

def register_device(device_id: str, fcm_token: str, platform: str, app_version: Optional[str]) -> None:
    with _lock:
        _devices[device_id] = {
            "fcm_token": fcm_token,
            "platform": platform,
            "app_version": app_version,
            "registered_at": datetime.now(timezone.utc).isoformat(),
        }


def get_fcm_token(device_id: str) -> Optional[str]:
    return _devices.get(device_id, {}).get("fcm_token")


def get_all_devices() -> dict:
    with _lock:
        return dict(_devices)
