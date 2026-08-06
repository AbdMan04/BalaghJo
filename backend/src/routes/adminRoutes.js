const router = require('express').Router();
const ctrl = require('../controllers/reportController');
const { authRequired, adminOnly } = require('../middleware/auth');

// F5 admin dashboard routes — all admin-gated (the citizen report routes
// are untouched; only role=admin JWTs can read the full report feed).
router.use(authRequired, adminOnly);

router.get('/reports', ctrl.listAdminReports);

module.exports = router;