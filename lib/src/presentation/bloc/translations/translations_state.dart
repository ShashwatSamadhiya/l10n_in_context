part of 'translations_bloc.dart';

/// What [TranslationsBloc] is doing or last did.
enum TranslationsOperation {
  /// Saving drafts of one key.
  save,

  /// Importing bundled text into the drafts.
  import,

  /// Publishing drafts.
  publish,

  /// Receiving drafts or published messages from the data source.
  sync,
}

/// The result of one finished operation.
class TranslationsOutcome extends Equatable {
  /// Creates an outcome. [id] makes every outcome distinct, so listeners see
  /// two identical results in a row.
  const TranslationsOutcome({
    required this.id,
    required this.operation,
    this.failure,
    this.languageCode,
    this.count = 0,
  });

  /// Increases with every outcome.
  final int id;

  /// What finished.
  final TranslationsOperation operation;

  /// Why it failed, or null on success.
  final L10nFailure? failure;

  /// The language a save failed for.
  final String? languageCode;

  /// Messages saved, imported or published.
  final int count;

  /// True when [operation] succeeded.
  bool get isSuccess => failure == null;

  @override
  List<Object?> get props => [id, operation, failure, languageCode, count];
}

/// State of [TranslationsBloc].
class TranslationsState extends Equatable {
  /// Creates the state.
  const TranslationsState({
    this.user,
    this.snapshot = const TranslationSnapshot(),
    this.unpublishedKeys = const {},
    this.missingFromBundledCount = 0,
    this.busy,
    this.outcome,
  });

  /// The editor reading and writing, or null when not subscribed.
  final EditorUser? user;

  /// The latest drafts and published messages.
  final TranslationSnapshot snapshot;

  /// `languageCode -> keys` whose draft differs from the published text.
  final Map<String, List<String>> unpublishedKeys;

  /// Bundled messages that an import would add.
  final int missingFromBundledCount;

  /// The operation in progress, if any.
  final TranslationsOperation? busy;

  /// The last finished operation.
  final TranslationsOutcome? outcome;

  /// True while a save, import or publish is in progress.
  bool get isBusy => busy != null;

  /// Number of unpublished messages across every language.
  int get unpublishedCount =>
      unpublishedKeys.values.fold(0, (n, keys) => n + keys.length);

  /// A copy with the given fields replaced.
  TranslationsState copyWith({
    TranslationSnapshot? snapshot,
    Map<String, List<String>>? unpublishedKeys,
    int? missingFromBundledCount,
    TranslationsOperation? busy,
    bool clearBusy = false,
    TranslationsOutcome? outcome,
  }) => TranslationsState(
    user: user,
    snapshot: snapshot ?? this.snapshot,
    unpublishedKeys: unpublishedKeys ?? this.unpublishedKeys,
    missingFromBundledCount:
        missingFromBundledCount ?? this.missingFromBundledCount,
    busy: clearBusy ? null : busy ?? this.busy,
    outcome: outcome ?? this.outcome,
  );

  @override
  List<Object?> get props => [
    user,
    snapshot,
    unpublishedKeys,
    missingFromBundledCount,
    busy,
    outcome,
  ];
}
