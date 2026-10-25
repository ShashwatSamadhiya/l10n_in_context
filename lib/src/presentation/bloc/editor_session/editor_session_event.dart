part of 'editor_session_bloc.dart';

/// Events of [EditorSessionBloc].
sealed class EditorSessionEvent extends Equatable {
  const EditorSessionEvent();

  @override
  List<Object?> get props => [];
}

/// Starts watching edit access. Add once.
final class EditorSessionStarted extends EditorSessionEvent {
  /// Creates the event.
  const EditorSessionStarted();
}
