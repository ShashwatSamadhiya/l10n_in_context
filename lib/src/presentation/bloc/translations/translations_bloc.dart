import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import '../../../domain/entities/editor_user.dart';
import '../../../domain/entities/l10n_catalog.dart';
import '../../../domain/entities/messages_by_language.dart';
import '../../../domain/entities/translation_snapshot.dart';
import '../../../domain/usecases/import_bundled.dart';
import '../../../domain/usecases/publish_drafts.dart';
import '../../../domain/usecases/save_draft.dart';
import '../../../domain/usecases/watch_translations.dart';

part 'translations_event.dart';
part 'translations_state.dart';

/// Drafts and published messages of the signed-in editor, plus saving,
/// importing and publishing them.
class TranslationsBloc extends Bloc<TranslationsEvent, TranslationsState> {
  /// Creates the bloc for the keys in [catalog].
  TranslationsBloc({
    required L10nCatalog catalog,
    required WatchDrafts watchDrafts,
    required WatchPublished watchPublished,
    required SaveDraft saveDraft,
    required ImportBundled importBundled,
    required PublishDrafts publishDrafts,
  }) : _catalog = catalog,
       _watchDrafts = watchDrafts,
       _watchPublished = watchPublished,
       _saveDraft = saveDraft,
       _importBundled = importBundled,
       _publishDrafts = publishDrafts,
       super(const TranslationsState()) {
    on<TranslationsSubscriptionRequested>(_onSubscriptionRequested);
    on<TranslationsUnsubscribed>(_onUnsubscribed);
    on<_DraftsReceived>(_onDraftsReceived);
    on<_PublishedReceived>(_onPublishedReceived);
    on<DraftsSaveRequested>(_onSaveRequested);
    on<BundledImportRequested>(_onImportRequested);
    on<PublishRequested>(_onPublishRequested);
  }

  final L10nCatalog _catalog;
  final WatchDrafts _watchDrafts;
  final WatchPublished _watchPublished;
  final SaveDraft _saveDraft;
  final ImportBundled _importBundled;
  final PublishDrafts _publishDrafts;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  int _nextOutcomeId = 0;

  Future<void> _onSubscriptionRequested(
    TranslationsSubscriptionRequested event,
    Emitter<TranslationsState> emit,
  ) async {
    await _cancelSubscriptions();
    emit(TranslationsState(user: event.user));
    _subscriptions
      ..add(_watchDrafts().listen((result) => add(_DraftsReceived(result))))
      ..add(
        _watchPublished().listen((result) => add(_PublishedReceived(result))),
      );
  }

  Future<void> _onUnsubscribed(
    TranslationsUnsubscribed event,
    Emitter<TranslationsState> emit,
  ) async {
    await _cancelSubscriptions();
    emit(const TranslationsState());
  }

  void _onDraftsReceived(
    _DraftsReceived event,
    Emitter<TranslationsState> emit,
  ) => emit(
    event.result.fold(
      (failure) => _withOutcome(TranslationsOperation.sync, failure: failure),
      (drafts) => _withSnapshot(state.snapshot.copyWith(drafts: drafts)),
    ),
  );

  void _onPublishedReceived(
    _PublishedReceived event,
    Emitter<TranslationsState> emit,
  ) => emit(
    event.result.fold(
      (failure) => _withOutcome(TranslationsOperation.sync, failure: failure),
      (published) =>
          _withSnapshot(state.snapshot.copyWith(published: published)),
    ),
  );

  Future<void> _onSaveRequested(
    DraftsSaveRequested event,
    Emitter<TranslationsState> emit,
  ) async {
    final user = state.user;
    if (user == null || state.isBusy || event.values.isEmpty) return;
    emit(state.copyWith(busy: TranslationsOperation.save));
    for (final MapEntry(key: lang, value: value) in event.values.entries) {
      final result = await _saveDraft(
        editor: user,
        languageCode: lang,
        key: event.key,
        value: value,
        previousValue: state.snapshot.effectiveDraft(lang)[event.key],
      );
      final failure = result.getLeft().toNullable();
      if (failure != null) {
        emit(
          _withOutcome(
            TranslationsOperation.save,
            failure: failure,
            languageCode: lang,
          ),
        );
        return;
      }
    }
    emit(_withOutcome(TranslationsOperation.save, count: event.values.length));
  }

  Future<void> _onImportRequested(
    BundledImportRequested event,
    Emitter<TranslationsState> emit,
  ) => _runBulk(
    TranslationsOperation.import,
    emit,
    (user) => _importBundled(editor: user, snapshot: state.snapshot),
  );

  Future<void> _onPublishRequested(
    PublishRequested event,
    Emitter<TranslationsState> emit,
  ) => _runBulk(
    TranslationsOperation.publish,
    emit,
    (user) => _publishDrafts(editor: user, snapshot: state.snapshot),
  );

  Future<void> _runBulk(
    TranslationsOperation operation,
    Emitter<TranslationsState> emit,
    Future<Either<L10nFailure, int>> Function(EditorUser user) run,
  ) async {
    final user = state.user;
    if (user == null || state.isBusy) return;
    emit(state.copyWith(busy: operation));
    final result = await run(user);
    emit(
      result.fold(
        (failure) => _withOutcome(operation, failure: failure),
        (count) => _withOutcome(operation, count: count),
      ),
    );
  }

  TranslationsState _withSnapshot(TranslationSnapshot snapshot) {
    final missing = snapshot.missingFromBundled(_catalog);
    return state.copyWith(
      snapshot: snapshot,
      unpublishedKeys: snapshot.unpublishedKeys(_catalog),
      missingFromBundledCount: missing.values.fold<int>(
        0,
        (n, m) => n + m.length,
      ),
    );
  }

  /// Ends any operation in progress and records [operation]'s result.
  TranslationsState _withOutcome(
    TranslationsOperation operation, {
    L10nFailure? failure,
    String? languageCode,
    int count = 0,
  }) => state.copyWith(
    clearBusy: true,
    outcome: TranslationsOutcome(
      id: _nextOutcomeId++,
      operation: operation,
      failure: failure,
      languageCode: languageCode,
      count: count,
    ),
  );

  Future<void> _cancelSubscriptions() async {
    final subscriptions = [..._subscriptions];
    _subscriptions.clear();
    await Future.wait(subscriptions.map((s) => s.cancel()));
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }
}
