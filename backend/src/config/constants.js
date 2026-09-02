/*
- Shared domain constants: report statuses, categories, and the allowed
- status-transition map. Pulled out of Report.js so that models, routes,
- and services can reference them without importing the Report model itself.
 */
const STATUSES = ['pending', 'in_progress', 'resolved'];
const CATEGORIES = ['pothole', 'waste', 'lighting', 'other'];

// F4 / FR-16 controlled workflow: a report can only move forward
// through the lifecycle (Pending -> In Progress -> Resolved).
const STATUS_TRANSITIONS = {
  pending: ['in_progress'],
  in_progress: ['resolved'],
  resolved: [],
};

module.exports = { STATUSES, CATEGORIES, STATUS_TRANSITIONS };