import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

import '../fixtures.dart';

void main() {
  const validate = ValidateMessage();
  final pondCount = testCatalog.lookup('pondCount')!;
  final farmerRegistered = testCatalog.lookup('farmerRegistered')!;
  final retry = testCatalog.lookup('retry')!;

  test('accepts every bundled message', () {
    for (final key in testCatalog.keys.where((k) => k.overridable)) {
      for (final MapEntry(key: lang, value: message) in key.bundled.entries) {
        expect(
          validate(message, key, locale: lang),
          isNull,
          reason: '$lang:${key.name}',
        );
      }
    }
  });

  test('rejects empty text', () {
    expect(validate('  ', retry), contains('empty'));
  });

  test('rejects invalid ICU', () {
    expect(
      validate('{count, plural, =0{none}', pondCount),
      contains('Invalid ICU'),
    );
  });

  test('rejects a misspelled placeholder', () {
    expect(
      validate('{nmae} registered', farmerRegistered),
      contains('Unknown placeholder {nmae}'),
    );
  });

  test('rejects a missing placeholder', () {
    expect(
      validate('Farmer registered', farmerRegistered),
      contains('Missing placeholder {name}'),
    );
  });

  test('rejects placeholders on a key without any', () {
    expect(validate('Retry {x}', retry), contains('has no placeholders'));
  });

  test('rejects a plural on a text placeholder', () {
    expect(
      validate('{name, plural, other{x}}', farmerRegistered),
      contains('does not render'),
    );
  });
}
