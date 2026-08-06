const router = require('express').Router();
const ctrl = require('../controllers/reportController');
const adminCtrl = require('../controllers/adminController');
const annCtrl = require('../controllers/announcementController');
const { authRequired, adminOnly } = require('../middleware/auth');

// F5 admin dashboard routes — all admin-gated (the citizen report routes
// are untouched; only role=admin JWTs can read the full report feed).
router.use(authRequired, adminOnly);

router.get('/reports', ctrl.listAdminReports);
router.get('/stats', adminCtrl.stats);
router.get('/users', adminCtrl.listUsers);
router.patch('/users/:id/role', adminCtrl.updateRole);
router.get('/announcements', annCtrl.list);
router.post('/announcements', annCtrl.create);

module.exports = router;
