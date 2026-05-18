# BalaghJo

A civic-reporting mobile application that lets citizens submit issues
(potholes, waste, lighting) with a photo and GPS location,
track their reports through a status timeline, and view a community map
of nearby reports.

This repository contains the GP1 prototype: a working citizen-side app
backed by a REST API. An admin dashboard is planned for GP2.

## Tech stack

- **Backend:** Node.js, Express, MongoDB Atlas (Mongoose), JWT auth, bcrypt
- **Frontend:** Flutter (Dart), Provider for state, `flutter_map` for the map
- **Storage:** GridFS via Multer for report photos
- **Patterns used:** Strategy (login identifier resolution), Singleton (API client),
  Observer (Provider / ChangeNotifier)

## Repository layout

```
backend/      Node.js + Express REST API
frontend/     Flutter mobile app
docs/         UML diagrams, screenshots
```

Each module has its own README explaining what it contains and how
the pieces fit together. Start with the per-folder READMEs under
`backend/src/` and `frontend/lib/` when exploring the code.

## Running the backend

```bash
cd backend
npm install
cp .env.example .env       # fill in MONGO_URI and JWT_SECRET
npm run dev                # starts on http://localhost:4000
```

Required environment variables (see `backend/.env.example`):
`MONGO_URI`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `CORS_ORIGINS`, `PORT`.

## Running the frontend

```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:4000
```

Replace `<your-lan-ip>` with the IP of the machine running the backend
(e.g., `192.168.1.20`). The phone and the backend must be on the same
Wi-Fi network. The base URL defaults to a development value if you skip
the flag — see `frontend/lib/core/config.dart`.

## Verification flow (GP1)

The 6-digit verification code is **logged to the backend console**
(simulated delivery — no SMS/email gateway integration in GP1). After
registering, watch the backend terminal for a line like:

```
[verify] Code for +962XXXXXXXXX: 123456 (expires in 10m)
```

Enter that code on the verification screen.

## Team

Final-year project (GP1), Software Engineering — 2025/26.
