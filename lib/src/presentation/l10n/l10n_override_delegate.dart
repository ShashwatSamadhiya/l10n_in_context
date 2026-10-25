import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/l10n_catalog.dart';
import '../../domain/entities/messages_by_language.dart';

/// Base of the generated `...OverrideDelegate`, which replaces the
/// gen-l10n delegate (for example `AppLocalizations.delegate`).
///
/// `AppLocalizations.of(context)` keeps working everywhere. Each key uses its
/// message from [messages] when there is a usable one, and the bundled ARB
/// string otherwise. Pass messages delivered over the air here; in edit mode
/// `InContextEditor` layers the drafts on top.
abstract class L10nOverrideDelegate<T> extends LocalizationsDelegate<T> {
  /// Creates a delegate with override [messages] per language.
  const L10nOverrideDelegate({this.messages = const {}, this.tagKeys = false});

  /// Override messages: `languageCode -> key -> raw ICU message`. Language
  /// codes are ARB `@@locale` values, e.g. `en` or `pt_BR`.
  final MessagesByLanguage messages;

  /// Appends invisible key tags so the editor can find strings on screen.
  final bool tagKeys;

  /// Every ARB key, for the editor.
  L10nCatalog get catalog;

  /// A copy with the given fields replaced.
  L10nOverrideDelegate<T> copyWith({
    MessagesByLanguage? messages,
    bool? tagKeys,
  });

  /// The gen-l10n localizations for [locale].
  @protected
  T lookupBundled(Locale locale);

  /// The generated override class around [bundled].
  @protected
  T createOverride(T bundled, Map<String, String> messages);

  /// Override messages for [locale]: an exact match first (`pt_BR`), then
  /// the language alone (`pt`).
  Map<String, String> messagesFor(Locale locale) =>
      messages[locale.toString()] ?? messages[locale.languageCode] ?? const {};

  /// Synchronous, like the gen-l10n delegate, so the first frame never
  /// renders without localizations.
  @override
  Future<T> load(Locale locale) {
    final bundled = lookupBundled(locale);
    final localeMessages = messagesFor(locale);
    if (localeMessages.isEmpty && !tagKeys) {
      return SynchronousFuture(bundled);
    }
    return SynchronousFuture(createOverride(bundled, localeMessages));
  }

  /// New messages rebuild every widget that reads the localizations.
  @override
  bool shouldReload(covariant L10nOverrideDelegate<T> old) =>
      old.tagKeys != tagKeys || !_sameMessages(old.messages, messages);

  static bool _sameMessages(MessagesByLanguage a, MessagesByLanguage b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final MapEntry(key: lang, value: entries) in a.entries) {
      if (!mapEquals(entries, b[lang])) return false;
    }
    return true;
  }
}
