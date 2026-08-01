const router = require('express').Router();
const { authRequired } = require('../middleware/auth');
const ctrl = require('../controllers/notificationController');

router.use(authRequired);

router.get('/', ctrl.list);
router.patch('/read', ctrl.markRead);

module.exports = router;
