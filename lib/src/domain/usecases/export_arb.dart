import 'dart:convert';

import '../entities/l10n_catalog.dart';
import '../entities/messages_by_language.dart';

/// Turns over-the-air messages back into ARB files, so edits made in the
/// app can be committed to the project's bundled ARB files.
///
/// The editor's key table copies these files; merge them into the project
/// with `dart run l10n_in_context:merge`.
class ArbExport {
  /// Creates an export for the keys in [catalog].
  const ArbExport(this.catalog);

  /// The app's keys.
  final L10nCatalog catalog;

  /// The messages of [messages] whose text differs from the bundled ARB,
  /// per language, in catalog order. Unknown keys and languages without
  /// changes are left out.
  MessagesByLanguage changes(MessagesByLanguage messages) {
    final result = <String, Map<String, String>>{};
    for (final lang in catalog.languages) {
      final byKey = messages[lang];
      if (byKey == null) continue;
      final changed = {
        for (final key in catalog.keys)
          if (byKey[key.name] case final message?
              when message != key.bundled[lang])
            key.name: message,
      };
      if (changed.isNotEmpty) result[lang] = changed;
    }
    return result;
  }

  /// An ARB file with `@@locale` set to [languageCode] and [messages], with
  /// two-space indentation and a trailing newline.
  String arb(String languageCode, Map<String, String> messages) =>
      _encode({'@@locale': languageCode, ...messages});

  /// Every language of [messages] as one JSON list of ARB objects, which
  /// `dart run l10n_in_context:merge` writes into every ARB file at once.
  String arbs(MessagesByLanguage messages) => _encode([
    for (final MapEntry(key: lang, value: byKey) in messages.entries)
      {'@@locale': lang, ...byKey},
  ]);

  static String _encode(Object json) =>
      '${const JsonEncoder.withIndent('  ').convert(json)}\n';
}
