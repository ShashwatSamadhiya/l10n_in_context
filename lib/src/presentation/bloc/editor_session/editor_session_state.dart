part of 'editor_session_bloc.dart';

/// Whether someone may edit.
enum EditorSessionStatus {
  /// Waiting for the access data source's first answer.
  checking,

  /// Nobody may edit; the app shows published strings.
  noAccess,

  /// [EditorSessionState.user] may edit and sees drafts.
  editor,
}

/// State of [EditorSessionBloc].
class EditorSessionState extends Equatable {
  /// Creates the state.
  const EditorSessionState({
    this.status = EditorSessionStatus.checking,
    this.user,
    this.failure,
  });

  /// Whether someone may edit.
  final EditorSessionStatus status;

  /// Set while [status] is [EditorSessionStatus.editor].
  final EditorUser? user;

  /// Why access could not be checked, if it failed.
  final L10nFailure? failure;

  /// True while [user] may edit.
  bool get isEditor => status == EditorSessionStatus.editor;

  @override
  List<Object?> get props => [status, user, failure];
}
