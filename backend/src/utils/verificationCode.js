const crypto = require('crypto');
const bcrypt = require('bcryptjs');

const CODE_TTL_MINUTES = 10;

function generateCode() {
  return crypto.randomInt(100000, 1000000).toString();
}

async function hashCode(code) {
  return bcrypt.hash(code, 8);
}

function compareCode(plain, hash) {
  if (!hash) return Promise.resolve(false);
  return bcrypt.compare(plain, hash);
}

function expiryFromNow() {
  return new Date(Date.now() + CODE_TTL_MINUTES * 60 * 1000);
}

function logSimulatedDelivery(channel, recipient, code) {
  // In production this would dispatch via SendGrid/Twilio/etc.
  // For the prototype we log the code so a demo audience can read it.
  // eslint-disable-next-line no-console
  console.log(
    `\n[verification] code for ${channel} "${recipient}": ${code} (expires in ${CODE_TTL_MINUTES} min)\n`
  );
}

module.exports = {
  CODE_TTL_MINUTES,
  generateCode,
  hashCode,
  compareCode,
  expiryFromNow,
  logSimulatedDelivery,
};
