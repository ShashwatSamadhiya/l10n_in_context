import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/l10n_in_context.dart';
import 'package:l10n_in_context/src/presentation/pages/l10n_key_table_page.dart';

import '../fixtures.dart';

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final strings = Localizations.of<TestStrings>(context, TestStrings)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text(strings.welcomeTitle), Text(strings.retry)],
        ),
      ),
    );
  }
}

void main() {
  late InMemoryL10nAccessDataSource access;
  late InMemoryL10nTranslationDataSource translations;
  var accessRequests = 0;

  setUp(() {
    access = InMemoryL10nAccessDataSource();
    translations = InMemoryL10nTranslationDataSource(
      drafts: {
        'en': {'retry': 'Try again'},
      },
      published: {
        'en': {'welcomeTitle': 'Hello'},
      },
    );
    accessRequests = 0;
  });

  Widget app({bool enabled = true, bool withAccessRequest = true}) =>
      InContextEditor(
        enabled: enabled,
        delegate: const TestStringsDelegate(
          messages: {
            'en': {'welcomeTitle': 'Hi from OTA'},
          },
        ),
        accessDataSource: access,
        translationDataSource: translations,
        onRequestAccess: withAccessRequest
            ? (context) async => accessRequests++
            : null,
        builder: (context, l10n) => MaterialApp(
          localizationsDelegates: [
            l10n.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          builder: l10n.overlay,
          home: const _Home(),
        ),
      );

  Finder textStartingWith(String text) => find.byWidgetPredicate(
    (w) => w is Text && L10nKeyTag.strip(w.data ?? '') == text,
  );

  testWidgets('without access the app shows its own messages', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Hi from OTA'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit translations'));
    expect(accessRequests, 1);
  });

  testWidgets('no Edit button without onRequestAccess', (tester) async {
    await tester.pumpWidget(app(withAccessRequest: false));
    await tester.pump();
    expect(find.byTooltip('Edit translations'), findsNothing);
  });

  testWidgets('disabled builds the plain app', (tester) async {
    access.grant(testEditor);
    await tester.pumpWidget(app(enabled: false));
    await tester.pump();
    expect(find.text('Hi from OTA'), findsOneWidget);
    expect(find.byTooltip('Pick a text'), findsNothing);
  });

  testWidgets('editors see drafts live and can edit a picked text', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    access.grant(testEditor);
    await tester.pumpAndSettle();

    // Drafts over published over the app's OTA messages, all tagged.
    expect(textStartingWith('Hello'), findsOneWidget);
    expect(textStartingWith('Try again'), findsOneWidget);
    expect(find.byTooltip('Pick a text'), findsOneWidget);

    await tester.tap(find.byTooltip('Pick a text'));
    await tester.pump();
    await tester.tapAt(tester.getCenter(textStartingWith('Try again')));
    await tester.pumpAndSettle();
    expect(find.text('retry'), findsOneWidget);
    // The toolbar would be drawn on top of the dialog.
    expect(find.byTooltip('Pick a text'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Once more');
    await tester.pump();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(translations.drafts['en']!['retry'], 'Once more');
    expect(textStartingWith('Once more'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    // Pick mode is still on, so the next text can be picked straight away.
    expect(find.text('Tap a text to edit it'), findsOneWidget);
    await tester.tapAt(tester.getCenter(textStartingWith('Hello')));
    await tester.pumpAndSettle();
    expect(find.text('welcomeTitle'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Tap a text to edit it'), findsOneWidget);

    access.revoke();
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Pick a text'), findsNothing);
  });

  Future<void> openKeyTable(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    access.grant(testEditor);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('All keys'));
    await tester.pumpAndSettle();
  }

  testWidgets('the toolbar can be dragged but not off screen', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    access.grant(testEditor);
    await tester.pumpAndSettle();

    final handle = find.byIcon(Icons.drag_indicator);
    final start = tester.getCenter(handle);
    await tester.drag(handle, const Offset(-200, -150));
    await tester.pumpAndSettle();
    expect(tester.getCenter(handle), start + const Offset(-200, -150));

    // Its buttons still work after the move.
    await tester.tap(find.byTooltip('Pick a text'));
    await tester.pump();
    expect(find.text('Tap a text to edit it'), findsOneWidget);
    await tester.tap(find.byTooltip('Pick a text'));
    await tester.pump();

    await tester.drag(handle, const Offset(-5000, -5000));
    await tester.pumpAndSettle();
    final screen =
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    final toolbar = tester.getRect(
      find.ancestor(of: handle, matching: find.byType(Material)).first,
    );
    expect(screen.contains(toolbar.topLeft), isTrue);
    expect(screen.contains(toolbar.bottomRight), isTrue);
  });

  testWidgets('All keys opens the key table only once', (tester) async {
    await openKeyTable(tester);
    await tester.tap(find.byTooltip('All keys'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(L10nKeyTablePage), findsNothing);
    expect(textStartingWith('Try again'), findsOneWidget);

    // It opens again once closed.
    await tester.tap(find.byTooltip('All keys'));
    await tester.pumpAndSettle();
    expect(find.byType(L10nKeyTablePage), findsOneWidget);
  });

  testWidgets('the edit dialog discards an unpublished draft', (tester) async {
    await openKeyTable(tester);
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard draft (EN)'));
    await tester.pumpAndSettle();

    expect(translations.drafts['en'], isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Discarded 1 draft.'), findsOneWidget);

    // Nothing left to discard.
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Discard draft'), findsNothing);
  });

  testWidgets('the key table discards every unpublished draft', (tester) async {
    await openKeyTable(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard unpublished drafts…'));
    await tester.pumpAndSettle();
    expect(find.text('Discard 1 unpublished draft?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(translations.drafts['en'], isEmpty);
  });

  testWidgets('export copies the changed messages as ARB', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await openKeyTable(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export ARB…'));
    await tester.pumpAndSettle();

    // Published: only welcomeTitle differs from bundled.
    expect(find.text('1 changed message'), findsOneWidget);
    expect(find.text('Same as bundled'), findsOneWidget);
    await tester.tap(find.text('Copy').first);
    await tester.pumpAndSettle();
    expect(jsonDecode(copied!), {'@@locale': 'en', 'welcomeTitle': 'Hello'});

    // Drafts add the unpublished retry.
    await tester.tap(find.text('Drafts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy').first);
    await tester.pumpAndSettle();
    expect(jsonDecode(copied!), {
      '@@locale': 'en',
      'welcomeTitle': 'Hello',
      'retry': 'Try again',
    });

    // Copy all: every language with changes, as a list.
    await tester.tap(find.text('Copy all languages (2)'));
    await tester.pumpAndSettle();
    expect(jsonDecode(copied!), [
      {'@@locale': 'en', 'welcomeTitle': 'Hello', 'retry': 'Try again'},
    ]);
    expect(find.textContaining('Copied every language.'), findsOneWidget);
  });
}
