import 'package:flutter/widgets.dart';
import 'strings.dart';

abstract class IdentifierValidator {
  bool matches(String value);
  String? validate(BuildContext context, String value);
}

class EmailIdentifierValidator implements IdentifierValidator {
  static final _re = RegExp(r'^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$');

  const EmailIdentifierValidator();

  @override
  bool matches(String value) => value.contains('@');
  @override
  String? validate(BuildContext context, String value) =>
      _re.hasMatch(value) ? null : context.t('login.invalid_email');
}

class PhoneIdentifierValidator implements IdentifierValidator {
  static final _re = RegExp(r'^[+0-9\s()-]+$');

  const PhoneIdentifierValidator();

  @override
  bool matches(String value) => !value.contains('@');
  @override
  String? validate(BuildContext context, String value) =>
      (value.length >= 6 && _re.hasMatch(value))
          ? null
          : context.t('login.invalid_phone');
}

const _strategies = <IdentifierValidator>[
  EmailIdentifierValidator(),
  PhoneIdentifierValidator(),
];

String? validateIdentifier(BuildContext context, String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return context.t('login.enter_identifier');
  for (final strategy in _strategies) {
    if (strategy.matches(value)) return strategy.validate(context, value);
  }
  return null;
}
