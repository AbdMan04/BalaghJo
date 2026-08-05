// Runs before every test file: force test env and provide a strong JWT
// secret so the server's startup guard and token signing are happy.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET =
  process.env.JWT_SECRET ||
  'test-only-secret-that-is-at-least-32-characters-long';
process.env.JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '15m';
