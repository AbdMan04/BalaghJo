const router = require('express').Router();
const { body } = require('express-validator');
const ctrl = require('../controllers/reportController');
const { authRequired, adminOnly } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.use(authRequired);

router.get('/summary', ctrl.summary);
router.get('/public', ctrl.listPublicReports);
router.get('/', ctrl.listMyReports);
router.get('/:id', ctrl.getReport);

router.post(
  '/',
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
