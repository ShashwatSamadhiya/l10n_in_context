import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/editor_user.dart';
import '../entities/messages_by_language.dart';

/// Reads and writes draft and published translations.
abstract interface class TranslationRepository {
  /// Live drafts of every language.
  Stream<Either<L10nFailure, MessagesByLanguage>> watchDrafts();

  /// Live published messages of every language.
  Stream<Either<L10nFailure, MessagesByLanguage>> watchPublished();

  /// Sets one draft message.
  Future<Either<L10nFailure, Unit>> saveDraft({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    String? previousValue,
  });

  /// Adds [messages] to the drafts.
  Future<Either<L10nFailure, Unit>> importDrafts({
    required EditorUser editor,
    required MessagesByLanguage messages,
  });

  /// Replaces the published messages of each language in [messages].
  Future<Either<L10nFailure, Unit>> publish({
    required EditorUser editor,
    required MessagesByLanguage messages,
    required List<String> changedKeys,
  });
}
