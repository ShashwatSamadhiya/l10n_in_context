import 'dart:async';

import '../../../domain/entities/editor_user.dart';
import '../../../domain/entities/messages_by_language.dart';
import '../l10n_translation_data_source.dart';

/// [L10nTranslationDataSource] kept in memory, for tests and demos. Nothing
/// survives a restart.
class InMemoryL10nTranslationDataSource implements L10nTranslationDataSource {
  /// Starts with copies of [drafts] and [published].
  InMemoryL10nTranslationDataSource({
    MessagesByLanguage drafts = const {},
    MessagesByLanguage published = const {},
  }) : _drafts = _copy(drafts),
       _published = _copy(published);

  final MessagesByLanguage _drafts;
  MessagesByLanguage _published;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// A copy of the current drafts.
  MessagesByLanguage get drafts => _copy(_drafts);

  /// A copy of the current published messages.
  MessagesByLanguage get published => _copy(_published);

  @override
  Stream<MessagesByLanguage> watchDrafts() => _watch(() => drafts);

  @override
  Stream<MessagesByLanguage> watchPublished() => _watch(() => published);

  Stream<MessagesByLanguage> _watch(MessagesByLanguage Function() read) =>
      Stream.multi((controller) {
        controller.add(read());
        final subscription = _changes.stream.listen(
          (_) => controller.add(read()),
        );
        controller.onCancel = subscription.cancel;
      });

  @override
  Future<void> saveDraft({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    String? previousValue,
  }) async {
    _drafts.putIfAbsent(languageCode, () => {})[key] = value;
    _changes.add(null);
  }

  @override
  Future<void> importDrafts({
    required EditorUser editor,
    required MessagesByLanguage messages,
  }) async {
    for (final MapEntry(key: lang, value: entries) in messages.entries) {
      _drafts.putIfAbsent(lang, () => {}).addAll(entries);
    }
    _changes.add(null);
  }

  @override
  Future<void> publish({
    required EditorUser editor,
    required MessagesByLanguage messages,
    required List<String> changedKeys,
  }) async {
    _published = {..._published, ..._copy(messages)};
    _changes.add(null);
  }

  /// Closes the streams of changes.
  Future<void> dispose() => _changes.close();

  static MessagesByLanguage _copy(MessagesByLanguage messages) => {
    for (final MapEntry(key: lang, value: entries) in messages.entries)
      lang: {...entries},
  };
}
