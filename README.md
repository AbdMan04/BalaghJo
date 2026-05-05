# BALAGHJO — Smart Municipality Reporting System (Irbid)

GP1 working prototype: Flutter mobile app + Node.js/Express REST API + MongoDB.

```
.
├── backend/   # Node.js + Express + Mongoose API
├── frontend/  # Flutter mobile app
└── docs/      # Database schema and design notes
```

## Architecture (4-tier)

- **Presentation:** Flutter app (`frontend/`)
- **Application:** Express REST API (`backend/src/app.js`)
- **Business logic:** services/controllers (`backend/src/controllers/`)
- **Data:** MongoDB (Atlas or local) + local file uploads (S3 in production)

Flow: Flutter → HTTPS/JSON → Express → controllers → Mongoose → MongoDB / disk.

## GP1 Scope (this prototype)

- F1 — User auth (register / login / logout) with JWT + bcrypt
- F2 — Report submission (category, description, photo, GPS)
- F3 — Report list & detail view (chronological, status badges)

GP2 will add: real-time status tracking, push notifications, admin dashboard, map view.

---

## 1. Backend — Node.js + Express + MongoDB

### Prerequisites
- Node.js ≥ 18
- MongoDB running locally (`mongodb://127.0.0.1:27017`) or a MongoDB Atlas URI

### Setup
```bash
cd backend
cp .env.example .env       # then edit JWT_SECRET / MONGO_URI
npm install
npm run dev                # http://localhost:4000
```

### Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET    | `/health` | — | Health check |
| POST   | `/api/auth/register` | — | Register `{firstName,lastName,email,password,phone?}` |
| POST   | `/api/auth/login` | — | Login `{email,password}` → `{token,user}` |
| GET    | `/api/auth/me` | Bearer | Current user |
| GET    | `/api/reports/summary` | Bearer | Counters + 3 most recent |
| GET    | `/api/reports?status=` | Bearer | List my reports (filter optional) |
| GET    | `/api/reports/:id` | Bearer | Report detail |
| POST   | `/api/reports` | Bearer | multipart: `photo`, `category`, `description`, `lat`, `lng`, `address?` |
| PATCH  | `/api/reports/:id/status` | Admin | Update status |

Uploaded photos served from `/uploads/<file>`.

### MongoDB schema
See [docs/database-design.md](docs/database-design.md).

---

## 2. Frontend — Flutter

### Prerequisites
- Flutter SDK ≥ 3.19

### Setup
```bash
cd frontend
flutter pub get
# Android emulator (default base URL = http://10.0.2.2:4000)
flutter run
# Real device / iOS sim — point to your machine's LAN IP:
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:4000
```

### Screens implemented

| Spec # | Screen | File |
|--------|--------|------|
| 01 | Splash | `lib/ui/auth/splash_screen.dart` |
| 02 | Onboarding | `lib/ui/auth/onboarding_screen.dart` |
| 03 | Register | `lib/ui/auth/register_screen.dart` |
| 05 | Login | `lib/ui/auth/login_screen.dart` |
| 06 | Home Dashboard | `lib/ui/home/home_screen.dart` |
| 07 | Submit Report | `lib/ui/reports/submit_report_screen.dart` |
| 08 | Report Detail | `lib/ui/reports/report_detail_screen.dart` |
| 09 | My Reports | `lib/ui/reports/my_reports_screen.dart` |
| 10 | Profile | `lib/ui/profile/profile_screen.dart` |

OTP screen (04) is deferred to GP2 along with push notifications.

### Theme
Colors, radii, and typography from the design system (`lib/core/theme.dart`):
Navy `#0D1F3C`, Blue `#1B4FD8`, Sky `#4A9EFF`, plus standard semantic colors.

---

## 3. Quick smoke test

```bash
# 1) start API
cd backend && npm run dev

# 2) register
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Mohammad","lastName":"Ali","email":"m@example.com","password":"secret123","phone":"+962790000000"}'

# 3) submit a report (replace TOKEN)
curl -X POST http://localhost:4000/api/reports \
  -H "Authorization: Bearer TOKEN" \
  -F "category=pothole" \
  -F "description=Large pothole near traffic light" \
  -F "lat=32.5556" -F "lng=35.85" \
  -F "photo=@/path/to/image.jpg"
```

---

## Roadmap → GP2

- Real-time status updates + push notifications (FCM)
- Admin web dashboard (Next.js or React)
- Interactive map of all reports (Mapbox / Google Maps)
- Photo storage on S3
- Session refresh tokens
