import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_override.dart';

/// Runs the editor on in-memory data sources: nothing is stored, and the
/// "Everyone can edit" switch stands in for a real access check.
///
/// A real app implements `L10nAccessDataSource` and
/// `L10nTranslationDataSource` for its backend instead.
void main() {
  final access = InMemoryL10nAccessDataSource();
  final translations = InMemoryL10nTranslationDataSource(
    // What the backend would serve to every user.
    published: {
      'en': {'addPond': 'Add a pond'},
    },
  );
  runApp(ExampleApp(access: access, translations: translations));
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({
    required this.access,
    required this.translations,
    super.key,
  });

  final InMemoryL10nAccessDataSource access;
  final InMemoryL10nTranslationDataSource translations;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  Locale _locale = const Locale('en');

  @override
  Widget build(BuildContext context) {
    return InContextEditor(
      // Pass strings delivered over the air here; they apply to every user.
      delegate: AppLocalizationsOverrideDelegate(
        messages: widget.translations.published,
      ),
      accessDataSource: widget.access,
      translationDataSource: widget.translations,
      label: 'in-memory demo',
      // Any sign-in UI works; this one ships with the package.
      onRequestAccess: (context) => showEmailPasswordSignInDialog(
        context,
        subtitle: 'Use any email and the password "demo".',
        signIn: (email, password) async {
          if (password != 'demo') return 'Wrong password.';
          widget.access.grant(EditorUser(id: email, displayName: email));
          return null;
        },
      ),
      onSignOut: () async => widget.access.revoke(),
      builder: (context, l10n) => MaterialApp(
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          l10n.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: l10n.overlay,
        home: HomePage(
          access: widget.access,
          locale: _locale,
          onLocaleChanged: (locale) => setState(() => _locale = locale),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    required this.access,
    required this.locale,
    required this.onLocaleChanged,
    super.key,
  });

  final InMemoryL10nAccessDataSource access;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _ponds = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          SegmentedButton<Locale>(
            segments: [
              for (final locale in AppLocalizations.supportedLocales)
                ButtonSegment(
                  value: locale,
                  label: Text(locale.languageCode.toUpperCase()),
                ),
            ],
            selected: {widget.locale},
            onSelectionChanged: (s) => widget.onLocaleChanged(s.first),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.greeting('Asha'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l10n.pondCount(_ponds)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => setState(() => _ponds++),
              child: Text(l10n.addPond),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(l10n.canEditLabel),
            value: widget.access.editor != null,
            onChanged: (on) => setState(
              () => on
                  ? widget.access.grant(const EditorUser(id: 'everyone'))
                  : widget.access.revoke(),
            ),
          ),
        ],
      ),
    );
  }
}
