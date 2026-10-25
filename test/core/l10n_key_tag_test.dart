import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/src/core/l10n/l10n_key_tag.dart';

void main() {
  test('round-trips indexes, including 0 and multi-bit values', () {
    for (final index in [0, 1, 2, 5, 150, 1023]) {
      expect(KeyTagCodec.decode('x${KeyTagCodec.encode(index)}'), [index]);
    }
  });

  test('is invisible: only zero-width and format characters', () {
    final tag = KeyTagCodec.encode(150);
    expect(
      tag.runes.every((r) => {0x2063, 0x200C, 0x200D}.contains(r)),
      isTrue,
    );
  });

  test('finds every tag in concatenated text and strips them', () {
    final text = 'Retry${KeyTagCodec.encode(1)} · Go${KeyTagCodec.encode(2)}';
    expect(KeyTagCodec.decode(text), [1, 2]);
    expect(L10nKeyTag.strip(text), 'Retry · Go');
  });

  test('leaves untagged text alone', () {
    expect(KeyTagCodec.decode('plain'), isEmpty);
    expect(L10nKeyTag.strip('plain'), 'plain');
  });

  test('rejects negative indexes', () {
    expect(() => KeyTagCodec.encode(-1), throwsArgumentError);
  });
}
