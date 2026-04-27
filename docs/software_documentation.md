# SurakshamAI Software Documentation

## 1. Overview

SurakshamAI is a fraud-defense software system with:

- A **FastAPI backend** that analyzes incoming SMS/call text for scam risk.
- An **Android (Flutter) app** that sends content for analysis, shows alerts/history/analytics, and receives real-time WebSocket alerts.
- A **privacy-first pipeline** that masks sensitive data before LLM inference.
- Optional **vector memory** for scam pattern recall and feedback-driven improvement.

---

## 2. High-Level Architecture

1. Android app captures or receives text input.
2. App calls backend `/analyze` or `/report`.
3. Backend masks PII using spaCy + regex rules.
4. Backend fetches similar scam patterns from Pinecone (if configured).
5. Backend calls Groq LLM and parses structured decision output.
6. Backend stores alert in in-memory store and optionally emits WebSocket alert.
7. App updates UI (home/history/analytics) and can submit user feedback.

---

## 3. Repository Structure

- `main.py` — FastAPI application, routes, middleware, WebSocket manager.
- `agent/`
  - `sentinel.py` — main analysis pipeline (privacy → memory → LLM → decision).
  - `privacy.py` — PII masking logic.
  - `memory.py` — pattern storage/search with embeddings + Pinecone.
- `models/schemas.py` — Pydantic request/response contracts.
- `db/store.py` — in-memory alert, analytics, and device registry.
- `core/` — config, logging, security, and custom exception handling.
- `static/` — web dashboard preview assets.
- `docs/` — project documentation.
- `sentinel_android/` — Flutter Android client.
- `.github/workflows/build-apk.yml` — CI workflow for Android APK build/release.

---

## 4. Backend Design

### 4.1 Framework & Runtime

- Python + FastAPI
- Uvicorn ASGI server
- GZip + CORS middleware
- API key protection and per-IP rate limiting

### 4.2 Core API Endpoints

- `POST /analyze` — analyze incoming SMS/call transcript.
- `POST /report` — manual suspicious-content reporting.
- `GET /alerts/history` — paginated alert history.
- `POST /alerts/feedback` — mark alert as `confirmed_scam` or `false_positive`.
- `GET /analytics` — summary metrics.
- `POST /device/register` — register device/FCM token.
- `POST /memory/patterns` — store scam pattern manually.
- `POST /demo/mask` — raw vs masked privacy demo.
- `GET /health` and `GET /health/detailed` — service health.
- `WS /ws/overlay/{device_id}` — real-time fraud overlay alerts.

### 4.3 Fraud Decision Logic

`AgentDecision` fields include score (0–100), action, reasoning, and masked text.

- Score `> 80` → `BLOCK_CALL`
- Score `50–80` → `OVERLAY_WARNING`
- Score `< 50` → `IGNORE`

Thresholds are configurable through environment variables.

### 4.4 Data Storage

Current implementation uses process memory:

- Alerts: bounded deque (`maxlen=1000`)
- Devices: in-memory map of `device_id -> metadata`

This is suitable for demo/prototype usage; persistent stores should be used for production.

---

## 5. Privacy and Security

### 5.1 Privacy Layer

- spaCy NER masks entities (person, org, location, etc.).
- Regex rules mask financial and sensitive patterns (URLs, emails, account/card numbers, OTP-like values, phone numbers, IFSC, etc.).
- LLM receives masked text only.

### 5.2 Security Controls

- API key validation via `X-API-Key` (configurable).
- Rate limiting by client IP.
- Structured exception handling and logging.

---

## 6. Android App Design

### 6.1 Tech Stack

- Flutter + Provider state management
- HTTP client for REST calls
- WebSocket channel for live alerts
- SharedPreferences for local settings persistence

### 6.2 Main Responsibilities

- Connect to backend and WebSocket.
- Trigger analysis requests.
- Render alerts/history/analytics screens.
- Submit feedback to improve model behavior.

---

## 7. Configuration

Configuration is environment-driven (`.env`, see `.env.example`):

- App settings: `ENVIRONMENT`, `DEBUG`
- Security: `API_KEYS`
- LLM: `GROQ_API_KEY`, model, timeout, retry settings
- Memory: `PINECONE_API_KEY`, index/cloud/region
- Runtime controls: rate limits, thresholds, WebSocket limits

---

## 8. Local Setup and Run

### 8.1 Backend

1. Create and activate a Python virtual environment.
2. Install dependencies:
   - `pip install -r requirements.txt`
3. Copy environment template:
   - `cp .env.example .env`
4. Fill required keys (at minimum `GROQ_API_KEY`; add `API_KEYS` for protected routes).
5. Start backend:
   - `uvicorn main:app --host 0.0.0.0 --port 8000`

Alternative:

- `python run_mobile.py` (prints LAN URLs for device testing).

### 8.2 Android App

1. Go to `sentinel_android/`.
2. Run:
   - `flutter pub get`
3. Build/run app on Android device or emulator.
4. Configure API URL/device ID/API key in app settings screen.

---

## 9. Build and Release

The GitHub Actions workflow in `.github/workflows/build-apk.yml`:

- Sets up Java + Flutter.
- Runs Flutter dependency install and analysis.
- Builds release APK.
- Uploads artifact and creates a GitHub release.

---

## 10. Operational Notes

- Health checks are available for service observability.
- WebSocket manager enforces maximum connection count.
- Memory and analytics are currently in-process; restart clears data.
- For production hardening, migrate storage to persistent DB/cache and secure CORS/API key policies per environment.

---

## 11. Additional Documentation

- Real-world benchmark guide: `docs/real_world_evaluation.md`
- Evaluation script: `tools/evaluate_real_world.py`
- Dataset template: `data/real_world_eval_template.csv`
