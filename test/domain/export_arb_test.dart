import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

import '../fixtures.dart';

void main() {
  const export = ArbExport(testCatalog);

  group('changes', () {
    test('keeps only messages that differ from bundled, in catalog order', () {
      expect(
        export.changes({
          'en': {
            'getStarted': 'Start now',
            'retry': 'Retry',
            'welcomeTitle': 'Hello',
          },
          'hi': {'retry': 'फिर से प्रयास करें'},
        }),
        {
          'en': {'welcomeTitle': 'Hello', 'getStarted': 'Start now'},
        },
      );
    });

    test('ignores unknown keys and languages', () {
      expect(
        export.changes({
          'en': {'notAKey': 'x'},
          'fr': {'retry': 'Réessayer'},
        }),
        isEmpty,
      );
    });
  });

  test('arb writes @@locale first and ends with a newline', () {
    final arb = export.arb('hi', {'retry': 'फिर से'});
    expect(arb, endsWith('}\n'));
    expect(jsonDecode(arb), {'@@locale': 'hi', 'retry': 'फिर से'});
    expect(arb.indexOf('@@locale'), lessThan(arb.indexOf('retry')));
  });

  test('arbs writes every language as a list of ARB objects', () {
    final arbs = export.arbs({
      'en': {'retry': 'Again'},
      'hi': {'retry': 'फिर से'},
    });
    expect(arbs, endsWith(']\n'));
    expect(jsonDecode(arbs), [
      {'@@locale': 'en', 'retry': 'Again'},
      {'@@locale': 'hi', 'retry': 'फिर से'},
    ]);
  });
}
