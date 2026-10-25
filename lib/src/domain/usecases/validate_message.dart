import '../../core/l10n/icu_message_formatter.dart';
import '../entities/l10n_catalog.dart';

/// Checks a message before it is saved as a draft.
///
/// Mirrors what the app does at runtime: a message that fails here would make
/// the app fall back to the bundled string, so it is blocked before saving.
class ValidateMessage {
  /// Creates the validator.
  const ValidateMessage();

  /// Why [message] can't be saved for [key], or null when it is valid.
  String? call(String message, L10nKeyInfo key, {String? locale}) {
    if (message.trim().isEmpty) return 'The text is empty.';
    final Set<String> used;
    try {
      used = IcuMessageFormatter.argumentNames(message);
    } on FormatException catch (e) {
      return 'Invalid ICU syntax: ${e.message}.';
    }
    final expected = key.placeholderNames;
    final unknown = used.difference(expected);
    if (unknown.isNotEmpty) {
      final allowed = expected.isEmpty
          ? 'This key has no placeholders.'
          : 'Allowed: ${_braced(expected)}.';
      return 'Unknown placeholder ${_braced(unknown)}. $allowed';
    }
    final missing = expected.difference(used);
    if (missing.isNotEmpty) return 'Missing placeholder ${_braced(missing)}.';
    final rendered = IcuMessageFormatter.format(
      message,
      locale: locale ?? 'en',
      args: key.exampleArgs,
    );
    if (rendered == null) {
      return 'The message does not render with the example values '
          '(is a plural used on a text placeholder?).';
    }
    return null;
  }

  static String _braced(Set<String> names) =>
      names.map((n) => '{$n}').join(', ');
}
