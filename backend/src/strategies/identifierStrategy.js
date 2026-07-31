/**
 * IdentifierStrategy — Strategy design pattern (imported from SE324).
 *
 * Encapsulates the rule for resolving a login identifier (always a
 * phone number) so that the auth controller stays free of if/else
 * branches. Each concrete strategy answers two questions: does this
 * strategy apply to the raw input (matches), and how do I turn that
 * input into a Mongoose query (toQuery). Adding a new identifier type
 * means adding one class to the strategies list — no controller changes.
 */
class IdentifierStrategy {
  matches(_raw) {
    throw new Error('IdentifierStrategy.matches() must be overridden');
  }
  toQuery(_raw) {
    throw new Error('IdentifierStrategy.toQuery() must be overridden');
  }
}

class PhoneIdentifierStrategy extends IdentifierStrategy {
  matches(_raw) {
    return true;
  }
  toQuery(raw) {
    return { phone: raw };
  }
}

const strategies = [new PhoneIdentifierStrategy()];

function resolveIdentifierStrategy(raw) {
  return strategies.find((s) => s.matches(raw)) || null;
}

module.exports = {
  IdentifierStrategy,
  PhoneIdentifierStrategy,
  resolveIdentifierStrategy,
};
