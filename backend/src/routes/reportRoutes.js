const router = require('express').Router();
const { body } = require('express-validator');
const rateLimit = require('express-rate-limit');
const ctrl = require('../controllers/reportController');
const { authRequired, adminOnly } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.use(authRequired);

// Stricter limiter on report creation to throttle photo upload spam.
const createLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many reports submitted. Try again later.' },
});

router.get('/summary', ctrl.summary);
router.get('/public', ctrl.listPublicReports);
router.get('/', ctrl.listMyReports);
router.get('/:id', ctrl.getReport);

router.post('/nearby', ctrl.nearbyReports);

router.post(
  '/',
  createLimiter,
  upload.single('photo'),
  [
    body('category').isIn(['pothole', 'waste', 'lighting', 'other']),
    body('description').isString().isLength({ min: 5, max: 2000 }),
    body('lat').optional().isFloat(),
    body('lng').optional().isFloat(),
  ],
  ctrl.createReport
);

router.delete('/:id', ctrl.deleteReport);

router.patch('/:id/status', adminOnly, ctrl.updateStatus);

module.exports = router;
