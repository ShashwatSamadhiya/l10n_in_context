import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/messages_by_language.dart';
import '../repositories/translation_repository.dart';

/// Live drafts of every language.
class WatchDrafts {
  /// Creates the use case.
  const WatchDrafts(this._repository);

  final TranslationRepository _repository;

  /// Starts watching.
  Stream<Either<L10nFailure, MessagesByLanguage>> call() =>
      _repository.watchDrafts();
}

/// Live published messages of every language.
class WatchPublished {
  /// Creates the use case.
  const WatchPublished(this._repository);

  final TranslationRepository _repository;

  /// Starts watching.
  Stream<Either<L10nFailure, MessagesByLanguage>> call() =>
      _repository.watchPublished();
}
