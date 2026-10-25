import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/editor_user.dart';

/// Who may edit translations right now.
abstract interface class EditorAccessRepository {
  /// The current editor, or null when nobody may edit. A failure means
  /// access could not be checked; the editor stays closed.
  Stream<Either<L10nFailure, EditorUser?>> watchEditor();
}
