// escapeRegExp — escape user input before it is embedded in a RegExp used
// as a search pattern. Without this, a crafted query (e.g. `(.*)*`) becomes
// a catastrophic-backtracking regex (ReDoS) and arbitrary regex metacharacters
// let a user reshape the search. Applied wherever admin search still uses
// $regex (substring matching); text-indexed search has no regex semantics.
function escapeRegExp(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

module.exports = { escapeRegExp };
