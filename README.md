# Balaghjo

A civic reporting app for the city of Irbid, Jordan. Citizens can report problems like potholes, waste, broken lights etc. with a photo and location, and the municipality can track and resolve them.

## What's in here

- `backend/` — Node.js/Express API (MongoDB)
- `frontend/` — Flutter app (Android + web)

## Backend

```bash
cd backend
cp .env.example .env 
npm install
npm run dev
```

### Useful scripts

- `npm run dev` — start with nodemon
- `npm start` — production start
- `npm test` — run the test suite
- `npm run make-admin 077xxxxxxx` — give a user admin role
- `npm run sync-indexes` — sync Mongo indexes to match the schema

## Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome 
```

For Android: connect a device or start an emulator, same command without `-d chrome`.

## Tech stack

**Backend:** Express, Mongoose, JWT auth, Cloudinary (photos), Firebase (push notifications)

**Frontend:** Flutter, Provider (state), custom i18n (EN/AR)

