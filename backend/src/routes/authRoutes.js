const router = require('express').Router();
const { body } = require('express-validator');
const { rateLimit, ipKeyGenerator } = require('express-rate-limit');
const ctrl = require('../controllers/authController');
const { authRequired } = require('../middleware/auth');
const { isValidPhone } = require('../utils/phone');

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

// Per-phone lockout: the per-IP limiter alone doesn't stop a distributed
// brute force of a single account, so throttle by the identifier too.
const phoneLoginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const id = String((req.body && req.body.identifier) || '').trim();
    return id ? `login:${id}` : ipKeyGenerator(req);
  },
  message: { error: 'Too many attempts for this phone number. Try again in a few minutes.' },
});

const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many token refreshes. Try again in a few minutes.' },
});

const isTest = process.env.NODE_ENV === 'test';
const limiter = (l) => (isTest ? [] : [l]);

router.post(
  '/register',
  ...limiter(registerLimiter),
  [
    body('firstName').isString().trim().notEmpty(),
    body('lastName').isString().trim().notEmpty(),
    body('phone').isString().trim().custom(isValidPhone).withMessage('Phone must start with 077, 078, or 079'),
    body('password').isString().isLength({ min: 6 }),
  ],
  ctrl.register
);

router.post(
  '/login',
  ...limiter(loginLimiter),
  ...limiter(phoneLoginLimiter),
  [
    body('identifier').isString().trim().custom(isValidPhone).withMessage('Phone must start with 077, 078, or 079'),
    body('password').isString().notEmpty().withMessage('Enter your password'),
  ],
  ctrl.login
);

router.post(
  '/refresh',
  ...limiter(refreshLimiter),
  [body('refreshToken').isString().trim().notEmpty()],
  ctrl.refresh
);

router.post('/logout', authRequired, ctrl.logout);

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
      .custom((v) => v === '' || isValidPhone(v))
      .withMessage('Phone must start with 077, 078, or 079'),
    // Phone is the login identifier: require the password before it changes.
    body('currentPassword')
      .if(body('phone').exists())
      .isString()
      .notEmpty()
      .withMessage('Current password is required to change your phone number'),
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
