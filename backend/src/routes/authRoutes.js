const router = require('express').Router();
const { body } = require('express-validator');
const rateLimit = require('express-rate-limit');
const ctrl = require('../controllers/authController');
const { authRequired } = require('../middleware/auth');

const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many sign-up attempts. Try again later.' },
});

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts. Try again in a few minutes.' },
});

router.post(
  '/register',
  registerLimiter,
  [
    body('firstName').isString().trim().notEmpty(),
    body('lastName').isString().trim().notEmpty(),
    body('phone').isString().trim().matches(/^07[789]\d{7}$/).withMessage('Phone must start with 077, 078, or 079'),
    body('password').isString().isLength({ min: 6 }),
  ],
  ctrl.register
);

router.post(
  '/login',
  loginLimiter,
  [
    body('identifier').isString().trim().matches(/^07[789]\d{7}$/).withMessage('Phone must start with 077, 078, or 079'),
    body('password').isString().notEmpty().withMessage('Enter your password'),
  ],
  ctrl.login
);

router.get('/me', authRequired, ctrl.me);

router.patch(
  '/password',
  authRequired,
  [
    body('currentPassword').isString().notEmpty().withMessage('Current password required'),
    body('newPassword').isString().isLength({ min: 6 }).withMessage('New password must be at least 6 characters'),
  ],
  ctrl.changePassword
);

router.patch(
  '/profile',
  authRequired,
  [
    body('firstName').optional().isString().trim().isLength({ min: 1, max: 50 }),
    body('lastName').optional().isString().trim().isLength({ min: 1, max: 50 }),
    body('phone')
      .optional()
      .custom((v) => v === '' || /^07[789]\d{7}$/.test(v))
      .withMessage('Phone must start with 077, 078, or 079'),
  ],
  ctrl.updateProfile
);

router.post(
  '/device-token',
  authRequired,
  [body('token').isString().trim().isLength({ min: 10, max: 512 })],
  ctrl.registerDeviceToken
);

router.delete(
  '/device-token',
  authRequired,
  [body('token').isString().trim().isLength({ min: 10, max: 512 })],
  ctrl.unregisterDeviceToken
);

module.exports = router;
