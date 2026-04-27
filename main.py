import json
import asyncio
from typing import Optional
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, Request, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from core.config import get_settings
from core.logging import logger
from core.security import verify_api_key, check_rate_limit
from core.exceptions import (
    SentinelBaseError,
    sentinel_exception_handler,
    unhandled_exception_handler,
)
from models.schemas import (
    IncomingMessage, AgentDecision, MaskDemoResponse,
    HealthResponse, StorePatternRequest, WebSocketAlert,
    AlertHistoryResponse, AnalyticsSummary,
    DeviceRegisterRequest, DeviceRegisterResponse,
    ManualReportRequest, FeedbackRequest,
)
from agent.sentinel import analyze
from agent.privacy import scrub_pii_with_diff
from agent.memory import store_pattern, _get_index, _get_embedder
from db.store import (
    save_alert, get_alerts, get_analytics,
    register_device, update_feedback,
)

settings = get_settings()


# ─── WebSocket Connection Manager ─────────────────────────────────────────────

class ConnectionManager:
    def __init__(self):
        self._connections: dict[str, WebSocket] = {}

    async def connect(self, client_id: str, websocket: WebSocket) -> bool:
        if len(self._connections) >= settings.ws_max_connections:
            await websocket.close(code=1008, reason="Max connections reached")
            return False
        await websocket.accept()
        self._connections[client_id] = websocket
        logger.info("WS connected", extra={"client_id": client_id})
        return True

    def disconnect(self, client_id: str):
        self._connections.pop(client_id, None)

    async def broadcast(self, alert: WebSocketAlert):
        if not self._connections:
            return
        payload = alert.model_dump_json()
        dead = []
        for cid, ws in self._connections.items():
            try:
                await ws.send_text(payload)
            except Exception:
                dead.append(cid)
        for cid in dead:
            self.disconnect(cid)

    async def send_to_device(self, device_id: str, alert: WebSocketAlert):
        ws = self._connections.get(device_id)
        if ws:
            try:
                await ws.send_text(alert.model_dump_json())
            except Exception:
                self.disconnect(device_id)

    @property
    def connection_count(self) -> int:
        return len(self._connections)


manager = ConnectionManager()


# ─── Lifespan ─────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"Starting {settings.app_name} v{settings.app_version} [{settings.environment}]")
    try:
        _get_embedder()
        logger.info("Embedder warmed up")
    except Exception as e:
        logger.warning(f"Embedder warm-up failed: {e}")
    try:
        _get_index()
        logger.info("Pinecone warmed up")
    except Exception as e:
        logger.warning(f"Pinecone warm-up failed: {e}")
    yield
    logger.info("Shutting down")


# ─── App ──────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Sentinel-Agent",
    version=settings.app_version,
    description="Autonomous Zero-Friction Fraud Defense — Android Backend API",
    docs_url="/docs",
    redoc_url=None,
    lifespan=lifespan,
)

app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)
app.add_exception_handler(SentinelBaseError, sentinel_exception_handler)
app.add_exception_handler(Exception, unhandled_exception_handler)

# Serve static dashboard
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/", include_in_schema=False)
async def dashboard():
    return FileResponse("static/index.html")


@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    import uuid
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4())[:8])
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response


# ─── 1. Core Analyze ──────────────────────────────────────────────────────────

@app.post("/analyze", response_model=AgentDecision, tags=["Core"])
async def analyze_message(
    payload: IncomingMessage,
    request: Request,
    api_key: str = Depends(verify_api_key),
):
    """
    Main endpoint — Android app sends every SMS/call transcript here.
    Returns fraud score, action, and masked text.
    """
    client_ip = request.client.host if request.client else "unknown"
    check_rate_limit(client_ip)

    decision = await analyze(
        raw_text=payload.raw_text,
        message_type=payload.type,
        source_number=payload.source_number,
        device_id=payload.device_id,
    )

    # Save to history
    save_alert(decision)

    # Push real-time alert to WebSocket (device-specific or broadcast)
    if decision.score > settings.overlay_threshold:
        alert = WebSocketAlert(
            event="fraud_alert",
            score=decision.score,
            action=decision.action,
            reasoning=decision.reasoning,
            masked_text=decision.masked_text,
            alert_id=decision.id,
        )
        if payload.device_id:
            asyncio.create_task(manager.send_to_device(payload.device_id, alert))
        else:
            asyncio.create_task(manager.broadcast(alert))

    return decision


# ─── 2. Alert History ─────────────────────────────────────────────────────────

@app.get("/alerts/history", response_model=AlertHistoryResponse, tags=["Alerts"])
async def alert_history(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    device_id: Optional[str] = Query(default=None),
    action: Optional[str] = Query(default=None, description="BLOCK_CALL | OVERLAY_WARNING | IGNORE"),
    api_key: str = Depends(verify_api_key),
):
    """
    Android app fetches past fraud alerts.
    Filter by device_id to show only that device's history.
    """
    total, items = get_alerts(page=page, page_size=page_size, device_id=device_id, action_filter=action)
    return AlertHistoryResponse(total=total, page=page, page_size=page_size, items=items)


# ─── 3. User Feedback ─────────────────────────────────────────────────────────

