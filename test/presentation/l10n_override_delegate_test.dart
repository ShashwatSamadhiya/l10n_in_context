import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/l10n_in_context.dart';
import 'package:l10n_in_context/src/presentation/widgets/tagged_text_finder.dart';

import '../fixtures.dart';

void main() {
  const hindi = Locale('hi');
  final bundled = TestStrings('hi');

  Future<TestStrings> load(MessagesByLanguage messages, {bool tag = false}) =>
      TestStringsDelegate(messages: messages, tagKeys: tag).load(hindi);

  test('uses the override message when present', () async {
    final l10n = await load({
      'hi': {'retry': 'दोबारा कोशिश करें'},
    });
    expect(l10n.retry, 'दोबारा कोशिश करें');
  });

  test('falls back per key when the override is missing', () async {
    final l10n = await load({
      'hi': {'retry': 'X'},
    });
    expect(l10n.getStarted, bundled.getStarted);
  });

  test('falls back when the override is empty', () async {
    final l10n = await load({
      'hi': {'retry': ''},
    });
    expect(l10n.retry, bundled.retry);
  });

  test('falls back when the override is malformed', () async {
    final l10n = await load({
      'hi': {'farmerRegistered': '{nmae} पंजीकृत'},
    });
    expect(l10n.farmerRegistered('Ramesh'), bundled.farmerRegistered('Ramesh'));
  });

  test('formats placeholders and plurals', () async {
    final l10n = await load({
      'hi': {
        'farmerRegistered': '{name} का पंजीकरण हो गया',
        'pondCount': '{count, plural, =0{कोई नहीं} other{# तालाब}}',
      },
    });
    expect(l10n.farmerRegistered('Ramesh'), 'Ramesh का पंजीकरण हो गया');
    expect(l10n.pondCount(0), 'कोई नहीं');
    expect(l10n.pondCount(4), '4 तालाब');
  });

  test('ignores messages for another language', () async {
    final l10n = await load({
      'en': {'retry': 'Try again'},
    });
    expect(l10n.retry, bundled.retry);
  });

  test('prefers an exact locale match over the language', () async {
    const delegate = TestStringsDelegate(
      messages: {
        'hi': {'retry': 'language'},
        'hi_IN': {'retry': 'exact'},
      },
    );
    expect((await delegate.load(const Locale('hi', 'IN'))).retry, 'exact');
    expect((await delegate.load(hindi)).retry, 'language');
  });

  test('reloads only when messages or tagging change', () {
    const a = TestStringsDelegate(
      messages: {
        'hi': {'retry': 'A'},
      },
    );
    expect(
      const TestStringsDelegate(
        messages: {
          'hi': {'retry': 'A'},
        },
      ).shouldReload(a),
      isFalse,
    );
    expect(
      const TestStringsDelegate(
        messages: {
          'hi': {'retry': 'B'},
        },
      ).shouldReload(a),
      isTrue,
    );
    expect(a.copyWith(tagKeys: true).shouldReload(a), isTrue);
  });

  group('edit mode', () {
    test('tags override and bundled strings with their key', () async {
      final l10n = await load({
        'hi': {'retry': 'फिर से'},
      }, tag: true);
      expect(keysIn(testCatalog, l10n.retry), ['retry']);
      expect(L10nKeyTag.strip(l10n.retry), 'फिर से');
      expect(keysIn(testCatalog, l10n.getStarted), ['getStarted']);
    });

    test('tags bundled-only keys too', () async {
      final l10n = await load(const {}, tag: true);
      final seen = l10n.lastSeen(DateTime(2026));
      expect(keysIn(testCatalog, seen), ['lastSeen']);
      expect(L10nKeyTag.strip(seen), bundled.lastSeen(DateTime(2026)));
    });

    test('does not tag outside edit mode', () async {
      final l10n = await load({
        'hi': {'retry': 'फिर से'},
      });
      expect(l10n.retry, 'फिर से');
    });
  });
}
