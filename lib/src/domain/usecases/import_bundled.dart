import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/editor_user.dart';
import '../entities/l10n_catalog.dart';
import '../entities/translation_snapshot.dart';
import '../repositories/translation_repository.dart';

/// Seeds the drafts with the bundled ARB text of every overridable key that
/// has no draft or published text yet.
class ImportBundled {
  /// Creates the use case for the keys in [catalog].
  const ImportBundled(this._repository, this._catalog);

  final TranslationRepository _repository;
  final L10nCatalog _catalog;

  /// Imports what is missing from [snapshot]. Returns how many messages were
  /// imported; zero writes nothing.
  Future<Either<L10nFailure, int>> call({
    required EditorUser editor,
    required TranslationSnapshot snapshot,
  }) async {
    final missing = snapshot.missingFromBundled(_catalog);
    final count = missing.values.fold(0, (n, m) => n + m.length);
    if (count == 0) return const Right(0);
    final result = await _repository.importDrafts(
      editor: editor,
      messages: missing,
    );
    return result.map((_) => count);
  }
}
