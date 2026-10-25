import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

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

    await tester.enterText(find.byType(TextField), 'Once more');
    await tester.pump();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(translations.drafts['en']!['retry'], 'Once more');
    expect(textStartingWith('Once more'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    access.revoke();
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Pick a text'), findsNothing);
  });
}
