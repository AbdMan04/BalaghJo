
class IdentifierStrategy {
  matches(_raw) {
    throw new Error('IdentifierStrategy.matches() must be overridden');
  }
  toQuery(_raw) {
    throw new Error('IdentifierStrategy.toQuery() must be overridden');
  }
}

class EmailIdentifierStrategy extends IdentifierStrategy {
  matches(raw) {
    return raw.includes('@');
  }
  toQuery(raw) {
    return { email: raw.toLowerCase() };
  }
}

class PhoneIdentifierStrategy extends IdentifierStrategy {
  matches(raw) {
    return !raw.includes('@');
  }
  toQuery(raw) {
    return { phone: raw };
  }
}

const strategies = [
  new EmailIdentifierStrategy(),
  new PhoneIdentifierStrategy(),
];

function resolveIdentifierStrategy(raw) {
  return strategies.find((s) => s.matches(raw)) || null;
}

module.exports = {
  IdentifierStrategy,
  EmailIdentifierStrategy,
  PhoneIdentifierStrategy,
  resolveIdentifierStrategy,
};
