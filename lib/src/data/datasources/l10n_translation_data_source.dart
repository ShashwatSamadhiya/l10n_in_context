import '../../domain/entities/editor_user.dart';
import '../../domain/entities/messages_by_language.dart';

/// Stores draft and published translations. Implemented by the app, for any
/// backend: Firestore, Supabase, a REST API, a local file.
///
/// Rules every implementation must follow:
///
/// - A write's future completes only once the write is stored.
/// - The `watch*` streams emit the full current state on listen and after
///   every change, including changes made by this device. A backend without
///   live updates can poll.
/// - Failures are thrown, ideally as `L10nDataSourceException` with a message
///   for editors. Stream errors are shown but don't end the stream.
/// - Authorise writes on the backend: only editors may write drafts or
///   publish. `editor` is passed so the backend can check and log it.
abstract interface class L10nTranslationDataSource {
  /// Live drafts of every language. Only editors read them.
  Stream<MessagesByLanguage> watchDrafts();

  /// Live published messages of every language.
  Stream<MessagesByLanguage> watchPublished();

  /// Sets one draft message, keeping every other draft.
  ///
  /// [previousValue] is the text the editor replaced, for audit logs.
  Future<void> saveDraft({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    String? previousValue,
  });

  /// Adds [messages] to the drafts, keeping every other draft.
  Future<void> importDrafts({
    required EditorUser editor,
    required MessagesByLanguage messages,
  });

  /// Replaces the published messages of each language in [messages] with
  /// exactly those messages. Languages not in [messages] are left alone.
  ///
  /// [changedKeys] (`lang:key`) lists what differs from the previous
  /// published text, for audit logs.
  Future<void> publish({
    required EditorUser editor,
    required MessagesByLanguage messages,
    required List<String> changedKeys,
  });
}
