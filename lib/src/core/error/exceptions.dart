/// Thrown by data source implementations when a read or write fails.
///
/// [message] is shown to editors as is, so keep it short and readable, e.g.
/// "Missing or insufficient permissions.". Any other exception a data source
/// throws is shown as its `toString()`.
class L10nDataSourceException implements Exception {
  /// Creates an exception with a message for editors and the original
  /// [cause], if any.
  const L10nDataSourceException(this.message, {this.cause});

  /// Human-readable reason, shown in the editor UI.
  final String message;

  /// The backend error this exception wraps, for logging.
  final Object? cause;

  @override
  String toString() => 'L10nDataSourceException: $message';
}
