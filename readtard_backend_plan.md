# Readtard Backend Integration Plan (Swift App ↔ Python Backend → Cloud Run)

## Goal

Build a minimal working integration between:

- SwiftUI iPhone app frontend
- Python ReadingSession backend
- FastAPI interface layer
- Deployment-ready architecture for Google Cloud Run

Target milestone:

> User presses “Ask Me” in the app → backend receives position → user asks question → backend returns answer → displayed in app

Final deployment target:

> Google Cloud Run containerized backend service

Prototype constraints:

- One user
- One book
- One active session
- In‑memory state allowed
- Session loss after restart acceptable
- No persistence required yet

---

# Architecture Overview

## Runtime Flow

App launch:

Backend already initialized

Ask button pressed:

POST /set_position

User submits question:

POST /ask

Backend response returned to Swift UI

---

# Backend Architecture Strategy

We intentionally use:

single-process  
single-session  
stateful in-memory backend

This keeps latency low and complexity minimal.

Session lifecycle:

Created at backend startup  
Destroyed on backend restart  
Optional timeout later (30 min inactivity)

This is acceptable for demo stage.

---

# Deployment Strategy (Important)

Development path:

Stage 1:

Local FastAPI service on laptop

Stage 2:

Docker containerization

Stage 3:

Deploy same container to Google Cloud Run

This avoids rewriting backend later.

Everything we build locally must remain Cloud Run compatible.

---

.
├── app/
│   ├── api/                # add this
│   │   ├── __init__.py
│   │   ├── routes.py
│   │   └── schemas.py
│   ├── book/
│   ├── index/
│   ├── llm/
│   ├── prompts/
│   ├── session/
│   ├── config.py
│   ├── environment.py
│   └── main.py             # FastAPI app entrypoint
├── data/
├── persist_dir/
├── pyproject.toml
├── Dockerfile              # later
└── uv.lock

# Backend Initialization Model

Session created once at startup

Example structure:

initialize_environment()

create_llm()

ReadingSession()

load_book()

Stored globally:

session

Endpoints reuse same instance.

---

# Required API Endpoints

POST /set_position

Input:

LAST_READ_SENTENCE

Executes:

session.set_position()

---

POST /ask

Input:

QUERY

Executes:

session.ask()

Returns:

answer

---

Optional

GET /health

Returns:

status OK

Used by Swift app and Cloud Run health checks

---

# Important Performance Rule

Do NOT use:

force_reindex=True

during runtime requests

Only use once during index creation phase.

Production-safe default:

force_reindex=False

---

# FastAPI Lifecycle Model

Session created inside startup hook

Example lifecycle:

server starts

startup hook executes

session initialized

API ready instantly afterwards

Compatible with Cloud Run container lifecycle

---

# Swift App Integration Plan

When Ask screen opens:

(Optional)

GET /health

Verify backend reachable

---

When user presses Ask Me:

POST /set_position

Payload:

LAST_READ_SENTENCE

---

When user submits question:

POST /ask

Payload:

QUERY

Display response text

---

# Local Testing Plan

Run backend:

uvicorn main:app --reload

Test endpoints:

curl /health

curl /set_position

curl /ask

Then connect Swift app to:

http://<your-mac-ip>:8000

Example:

http://192.168.1.12:8000

Phone must be on same WiFi network

---

# Optional Remote Testing (If Needed)

Use ngrok

Command:

ngrok http 8000

Produces:

https://xxxx.ngrok.io

Use that URL inside Swift app

---

# Preparing for Cloud Run (Design Constraints)

Backend must:

Avoid filesystem assumptions

Avoid local-only paths

Load environment variables correctly

Bind server to:

0.0.0.0

Use:

PORT environment variable

Example:

uvicorn main:app --host 0.0.0.0 --port $PORT

---

# Containerization Plan (Later Step)

Add:

Dockerfile

requirements.txt

Cloud Run expects container exposing HTTP server

Nothing else changes

---

# Cloud Run Deployment Goal

Final architecture:

Swift App

calls

Cloud Run HTTPS endpoint

running

FastAPI ReadingSession backend

Session lifecycle:

created on container startup

destroyed when container recycled

acceptable for demo stage

---

# Future Production Improvements (Not Required Yet)

Session persistence

Multi-book support

Multi-user isolation

Index caching layer

Vector store externalization

Authentication

Streaming responses

None required for demo

---

# Current Target Milestone

Achieve:

Swift button press

→ backend request

→ session.ask()

→ response returned

→ response rendered on device

Once working:

deploy same backend container to Cloud Run
