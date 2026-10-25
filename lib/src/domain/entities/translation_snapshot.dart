import 'package:equatable/equatable.dart';

import 'l10n_catalog.dart';
import 'messages_by_language.dart';

/// The latest drafts and published messages read from the data source.
class TranslationSnapshot extends Equatable {
  /// Creates a snapshot; both maps default to empty.
  const TranslationSnapshot({
    this.drafts = const {},
    this.published = const {},
  });

  /// Messages editors saved but haven't published.
  final MessagesByLanguage drafts;

  /// Messages every app user sees.
  final MessagesByLanguage published;

  /// What editors see for [languageCode]: drafts layered over the published
  /// messages, so an untouched key shows its published text.
  Map<String, String> effectiveDraft(String languageCode) => {
    ...?published[languageCode],
    ...?drafts[languageCode],
  };

  /// Every `languageCode -> keys` whose draft differs from the published
  /// text, in catalog order.
  Map<String, List<String>> unpublishedKeys(L10nCatalog catalog) {
    final languages = {...drafts.keys, ...published.keys};
    final result = <String, List<String>>{};
    for (final lang in languages) {
      final draft = effectiveDraft(lang);
      final live = published[lang] ?? const {};
      final keys = [
        for (final key in catalog.keys)
          if (draft[key.name] != live[key.name]) key.name,
      ];
      if (keys.isNotEmpty) result[lang] = keys;
    }
    return result;
  }

  /// Bundled messages of every overridable key that has no draft or
  /// published text yet, per language.
  MessagesByLanguage missingFromBundled(L10nCatalog catalog) {
    final result = <String, Map<String, String>>{};
    for (final key in catalog.keys.where((k) => k.overridable)) {
      for (final MapEntry(key: lang, value: message) in key.bundled.entries) {
        if (!effectiveDraft(lang).containsKey(key.name)) {
          result.putIfAbsent(lang, () => {})[key.name] = message;
        }
      }
    }
    return result;
  }

  /// A copy with the given maps replaced.
  TranslationSnapshot copyWith({
    MessagesByLanguage? drafts,
    MessagesByLanguage? published,
  }) => TranslationSnapshot(
    drafts: drafts ?? this.drafts,
    published: published ?? this.published,
  );

  @override
  List<Object?> get props => [drafts, published];
}
