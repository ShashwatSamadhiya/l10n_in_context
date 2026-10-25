import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/editor_user.dart';
import '../../domain/entities/messages_by_language.dart';
import '../../domain/repositories/translation_repository.dart';
import '../datasources/l10n_translation_data_source.dart';
import 'data_source_guard.dart';

/// [TranslationRepository] backed by the app's [L10nTranslationDataSource].
class TranslationRepositoryImpl implements TranslationRepository {
  /// Creates the repository.
  const TranslationRepositoryImpl(this._dataSource);

  final L10nTranslationDataSource _dataSource;

  @override
  Stream<Either<L10nFailure, MessagesByLanguage>> watchDrafts() =>
      guardStream(_dataSource.watchDrafts());

  @override
  Stream<Either<L10nFailure, MessagesByLanguage>> watchPublished() =>
      guardStream(_dataSource.watchPublished());

  @override
  Future<Either<L10nFailure, Unit>> saveDraft({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    String? previousValue,
  }) => _write(
    () => _dataSource.saveDraft(
      editor: editor,
      languageCode: languageCode,
      key: key,
      value: value,
      previousValue: previousValue,
    ),
  );

  @override
  Future<Either<L10nFailure, Unit>> importDrafts({
    required EditorUser editor,
    required MessagesByLanguage messages,
  }) => _write(
    () => _dataSource.importDrafts(editor: editor, messages: messages),
  );

  @override
  Future<Either<L10nFailure, Unit>> publish({
    required EditorUser editor,
    required MessagesByLanguage messages,
    required List<String> changedKeys,
  }) => _write(
    () => _dataSource.publish(
      editor: editor,
      messages: messages,
      changedKeys: changedKeys,
    ),
  );

  Future<Either<L10nFailure, Unit>> _write(Future<void> Function() write) =>
      guardCall(() async {
        await write();
        return unit;
      });
}
