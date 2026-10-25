import '../../domain/entities/editor_user.dart';

/// Decides who may edit translations. Implemented by the app.
///
/// The package never signs anyone in. It only shows the editor tools while
/// [watchEditor] emits a user, so the app can grant access however it likes:
/// to everyone, to users with a role, or after its own login, OTP or SSO
/// flow (see `InContextEditor.onRequestAccess`).
///
/// Hiding the tools is not security: the backend must enforce the same rule
/// for writes.
abstract interface class L10nAccessDataSource {
  /// Emits the current editor, or null when nobody may edit, and again
  /// whenever that changes. The first event should come quickly; until then
  /// the editor shows nothing.
  ///
  /// Errors keep the editor closed and are shown to the user; throw
  /// `L10nDataSourceException` for a readable message.
  Stream<EditorUser?> watchEditor();
}
