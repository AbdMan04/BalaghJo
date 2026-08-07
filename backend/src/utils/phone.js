// Phone validation — the one definition of a valid citizen phone number
// (Jordanian mobile), shared by every registration/profile/identifier rule
// so the auth surfaces can never drift apart.
const PHONE_RE = /^07[789]\d{7}$/;

function isValidPhone(value) {
  return typeof value === 'string' && PHONE_RE.test(value.trim());
}

module.exports = { PHONE_RE, isValidPhone };
