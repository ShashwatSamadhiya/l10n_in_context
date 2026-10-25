import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/editor_user.dart';
import '../../domain/repositories/editor_access_repository.dart';
import '../datasources/l10n_access_data_source.dart';
import 'data_source_guard.dart';

/// [EditorAccessRepository] backed by the app's [L10nAccessDataSource].
class EditorAccessRepositoryImpl implements EditorAccessRepository {
  /// Creates the repository.
  const EditorAccessRepositoryImpl(this._dataSource);

  final L10nAccessDataSource _dataSource;

  @override
  Stream<Either<L10nFailure, EditorUser?>> watchEditor() =>
      guardStream(_dataSource.watchEditor());
}
