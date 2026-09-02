# Balaghjo

A civic reporting app for the city of Irbid, Jordan. Citizens can report problems like potholes, waste, broken lights etc. with a photo and location, and the municipality can track and resolve them.

## What's in here

- `backend/` — Node.js/Express API (MongoDB)
- `frontend/` — Flutter app (Android + web)

## Backend

```bash
cd backend
cp .env.example .env   # fill in MONGO_URI, JWT_SECRET
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

## Notes

- Phone numbers must start with `077`, `078`, or `079`
- The map is locked to the Irbid area
- Cloudinary and Firebase are optional — the app runs without them, you just won't get photo hosting or push notifications
- On Render: Cloudinary is required in production (Render disk is ephemeral, photos would get lost)

