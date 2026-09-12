# PocketGuard Android app

Dark-themed dashboard for expenses stored on your local PocketGuard API.

## Run

```bash
flutter pub get
flutter run
```

Set the Mac LAN IP in Settings. Grant notification listener access so bank SMS/app alerts are posted to `POST /api/notifications` automatically.

Android already includes:

- `INTERNET` / `ACCESS_NETWORK_STATE`
- `usesCleartextTraffic` for `http://192.168.x.x:8000`
- `ExpenseNotificationListener` service
