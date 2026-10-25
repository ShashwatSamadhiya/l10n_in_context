import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:l10n_in_context/l10n_in_context.dart';
import 'package:l10n_in_context/src/data/repositories/translation_repository_impl.dart';

import '../fixtures.dart';

class _StreamingDataSource extends FailingTranslationDataSource {
  final StreamController<MessagesByLanguage> drafts$ = StreamController();

  @override
  Stream<MessagesByLanguage> watchDrafts() => drafts$.stream;
}

void main() {
  late FailingTranslationDataSource dataSource;
  late TranslationRepositoryImpl repository;

  setUp(() {
    dataSource = FailingTranslationDataSource();
    repository = TranslationRepositoryImpl(dataSource);
  });

  Future<Either<L10nFailure, Unit>> save() => repository.saveDraft(
    editor: testEditor,
    languageCode: 'en',
    key: 'retry',
    value: 'Again',
  );

  test('returns Right after a successful write', () async {
    expect(await save(), const Right<L10nFailure, Unit>(unit));
    expect(dataSource.drafts, {
      'en': {'retry': 'Again'},
    });
  });

  test('turns L10nDataSourceException into DataSourceFailure', () async {
    dataSource.failWith = const L10nDataSourceException('Denied');
    expect(
      await save(),
      const Left<L10nFailure, Unit>(DataSourceFailure('Denied')),
    );
  });

  test('turns other exceptions into UnexpectedFailure', () async {
    dataSource.failWith = const FormatException('bad');
    final result = await save();
    expect(result.getLeft().toNullable(), isA<UnexpectedFailure>());
  });

  test('reports stream errors without ending the stream', () async {
    final streaming = _StreamingDataSource();
    final events = <Either<L10nFailure, MessagesByLanguage>>[];
    TranslationRepositoryImpl(streaming).watchDrafts().listen(events.add);
    streaming.drafts$
      ..addError(const L10nDataSourceException('Offline'))
      ..add({
        'en': {'retry': 'Again'},
      });
    await Future<void>.delayed(Duration.zero);
    expect(
      events.first.getLeft().toNullable(),
      const DataSourceFailure('Offline'),
    );
    expect(events.last.getRight().toNullable(), {
      'en': {'retry': 'Again'},
    });
  });
}
