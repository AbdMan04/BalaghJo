// TtlCache — tiny in-memory TTL cache with a bounded entry count.
// Used for read-only endpoints (report summary, public map list) so that
// the app's foreground polling collapses many identical requests into one
// upstream query. Write endpoints invalidate the relevant keys, so the
// cache never serves stale data after a mutation.
//
// NOTE: bounded per Node process. With multiple cluster workers each worker
// keeps its own cache — still correct, just up to N upstream fetches per TTL
// window instead of one.
class TtlCache {
  constructor({ maxEntries = 250 } = {}) {
    this.maxEntries = maxEntries;
    this._map = new Map();
  }

  // Returns the cached value for [key] if it was set less than [ttlMs]
  // ago, else null.
  get(key, ttlMs) {
    const entry = this._map.get(key);
    if (!entry) return null;
    if (Date.now() - entry.at > ttlMs) {
      this._map.delete(key);
      return null;
    }
    return entry.value;
  }

  set(key, value) {
    if (this._map.size >= this.maxEntries) {
      // Map preserves insertion order, so the first key is the oldest.
      const oldest = this._map.keys().next().value;
      this._map.delete(oldest);
    }
    this._map.set(key, { at: Date.now(), value });
  }

  delete(key) {
    this._map.delete(key);
  }

  clear() {
    this._map.clear();
  }
}

module.exports = { TtlCache };
