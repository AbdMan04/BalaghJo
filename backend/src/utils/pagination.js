/*
- Shared pagination helper. Accepts an optional page-size value from the
- query string and clamps it between 1 and the caller-defined maximum.
  The same logic was duplicated in reportController.js and adminController.js
  with different max values — this is the single source of truth.
 */
function parsePageSize(raw, { defaultSize = 50, maxSize = 100 } = {}) {
  const n = Number(raw);
  if (!Number.isFinite(n)) return defaultSize;
  return Math.min(Math.max(1, Math.trunc(n)), maxSize);
}

module.exports = { parsePageSize };