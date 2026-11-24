# Collecting the NFR measurements

How to produce the trial data for FR-11/12/17/18/19 and NFR-6 to NFR-10 with the logging built into the app and the API.

## Before you start

- **Test data.** Seed reports from `backend/`. The script prints the target database and only writes with `--yes`:
  ```bash
  npm run seed -- 500 --yes     # NFR-10 dataset (map)
  npm run seed -- 1000 --yes    # NFR-8 dataset (dashboard), FR-19 audit
  npm run seed -- --clear --yes # remove all seeded reports afterwards
  ```
  Seeded reports belong to one seed account (`0790000000`) and appear on the public map like real ones, so clear them when done.
- **Clocks.** Latencies compare the phone's clock with the server's. Keep test devices on automatic (network) time.
- **95th percentile over 20 trials** (nearest rank): sort the 20 values and take the 19th.

## Where the logs are

| Source | How to read it | Lines |
|---|---|---|
| Android app | `adb logcat \| grep "\[perf\]"` (or `flutter logs`) | `[perf] <time> status_seen …`, `push_received …`, `map_render …` |
| Web dashboard | Browser DevTools → Console | `[perf] <time> dashboard_load ms=… rows=…` |
| API server | Render → Logs (or the local terminal) | `[status-update] <time> report=RPT-… -> resolved`, `[notif] … created=1 …`, `[push] … sent=… durationMs=…` |
| MongoDB | `db.pushlogs.find({ reportId: "RPT-0001" })` | One document per fan-out: `eventAt`, `startedAt`, `finishedAt`, `durationMs`, `tokens`, `sent`, `failed` (kept 90 days) |

## Per requirement

| Req | Procedure (20 trials unless stated) | Value to record | Target |
|---|---|---|---|
| FR-11 / NFR-6 | Open the report on the phone (detail screen or My Reports). Change its status on the dashboard. | `status_seen latencyMs` (app time − server `[status-update]` time) | p95 ≤ 5000 ms |
| FR-12 / FR-17 | Run 20 status changes. | Count `[notif] created=1 type=report_status` lines and `pushlogs` documents. Both must equal 20, with one per change and none for other users. Tap each notification: the same report must open. | 100 % |
| NFR-7 / NFR-9 | Same as above, with the app in the background and in the foreground, on three Android devices for NFR-9. | `push_received latencyMs` (device arrival − status save). The `pushlogs` `durationMs` is the server-side share. | p95 ≤ 10 000 ms |
| NFR-8 | Seed 1000 reports. Open the dashboard's Reports tab in Chrome. | `dashboard_load ms`. Cross-check in DevTools → Performance. | ≤ 5000 ms |
| NFR-10 | Seed 500 reports. Open the citizen map. | `map_render ms` and `pins` | ≤ 4000 ms |
| FR-18 | Open the map zoomed out over Irbid. | `map_render pins` against `db.reports.countDocuments({ "location.coordinates": { $ne: [0, 0] } })` | Equal |
| FR-19 | With 100, 500 and 1000 seeded reports: zoom out, then zoom in. | Clusters (numbered bubbles) appear when more than 50 pins are in view and split into single pins at 50 or fewer. Legend shows the 4 category colours plus the cluster bubble. Check on the citizen map and on the dashboard Map tab. | Pass / fail |
