import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/src/core/l10n/l10n_key_tag.dart';
import 'package:l10n_in_context/src/presentation/widgets/tagged_text_finder.dart';

import '../fixtures.dart';

String _tag(String key, String text) =>
    text + KeyTagCodec.encode(testCatalog.indexOf(key)!);

void main() {
  final rootKey = GlobalKey();
  final navigatorKey = GlobalKey<NavigatorState>();

  RenderBox root(WidgetTester tester) =>
      rootKey.currentContext!.findRenderObject()! as RenderBox;

  Future<void> pump(WidgetTester tester, Widget home) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => KeyedSubtree(key: rootKey, child: child!),
      home: home,
    ),
  );

  testWidgets('picks the key of tapped text, including inside buttons', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: Column(
          children: [
            Text(_tag('welcomeTitle', 'Welcome')),
            FilledButton(onPressed: () {}, child: Text(_tag('retry', 'Retry'))),
            const Text('Untagged'),
          ],
        ),
      ),
    );

    Offset centerOf(String text) => tester.getCenter(find.textContaining(text));
    List<String> keysAtText(String text) =>
        keysAt(testCatalog, root(tester), centerOf(text));
    expect(keysAtText('Welcome'), ['welcomeTitle']);
    expect(keysAtText('Retry'), ['retry']);
    expect(keysAtText('Untagged'), isEmpty);
  });

  testWidgets('falls back to bounds for text under IgnorePointer', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(body: IgnorePointer(child: Text(_tag('getStarted', 'Go')))),
    );
    final center = tester.getCenter(find.textContaining('Go'));
    expect(keysAt(testCatalog, root(tester), center), ['getStarted']);
  });

  testWidgets('highlights only text on the visible route', (tester) async {
    await pump(tester, Scaffold(body: Text(_tag('welcomeTitle', 'Home'))));
    expect(findTaggedTexts(testCatalog, root(tester)).single.keys, [
      'welcomeTitle',
    ]);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Text(_tag('retry', 'Next'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      findTaggedTexts(testCatalog, root(tester)).expand((t) => t.keys).toList(),
      ['retry'],
    );
  });

  test('ignores indexes outside the catalog', () {
    expect(
      keysIn(testCatalog, 'x${KeyTagCodec.encode(testCatalog.keys.length)}'),
      isEmpty,
    );
  });
}
