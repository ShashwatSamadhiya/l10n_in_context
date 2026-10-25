part of 'translations_bloc.dart';

/// Events of [TranslationsBloc].
sealed class TranslationsEvent extends Equatable {
  const TranslationsEvent();

  @override
  List<Object?> get props => [];
}

/// Starts listening to drafts and published messages as [user].
final class TranslationsSubscriptionRequested extends TranslationsEvent {
  /// Creates the event.
  const TranslationsSubscriptionRequested(this.user);

  /// The editor who reads and writes.
  final EditorUser user;

  @override
  List<Object?> get props => [user];
}

/// Stops listening and forgets every message, e.g. when access ends.
final class TranslationsUnsubscribed extends TranslationsEvent {
  /// Creates the event.
  const TranslationsUnsubscribed();
}

/// Saves [values] (`languageCode -> message`) as drafts of [key], one
/// language at a time, stopping at the first failure.
final class DraftsSaveRequested extends TranslationsEvent {
  /// Creates the event.
  const DraftsSaveRequested({required this.key, required this.values});

  /// The ARB key.
  final String key;

  /// New message per language.
  final Map<String, String> values;

  @override
  List<Object?> get props => [key, values];
}

/// Seeds the drafts with bundled text for keys without OTA text.
final class BundledImportRequested extends TranslationsEvent {
  /// Creates the event.
  const BundledImportRequested();
}

/// Publishes every unpublished draft.
final class PublishRequested extends TranslationsEvent {
  /// Creates the event.
  const PublishRequested();
}

final class _DraftsReceived extends TranslationsEvent {
  const _DraftsReceived(this.result);

  final Either<L10nFailure, MessagesByLanguage> result;

  @override
  List<Object?> get props => [result];
}

final class _PublishedReceived extends TranslationsEvent {
  const _PublishedReceived(this.result);

  final Either<L10nFailure, MessagesByLanguage> result;

  @override
  List<Object?> get props => [result];
}
