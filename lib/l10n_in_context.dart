/// In-context translation editing for Flutter apps that use gen-l10n.
///
/// 1. Run `dart run l10n_in_context:generate` after `flutter gen-l10n`.
/// 2. Implement [L10nAccessDataSource] and [L10nTranslationDataSource] for
///    your backend.
/// 3. Wrap `MaterialApp` with [InContextEditor].
library;

export 'src/core/error/exceptions.dart';
export 'src/core/error/failures.dart';
export 'src/core/l10n/icu_message_formatter.dart';
export 'src/core/l10n/l10n_key_tag.dart' show L10nKeyTag;
export 'src/data/datasources/in_memory/in_memory_l10n_access_data_source.dart';
export 'src/data/datasources/in_memory/in_memory_l10n_translation_data_source.dart';
export 'src/data/datasources/l10n_access_data_source.dart';
export 'src/data/datasources/l10n_translation_data_source.dart';
export 'src/domain/entities/editor_user.dart';
export 'src/domain/entities/l10n_catalog.dart';
export 'src/domain/entities/messages_by_language.dart';
export 'src/domain/entities/translation_snapshot.dart';
export 'src/domain/usecases/validate_message.dart';
export 'src/presentation/bloc/editor_session/editor_session_bloc.dart';
export 'src/presentation/bloc/editor_tools/editor_tools_cubit.dart';
export 'src/presentation/bloc/translations/translations_bloc.dart';
export 'src/presentation/l10n/l10n_message_resolver.dart';
export 'src/presentation/l10n/l10n_override_delegate.dart';
export 'src/presentation/widgets/editor_config.dart' show L10nAccessRequest;
export 'src/presentation/widgets/email_password_sign_in_dialog.dart';
export 'src/presentation/widgets/in_context_editor.dart';
