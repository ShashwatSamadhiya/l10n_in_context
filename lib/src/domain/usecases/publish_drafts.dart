import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/editor_user.dart';
import '../entities/l10n_catalog.dart';
import '../entities/translation_snapshot.dart';
import '../repositories/translation_repository.dart';

/// Copies the drafts of every language with changes to the published
/// messages, which is what app users read.
class PublishDrafts {
  /// Creates the use case for the keys in [catalog].
  const PublishDrafts(this._repository, this._catalog);

  final TranslationRepository _repository;
  final L10nCatalog _catalog;

  /// Publishes what differs in [snapshot]. Returns how many messages
  /// changed; zero writes nothing.
  Future<Either<L10nFailure, int>> call({
    required EditorUser editor,
    required TranslationSnapshot snapshot,
  }) async {
    final unpublished = snapshot.unpublishedKeys(_catalog);
    final changedKeys = [
      for (final MapEntry(key: lang, value: keys) in unpublished.entries)
        for (final key in keys) '$lang:$key',
    ];
    if (changedKeys.isEmpty) return const Right(0);
    final result = await _repository.publish(
      editor: editor,
      messages: {
        for (final lang in unpublished.keys)
          lang: snapshot.effectiveDraft(lang),
      },
      changedKeys: changedKeys,
    );
    return result.map((_) => changedKeys.length);
  }
}
