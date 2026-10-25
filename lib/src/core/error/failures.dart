import 'package:equatable/equatable.dart';

/// Why an editor operation failed. [message] is shown to editors as is.
sealed class L10nFailure extends Equatable {
  /// Creates a failure with a message for editors.
  const L10nFailure(this.message);

  /// Human-readable reason, shown in the editor UI.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// A data source threw an [L10nDataSourceException], e.g. a permission or
/// network error.
final class DataSourceFailure extends L10nFailure {
  /// Creates a failure reported by a data source.
  const DataSourceFailure(super.message);
}

/// A message was rejected before it reached the data source, e.g. broken ICU
/// syntax or a misspelled placeholder.
final class ValidationFailure extends L10nFailure {
  /// Creates a failure for an invalid message.
  const ValidationFailure(super.message);
}

/// A data source threw something other than [L10nDataSourceException].
final class UnexpectedFailure extends L10nFailure {
  /// Creates a failure for an unexpected exception.
  const UnexpectedFailure(super.message);
}
