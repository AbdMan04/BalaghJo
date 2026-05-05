# BALAGHJO — MongoDB Schema Design

Database: `balaghjo`

## Collection: `users`

| Field | Type | Notes |
|-------|------|-------|
| `_id` | ObjectId | PK |
| `firstName` | String | required |
| `lastName` | String | required |
| `email` | String | unique, required, lowercase, indexed |
| `phone` | String | optional, e.164 (e.g. `+9627XXXXXXXX`) |
| `passwordHash` | String | bcrypt, cost 10 |
| `role` | String | `citizen` \| `admin`, default `citizen` |
| `sentReports` | Number | denormalized counter, default 0 |
| `solvedReports` | Number | denormalized counter, default 0 |
| `createdAt` | Date | auto |
| `updatedAt` | Date | auto |

Indexes: `{ email: 1 } unique`

## Collection: `reports`

| Field | Type | Notes |
|-------|------|-------|
| `_id` | ObjectId | PK |
| `reportId` | String | human code, e.g. `RPT-2401`, unique |
| `userId` | ObjectId | ref `users`, indexed |
| `category` | String | enum: `pothole`, `waste`, `lighting`, `road_crack`, `other` |
| `title` | String | short summary |
| `description` | String | required, max 2000 |
| `photoUrl` | String | served from `/uploads/*` (or S3 in prod) |
| `location` | GeoJSON Point | `{ type: "Point", coordinates: [lng, lat] }`, 2dsphere index |
| `address` | String | reverse-geocoded label, optional |
| `status` | String | enum: `pending` (Sent), `in_progress` (Processing), `resolved`. Default `pending` |
| `priority` | String | `low` \| `medium` \| `high`, default `medium` |
| `assignedTo` | String | dept name, optional |
| `estimatedFix` | Date | optional |
| `statusHistory` | Array | `[{ status, changedAt, changedBy }]` |
| `createdAt` | Date | auto |
| `updatedAt` | Date | auto |

Indexes: `{ userId: 1, createdAt: -1 }`, `{ location: "2dsphere" }`, `{ reportId: 1 } unique`

## Status mapping (UI ↔ DB)

| UI label | DB value |
|----------|----------|
| Sent     | `pending` |
| Processing | `in_progress` |
| Resolved | `resolved` |
