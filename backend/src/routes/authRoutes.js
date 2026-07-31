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
    body('phone').isString().trim().matches(/^\d{10}$/).withMessage('Phone must be 10 digits'),
    body('password').isString().isLength({ min: 6 }),
  ],
  ctrl.register
);

router.post(
  '/login',
  loginLimiter,
  [
    body('identifier').isString().trim().matches(/^\d{10}$/).withMessage('Phone must be 10 digits'),
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
    body('phone').optional().isString().trim().isLength({ max: 30 }),
  ],
  ctrl.updateProfile
);

module.exports = router;
