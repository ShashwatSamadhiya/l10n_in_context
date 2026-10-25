import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/editor_user.dart';
import '../repositories/editor_access_repository.dart';

/// The current editor, or null when nobody may edit.
class WatchEditorAccess {
  /// Creates the use case.
  const WatchEditorAccess(this._repository);

  final EditorAccessRepository _repository;

  /// Starts watching.
  Stream<Either<L10nFailure, EditorUser?>> call() => _repository.watchEditor();
}
