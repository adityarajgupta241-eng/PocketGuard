# PocketGuard

Zero-touch, local-first expense tracking. Bank and UPI notifications on Android are forwarded to a FastAPI server on your Mac, parsed privately in SQLite, and shown on a dark Flutter dashboard. Nothing is sent to a cloud vendor.

```
pocketguard/
  backend/    FastAPI + SQLite parser
  mobile/     Flutter Android dashboard
```

## Backend

Exact commands:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Find your Mac’s LAN IP (`System Settings → Network`, or `ipconfig getifaddr en0`) and enter it in the app’s Settings sheet.

## Android app

1. Enable **Developer options** and USB debugging, or use a device on the same Wi-Fi network.
2. Allow **Notification access** for PocketGuard (Settings sheet → Enable notification access).
3. Allow cleartext LAN HTTP (already configured).
4. Run:

```bash
cd mobile
flutter pub get
flutter run
```

Pull to refresh or tap **Sync** to call `GET http://<LOCAL_IP>:8000/api/expenses`.
