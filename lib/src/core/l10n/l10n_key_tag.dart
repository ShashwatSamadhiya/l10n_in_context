/// Invisible tags that edit mode appends to every localized string, so a tap
/// on rendered text can be traced back to its ARB key.
///
/// The tag format is an implementation detail and may change between
/// versions; only [strip] is public.
abstract final class L10nKeyTag {
  // A tag is U+2063 INVISIBLE SEPARATOR followed by the key's catalog index
  // in binary, most significant bit first, written as U+200C ZWNJ (0) and
  // U+200D ZWJ (1).
  static const String _start = '⁣';
  static const String _zero = '‌';
  static const String _one = '‍';

  static final RegExp _pattern = RegExp('$_start([$_zero$_one]+)');

  /// [text] without key tags, e.g. to compare a string shown in edit mode
  /// with its bundled version.
  static String strip(String text) => text.replaceAll(_pattern, '');
}

/// Encodes and decodes catalog indexes as key tags. Not exported: the
/// encoding is only stable within one build.
abstract final class KeyTagCodec {
  /// The tag for catalog [index].
  static String encode(int index) {
    if (index < 0) throw ArgumentError.value(index, 'index');
    final bits = index.toRadixString(2);
    return L10nKeyTag._start +
        bits.replaceAll('0', L10nKeyTag._zero).replaceAll('1', L10nKeyTag._one);
  }

  /// Indexes of every tag in [text], in order of appearance.
  static List<int> decode(String text) => [
    for (final match in L10nKeyTag._pattern.allMatches(text))
      int.parse(
        match
            .group(1)!
            .replaceAll(L10nKeyTag._zero, '0')
            .replaceAll(L10nKeyTag._one, '1'),
        radix: 2,
      ),
  ];
}