@app.post("/alerts/feedback", tags=["Alerts"])
async def submit_feedback(
    payload: FeedbackRequest,
    api_key: str = Depends(verify_api_key),
):
    """
    User marks an alert as confirmed scam or false positive.
    Helps improve future detection accuracy.
    """
    updated = update_feedback(payload.alert_id, payload.feedback)
    if not updated:
        raise HTTPException(status_code=404, detail="Alert not found")

    # If confirmed scam → store in Pinecone memory for future detection
    if payload.feedback == "confirmed_scam":
        total, items = get_alerts(page=1, page_size=1)
        for item in items:
            if item.id == payload.alert_id:
                await store_pattern(item.masked_text, label="scam")
                break

    return {"updated": True, "feedback": payload.feedback}


# ─── 4. Analytics ─────────────────────────────────────────────────────────────

@app.get("/analytics", response_model=AnalyticsSummary, tags=["Analytics"])
async def analytics(
    device_id: Optional[str] = Query(default=None),
    api_key: str = Depends(verify_api_key),
):
    """
    Dashboard stats — total scams blocked, avg score, 24h/7d trends.
    Pass device_id for per-device stats.
    """
    return get_analytics(device_id=device_id)


# ─── 5. Device Registration (FCM Push) ───────────────────────────────────────

@app.post("/device/register", response_model=DeviceRegisterResponse, tags=["Device"])
async def register_device_endpoint(
    payload: DeviceRegisterRequest,
    api_key: str = Depends(verify_api_key),
):
    """
    Android app registers its FCM token for push notifications.
    Call this on app start or when FCM token refreshes.
    """
    register_device(
        device_id=payload.device_id,
        fcm_token=payload.fcm_token,
        platform=payload.platform,
        app_version=payload.app_version,
    )
    logger.info("Device registered", extra={"device_id": payload.device_id})
    return DeviceRegisterResponse(registered=True, device_id=payload.device_id)


# ─── 6. Manual Report ─────────────────────────────────────────────────────────

@app.post("/report", response_model=AgentDecision, tags=["Core"])
async def manual_report(
    payload: ManualReportRequest,
    request: Request,
    api_key: str = Depends(verify_api_key),
):
    """
    User manually reports a suspicious SMS/call from the app.
    Runs full analysis pipeline and stores confirmed pattern.
    """
    check_rate_limit(request.client.host if request.client else "unknown")

    decision = await analyze(
        raw_text=payload.raw_text,
        message_type=payload.report_type,
        source_number=payload.source_number,
        device_id=payload.device_id,
    )
    save_alert(decision)

    # Manual reports are high-confidence — always store in memory
    await store_pattern(decision.masked_text, label="scam")
    logger.info("Manual report processed", extra={"score": decision.score, "device_id": payload.device_id})

    return decision


# ─── 7. WebSocket Overlay ─────────────────────────────────────────────────────

@app.websocket("/ws/overlay/{device_id}")
async def overlay_websocket(websocket: WebSocket, device_id: str):
    """
    Android app connects here for real-time fraud overlay alerts.
    device_id should match the one sent in /analyze requests.
    """
    connected = await manager.connect(device_id, websocket)
    if not connected:
        return
    try:
        while True:
            await asyncio.sleep(settings.ws_ping_interval)
            await websocket.send_text(WebSocketAlert(event="ping").model_dump_json())
    except WebSocketDisconnect:
        manager.disconnect(device_id)
    except Exception as e:
        logger.error("WS error", extra={"device_id": device_id, "error": str(e)})
        manager.disconnect(device_id)


# ─── 8. Privacy Demo ──────────────────────────────────────────────────────────

@app.post("/demo/mask", response_model=MaskDemoResponse, tags=["Demo"])
async def demo_mask(payload: IncomingMessage, api_key: str = Depends(verify_api_key)):
    """Shows raw vs masked text — for judges demo / privacy toggle in app."""
    result = scrub_pii_with_diff(payload.raw_text)
    return MaskDemoResponse(**result)


# ─── 9. Memory ────────────────────────────────────────────────────────────────

@app.post("/memory/patterns", tags=["Memory"], status_code=201)
async def add_pattern(payload: StorePatternRequest, api_key: str = Depends(verify_api_key)):
    """Manually add a scam pattern to vector memory."""
    success = await store_pattern(payload.text, payload.label)
    if not success:
        raise HTTPException(status_code=503, detail="Memory layer unavailable")
    return {"stored": True, "label": payload.label}


# ─── 10. Health ───────────────────────────────────────────────────────────────

@app.get("/health", response_model=HealthResponse, tags=["System"])
async def health():
    return HealthResponse(status="online", version=settings.app_version, environment=settings.environment)


@app.get("/health/detailed", tags=["System"])
async def health_detailed(api_key: str = Depends(verify_api_key)):
    from agent.privacy import _load_nlp
    checks = {
        "api": "ok",
        "spacy": "ok" if _load_nlp() else "degraded",
        "pinecone": "ok" if _get_index() else "degraded",
        "websocket_connections": manager.connection_count,
    }
    overall = "ok" if all(v in ("ok",) or isinstance(v, int) for v in checks.values()) else "degraded"
    return {"status": overall, "checks": checks, "version": settings.app_version}
