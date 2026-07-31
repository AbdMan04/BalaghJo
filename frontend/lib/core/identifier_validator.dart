import 'package:flutter/widgets.dart';
import 'strings.dart';

abstract class IdentifierValidator {
  bool matches(String value);
  String? validate(BuildContext context, String value);
}

class PhoneIdentifierValidator implements IdentifierValidator {
  static final _re = RegExp(r'^[0-9]{10}$');

  const PhoneIdentifierValidator();

  @override
  bool matches(String value) => value.isNotEmpty;
  @override
  String? validate(BuildContext context, String value) =>
      _re.hasMatch(value) ? null : context.t('login.invalid_phone');
}

const _strategies = <IdentifierValidator>[
  PhoneIdentifierValidator(),
];

String? validateIdentifier(BuildContext context, String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return context.t('login.enter_phone');
  for (final strategy in _strategies) {
    if (strategy.matches(value)) return strategy.validate(context, value);
  }
  return null;
}
