import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/l10n_in_context.dart';
import 'package:l10n_in_context/src/data/repositories/editor_access_repository_impl.dart';
import 'package:l10n_in_context/src/domain/usecases/watch_editor_access.dart';

import '../fixtures.dart';

class _ControlledAccess implements L10nAccessDataSource {
  final StreamController<EditorUser?> controller = StreamController();

  @override
  Stream<EditorUser?> watchEditor() => controller.stream;
}

EditorSessionBloc _bloc(L10nAccessDataSource dataSource) => EditorSessionBloc(
  watchEditorAccess: WatchEditorAccess(EditorAccessRepositoryImpl(dataSource)),
);

void main() {
  test('starts checking', () {
    expect(
      _bloc(InMemoryL10nAccessDataSource()).state.status,
      EditorSessionStatus.checking,
    );
  });

  blocTest<EditorSessionBloc, EditorSessionState>(
    'follows access granted and revoked by the app',
    build: () => _bloc(InMemoryL10nAccessDataSource()),
    act: (bloc) async {
      bloc.add(const EditorSessionStarted());
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const EditorSessionState(status: EditorSessionStatus.noAccess),
    ],
  );

  late _ControlledAccess access;
  blocTest<EditorSessionBloc, EditorSessionState>(
    'grants, revokes and reports failures',
    setUp: () => access = _ControlledAccess(),
    build: () => _bloc(access),
    act: (bloc) async {
      bloc.add(const EditorSessionStarted());
      await Future<void>.delayed(Duration.zero);
      access.controller
        ..add(testEditor)
        ..add(null)
        ..addError(const L10nDataSourceException('Offline'));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => [
      const EditorSessionState(
        status: EditorSessionStatus.editor,
        user: testEditor,
      ),
      const EditorSessionState(status: EditorSessionStatus.noAccess),
      const EditorSessionState(
        status: EditorSessionStatus.noAccess,
        failure: DataSourceFailure('Offline'),
      ),
    ],
  );
}
