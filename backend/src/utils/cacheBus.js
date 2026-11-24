/*
- cacheBus — cross-worker cache invalidation (FR-11 / NFR-6).
- The read caches (TtlCache) live in each cluster worker's memory, so a write
  handled by worker A used to leave worker B serving the stale entry until its
  TTL ran out — up to 15s of extra status lag for a citizen whose poll landed
  on B. publish() now runs the local handlers immediately and, inside a
  cluster worker, forwards the event over IPC; the primary relays it to every
  other worker (attachPrimaryRelay), whose handlers then clear their copies.
- Single-process mode (tests, DISABLE_CLUSTER=1) needs no IPC: publish() is
  just a synchronous local call.
 */
const cluster = require('cluster');

const TAG = '__cacheBus';
const handlers = new Map(); // channel -> Set<fn>

function subscribe(channel, fn) {
  if (!handlers.has(channel)) handlers.set(channel, new Set());
  handlers.get(channel).add(fn);
}

function deliver(channel, payload) {
  for (const fn of handlers.get(channel) || []) {
    try {
      fn(payload);
    } catch (err) {
      console.error(`[cacheBus] handler for ${channel} failed:`, err.message);
    }
  }
}

function publish(channel, payload) {
  deliver(channel, payload);
  if (cluster.isWorker && typeof process.send === 'function') {
    process.send({ [TAG]: channel, payload });
  }
}

// Worker side: events relayed by the primary from sibling workers.
function receive(msg) {
  if (msg && typeof msg[TAG] === 'string') deliver(msg[TAG], msg.payload);
}

if (cluster.isWorker) process.on('message', receive);

// Primary side: fan each worker's event out to every *other* worker.
function attachPrimaryRelay(clusterModule = cluster) {
  clusterModule.on('message', (worker, msg) => {
    if (!msg || typeof msg[TAG] !== 'string') return;
    for (const id of Object.keys(clusterModule.workers || {})) {
      const w = clusterModule.workers[id];
      if (w && w !== worker && w.isConnected()) w.send(msg);
    }
  });
}

module.exports = { subscribe, publish, attachPrimaryRelay, _receive: receive };
