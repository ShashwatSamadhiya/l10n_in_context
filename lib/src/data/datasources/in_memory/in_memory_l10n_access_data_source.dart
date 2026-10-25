import 'dart:async';

import '../../../domain/entities/editor_user.dart';
import '../l10n_access_data_source.dart';

/// [L10nAccessDataSource] kept in memory, for tests, demos and builds where
/// everyone may edit.
class InMemoryL10nAccessDataSource implements L10nAccessDataSource {
  /// Starts with [editor] having access, or nobody.
  InMemoryL10nAccessDataSource({EditorUser? editor}) : _editor = editor;

  EditorUser? _editor;
  final StreamController<EditorUser?> _changes =
      StreamController<EditorUser?>.broadcast();

  /// The current editor, or null.
  EditorUser? get editor => _editor;

  /// Gives [user] edit access.
  void grant(EditorUser user) => _set(user);

  /// Takes edit access away.
  void revoke() => _set(null);

  void _set(EditorUser? user) {
    _editor = user;
    _changes.add(user);
  }

  @override
  Stream<EditorUser?> watchEditor() => Stream.multi((controller) {
    controller.add(_editor);
    final subscription = _changes.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });

  /// Closes the stream of changes.
  Future<void> dispose() => _changes.close();
}
