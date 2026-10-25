import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../../../domain/entities/editor_user.dart';
import '../../../domain/usecases/watch_editor_access.dart';

part 'editor_session_event.dart';
part 'editor_session_state.dart';

/// Tracks whether someone may edit, as reported by the app's
/// `L10nAccessDataSource`.
class EditorSessionBloc extends Bloc<EditorSessionEvent, EditorSessionState> {
  /// Creates the bloc. Add [EditorSessionStarted] to start watching.
  EditorSessionBloc({required WatchEditorAccess watchEditorAccess})
    : _watchEditorAccess = watchEditorAccess,
      super(const EditorSessionState()) {
    on<EditorSessionStarted>(_onStarted);
  }

  final WatchEditorAccess _watchEditorAccess;

  Future<void> _onStarted(
    EditorSessionStarted event,
    Emitter<EditorSessionState> emit,
  ) => emit.forEach(
    _watchEditorAccess(),
    onData: (result) => result.fold(
      (failure) => EditorSessionState(
        status: EditorSessionStatus.noAccess,
        failure: failure,
      ),
      (user) => user == null
          ? const EditorSessionState(status: EditorSessionStatus.noAccess)
          : EditorSessionState(status: EditorSessionStatus.editor, user: user),
    ),
  );
}
