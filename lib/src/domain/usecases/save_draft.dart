import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/editor_user.dart';
import '../entities/l10n_catalog.dart';
import '../repositories/translation_repository.dart';
import 'validate_message.dart';

/// Validates one message and saves it as a draft.
class SaveDraft {
  /// Creates the use case for the keys in [catalog].
  const SaveDraft(
    this._repository,
    this._catalog, {
    ValidateMessage validate = const ValidateMessage(),
  }) : _validate = validate;

  final TranslationRepository _repository;
  final L10nCatalog _catalog;
  final ValidateMessage _validate;

  /// Saves [value] for [key] in [languageCode]. [previousValue] is what the
  /// editor saw before, for audit logs.
  Future<Either<L10nFailure, Unit>> call({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    String? previousValue,
  }) async {
    final info = _catalog.lookup(key);
    if (info == null) return Left(ValidationFailure('Unknown key "$key".'));
    final invalid = _validate(value, info, locale: languageCode);
    if (invalid != null) return Left(ValidationFailure(invalid));
    return _repository.saveDraft(
      editor: editor,
      languageCode: languageCode,
      key: key,
      value: value,
      previousValue: previousValue,
    );
  }
}
