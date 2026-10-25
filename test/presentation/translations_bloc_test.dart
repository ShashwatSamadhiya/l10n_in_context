import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/l10n_in_context.dart';
import 'package:l10n_in_context/src/data/repositories/translation_repository_impl.dart';
import 'package:l10n_in_context/src/domain/usecases/import_bundled.dart';
import 'package:l10n_in_context/src/domain/usecases/publish_drafts.dart';
import 'package:l10n_in_context/src/domain/usecases/save_draft.dart';
import 'package:l10n_in_context/src/domain/usecases/watch_translations.dart';

import '../fixtures.dart';

void main() {
  late FailingTranslationDataSource dataSource;
  late TranslationsBloc bloc;

  void build({
    MessagesByLanguage drafts = const {},
    MessagesByLanguage published = const {},
  }) {
    dataSource = FailingTranslationDataSource(
      drafts: drafts,
      published: published,
    );
    final repository = TranslationRepositoryImpl(dataSource);
    bloc = TranslationsBloc(
      catalog: testCatalog,
      watchDrafts: WatchDrafts(repository),
      watchPublished: WatchPublished(repository),
      saveDraft: SaveDraft(repository, testCatalog),
      importBundled: ImportBundled(repository, testCatalog),
      publishDrafts: PublishDrafts(repository, testCatalog),
    );
  }

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> subscribe() async {
    bloc.add(const TranslationsSubscriptionRequested(testEditor));
    await settle();
    await settle();
  }

  Future<TranslationsOutcome> run(TranslationsEvent event) async {
    bloc.add(event);
    final state = await bloc.stream.firstWhere(
      (s) => !s.isBusy && s.outcome?.operation != TranslationsOperation.sync,
    );
    await settle();
    return state.outcome!;
  }

  test('loads drafts layered over published messages', () async {
    build(
      drafts: {
        'en': {'retry': 'Try again'},
      },
      published: {
        'en': {'retry': 'Retry', 'getStarted': 'Start'},
      },
    );
    await subscribe();
    expect(bloc.state.snapshot.effectiveDraft('en'), {
      'retry': 'Try again',
      'getStarted': 'Start',
    });
    expect(bloc.state.unpublishedKeys, {
      'en': ['retry'],
    });
    expect(bloc.state.unpublishedCount, 1);
  });

  group('save', () {
    test('saves each language with the value it replaces', () async {
      build(
        published: {
          'en': {'retry': 'Retry'},
        },
      );
      await subscribe();
      final outcome = await run(
        const DraftsSaveRequested(
          key: 'retry',
          values: {'en': 'Try again', 'hi': 'फिर से'},
        ),
      );
      expect(outcome.isSuccess, isTrue);
      expect(dataSource.saves, [
        ('en', 'retry', 'Try again', 'Retry'),
        ('hi', 'retry', 'फिर से', null),
      ]);
      expect(bloc.state.snapshot.drafts['hi'], {'retry': 'फिर से'});
    });

    test('blocks an invalid message without writing', () async {
      build();
      await subscribe();
      final outcome = await run(
        const DraftsSaveRequested(
          key: 'farmerRegistered',
          values: {'en': '{nmae} registered'},
        ),
      );
      expect(outcome.failure, isA<ValidationFailure>());
      expect(outcome.failure!.message, contains('Unknown placeholder'));
      expect(outcome.languageCode, 'en');
      expect(dataSource.saves, isEmpty);
    });

    test('reports the data source error', () async {
      build();
      await subscribe();
      dataSource.failWith = const L10nDataSourceException('Denied');
      final outcome = await run(
        const DraftsSaveRequested(key: 'retry', values: {'en': 'Again'}),
      );
      expect(outcome.failure, const DataSourceFailure('Denied'));
      expect(bloc.state.isBusy, isFalse);
    });
  });

  test('publishes only languages with changes', () async {
    build(
      drafts: {
        'hi': {'retry': 'फिर से'},
      },
      published: {
        'en': {'retry': 'Retry'},
        'hi': {'getStarted': 'शुरू करें'},
      },
    );
    await subscribe();
    final outcome = await run(const PublishRequested());
    expect(outcome.isSuccess, isTrue);
    expect(outcome.count, 1);
    expect(dataSource.published, {
      'en': {'retry': 'Retry'},
      'hi': {'getStarted': 'शुरू करें', 'retry': 'फिर से'},
    });
    expect(bloc.state.unpublishedCount, 0);
  });

  test('a failed publish reports the error and clears busy', () async {
    build(
      drafts: {
        'en': {'retry': 'Again'},
      },
    );
    await subscribe();
    dataSource.failWith = const L10nDataSourceException('x');
    final outcome = await run(const PublishRequested());
    expect(outcome.failure, const DataSourceFailure('x'));
    expect(bloc.state.isBusy, isFalse);
  });

  test('imports bundled text only for keys without OTA text', () async {
    build(
      published: {
        'en': {'retry': 'Retry'},
      },
    );
    await subscribe();
    final overridable = testCatalog.keys.where((k) => k.overridable).length;
    expect(bloc.state.missingFromBundledCount, overridable * 2 - 1);
    final outcome = await run(const BundledImportRequested());
    expect(outcome.count, overridable * 2 - 1);
    expect(dataSource.drafts['en']!.containsKey('retry'), isFalse);
    expect(dataSource.drafts['hi']!.length, overridable);
    expect(bloc.state.missingFromBundledCount, 0);
  });

  test('unsubscribing forgets every message', () async {
    build(
      drafts: {
        'en': {'retry': 'Again'},
      },
    );
    await subscribe();
    bloc.add(const TranslationsUnsubscribed());
    await settle();
    expect(bloc.state, const TranslationsState());
  });
}
