import 'package:equatable/equatable.dart';

/// The person currently allowed to edit translations.
///
/// Passed back to every data source write, so the backend can authorise it
/// and record who made a change.
class EditorUser extends Equatable {
  /// Creates an editor with a stable [id] and an optional [displayName].
  const EditorUser({required this.id, this.displayName});

  /// Stable identifier, e.g. an auth uid or a device id.
  final String id;

  /// Shown in the editor UI and written to audit logs, e.g. an email.
  final String? displayName;

  @override
  List<Object?> get props => [id, displayName];
}
