import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/editor_user.dart';
import '../entities/translation_snapshot.dart';
import '../repositories/translation_repository.dart';

/// Deletes drafts, so editors see the published (or bundled) text again.
class DiscardDrafts {
  /// Creates the use case.
  const DiscardDrafts(this._repository);

  final TranslationRepository _repository;

  /// Discards the drafts of [keys] (`languageCode -> keys`) that exist in
  /// [snapshot]. Returns how many were discarded; zero writes nothing.
  Future<Either<L10nFailure, int>> call({
    required EditorUser editor,
    required TranslationSnapshot snapshot,
    required Map<String, List<String>> keys,
  }) async {
    final existing = <String, List<String>>{};
    for (final MapEntry(key: lang, value: names) in keys.entries) {
      final drafts = snapshot.drafts[lang] ?? const {};
      final found = names.where(drafts.containsKey).toSet().toList();
      if (found.isNotEmpty) existing[lang] = found;
    }
    final count = existing.values.fold(0, (n, k) => n + k.length);
    if (count == 0) return const Right(0);
    final result = await _repository.discardDrafts(
      editor: editor,
      keys: existing,
    );
    return result.map((_) => count);
  }
}
