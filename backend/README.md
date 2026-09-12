# PocketGuard API

Local-first FastAPI service that ingests Android notifications, filters non-financial noise, and stores parsed expenses in SQLite (`expenses.db`).

## Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run (bind to all interfaces so the phone can reach your Mac)

```bash
cd backend
source .venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The dashboard and Android app should use `http://<YOUR_LAN_IP>:8000`.

- Health: `GET http://127.0.0.1:8000/health`
- Ingest: `POST http://127.0.0.1:8000/api/notifications`
- List: `GET http://127.0.0.1:8000/api/expenses`

Example ingest:

```bash
curl -X POST http://127.0.0.1:8000/api/notifications \
  -H "Content-Type: application/json" \
  -d '{"package_name":"com.google.android.gms","title":"HDFC Bank","text":"Rs. 499.00 debited from A/c XX1234 at Swiggy on 12-09-26","timestamp":"2026-09-12T06:30:00Z"}'
```

## Tests

```bash
cd backend
source .venv/bin/activate
python -m unittest discover -s tests -v
```
