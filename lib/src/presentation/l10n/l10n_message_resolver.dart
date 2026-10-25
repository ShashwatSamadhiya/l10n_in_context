import '../../core/l10n/icu_message_formatter.dart';
import '../../core/l10n/l10n_key_tag.dart';

/// Picks the string for one key of the generated `...Override` class.
///
/// Uses the override message when there is one, and falls back to the
/// bundled ARB string when it is missing, empty or malformed. In edit mode
/// every string, bundled ones included, gets an invisible key tag.
///
/// Called by generated code only.
class L10nMessageResolver {
  /// Creates a resolver for one locale.
  const L10nMessageResolver({
    required this.localeName,
    required this.messages,
    this.tagKeys = false,
  });

  /// The locale passed to the ICU formatter, e.g. `hi`.
  final String localeName;

  /// Override messages of this locale: `key -> raw ICU message`.
  final Map<String, String> messages;

  /// Appends key tags so the editor can find each string on screen.
  final bool tagKeys;

  /// The override message for [key] formatted with [args], else [fallback].
  /// [index] is the key's position in the catalog.
  String resolve(
    int index,
    String key,
    String Function() fallback, [
    Map<String, Object> args = const {},
  ]) {
    final message = messages[key];
    final value = message == null || message.isEmpty
        ? fallback()
        : IcuMessageFormatter.format(message, locale: localeName, args: args) ??
              fallback();
    return _tag(index, value);
  }

  /// [bundled], for keys that can't be overridden. Still tagged in edit mode
  /// so the editor can explain why.
  String bundledOnly(int index, String Function() bundled) =>
      _tag(index, bundled());

  String _tag(int index, String value) =>
      tagKeys ? value + KeyTagCodec.encode(index) : value;
}
