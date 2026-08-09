const router = require('express').Router();
const { authRequired } = require('../middleware/auth');
const ctrl = require('../controllers/notificationController');

router.use(authRequired);

router.get('/', ctrl.list);
router.get('/unread-count', ctrl.unreadCount);
router.patch('/read', ctrl.markRead);
router.delete('/', ctrl.remove);

module.exports = router;
