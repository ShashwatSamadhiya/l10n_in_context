// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: lib/l10n/app_localizations.dart and the ARB files in lib/l10n
// Regenerate: dart run l10n_in_context:generate

import 'package:flutter/widgets.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

import 'app_localizations.dart';

/// Every ARB key in template order, for the in-context editor.
const L10nCatalog appLocalizationsCatalog = L10nCatalog(
  languages: ['en', 'hi'],
  keys: [
    L10nKeyInfo(
      name: 'appTitle',
      description: 'App bar title',
      placeholders: [],
      bundled: {'en': 'Pond diary', 'hi': 'तालाब डायरी'},
      overridable: true,
    ),
    L10nKeyInfo(
      name: 'greeting',
      description: 'Greeting on the home screen',
      placeholders: [
        L10nPlaceholder(name: 'name', type: 'String', example: 'Asha'),
      ],
      bundled: {'en': 'Good morning, {name}', 'hi': 'सुप्रभात, {name}'},
      overridable: true,
    ),
    L10nKeyInfo(
      name: 'pondCount',
      description: 'Number of ponds the user owns',
      placeholders: [L10nPlaceholder(name: 'count', type: 'int')],
      bundled: {
        'en':
            '{count, plural, =0{No ponds yet} =1{1 pond} other{{count} ponds}}',
        'hi':
            '{count, plural, =0{अभी कोई तालाब नहीं} =1{1 तालाब} other{{count} तालाब}}',
      },
      overridable: true,
    ),
    L10nKeyInfo(
      name: 'addPond',
      description: 'Button that adds a pond',
      placeholders: [],
      bundled: {'en': 'Add pond', 'hi': 'तालाब जोड़ें'},
      overridable: true,
    ),
    L10nKeyInfo(
      name: 'canEditLabel',
      description: 'Switch that grants edit access in the demo',
      placeholders: [],
      bundled: {'en': 'Everyone can edit', 'hi': 'सभी संपादित कर सकते हैं'},
      overridable: true,
    ),
  ],
);

/// [AppLocalizations] that prefers override messages, such as strings
/// delivered over the air or editor drafts, and falls back to the
/// bundled ARB string per key when the override is missing, empty or
/// malformed.
class AppLocalizationsOverride extends AppLocalizations {
  /// Wraps [bundled] with the override messages of [_messages].
  AppLocalizationsOverride(this._bundled, this._messages)
    : super(_bundled.localeName);

  final AppLocalizations _bundled;
  final L10nMessageResolver _messages;

  @override
  String get appTitle =>
      _messages.resolve(0, 'appTitle', () => _bundled.appTitle);

  @override
  String greeting(String name) => _messages.resolve(
    1,
    'greeting',
    () => _bundled.greeting(name),
    {'name': name},
  );

  @override
  String pondCount(int count) => _messages.resolve(
    2,
    'pondCount',
    () => _bundled.pondCount(count),
    {'count': count},
  );

  @override
  String get addPond => _messages.resolve(3, 'addPond', () => _bundled.addPond);

  @override
  String get canEditLabel =>
      _messages.resolve(4, 'canEditLabel', () => _bundled.canEditLabel);
}

/// Use in place of [AppLocalizations.delegate]. Pass override
/// [messages] per language, e.g. strings delivered over the air.
class AppLocalizationsOverrideDelegate
    extends L10nOverrideDelegate<AppLocalizations> {
  /// Creates the delegate.
  const AppLocalizationsOverrideDelegate({super.messages, super.tagKeys});

  @override
  L10nCatalog get catalog => appLocalizationsCatalog;

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  @override
  AppLocalizations lookupBundled(Locale locale) =>
      lookupAppLocalizations(locale);

  @override
  AppLocalizations createOverride(
    AppLocalizations bundled,
    Map<String, String> messages,
  ) => AppLocalizationsOverride(
    bundled,
    L10nMessageResolver(
      localeName: bundled.localeName,
      messages: messages,
      tagKeys: tagKeys,
    ),
  );

  @override
  AppLocalizationsOverrideDelegate copyWith({
    MessagesByLanguage? messages,
    bool? tagKeys,
  }) => AppLocalizationsOverrideDelegate(
    messages: messages ?? this.messages,
    tagKeys: tagKeys ?? this.tagKeys,
  );
}
