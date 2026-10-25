import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

import '../fixtures.dart';

void main() {
  const snapshot = TranslationSnapshot(
    drafts: {
      'en': {'retry': 'Try again'},
    },
    published: {
      'en': {'retry': 'Retry', 'getStarted': 'Start'},
      'hi': {'getStarted': 'शुरू करें'},
    },
  );

  test('drafts overlay published messages', () {
    expect(snapshot.effectiveDraft('en'), {
      'retry': 'Try again',
      'getStarted': 'Start',
    });
  });

  test('lists only keys whose draft differs from published', () {
    expect(snapshot.unpublishedKeys(testCatalog), {
      'en': ['retry'],
    });
  });

  test('imports bundled text only for overridable keys without OTA text', () {
    final missing = snapshot.missingFromBundled(testCatalog);
    final overridable = testCatalog.keys.where((k) => k.overridable).length;
    expect(missing['en']!.keys, isNot(contains('retry')));
    expect(missing['en']!.length, overridable - 2);
    expect(missing['hi']!.length, overridable - 1);
    expect(missing['en']!.containsKey('lastSeen'), isFalse);
  });
}
