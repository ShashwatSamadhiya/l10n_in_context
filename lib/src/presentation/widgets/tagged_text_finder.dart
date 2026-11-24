import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import '../../core/l10n/l10n_key_tag.dart';
import '../../domain/entities/l10n_catalog.dart';

/// A piece of rendered text that carries at least one key tag.
class TaggedText {
  /// Creates a tagged text.
  const TaggedText(this.rect, this.keys);

  /// Bounds in the coordinate space of the root passed to [findTaggedTexts].
  final Rect rect;

  /// Catalog keys tagged in the text.
  final List<String> keys;
}

/// Catalog keys tagged in [text], without duplicates, in order.
List<String> keysIn(L10nCatalog catalog, String text) => [
  for (final index in KeyTagCodec.decode(text).toSet())
    if (index < catalog.keys.length) catalog.keys[index].name,
];

/// Catalog keys of the text under [globalPosition] inside [root].
///
/// Uses a real hit test first, so only what the user can see and tap counts.
/// Text under `IgnorePointer`/`AbsorbPointer` is never hit, so in that case
/// it falls back to the bounds of every visible tagged text.
List<String> keysAt(
  L10nCatalog catalog,
  RenderBox root,
  Offset globalPosition,
) {
  final local = root.globalToLocal(globalPosition);
  final result = BoxHitTestResult();
  root.hitTest(result, position: local);
  final keys = <String>{
    for (final entry in result.path)
      if (_textOf(entry.target) case final text?) ...keysIn(catalog, text),
  };
  if (keys.isNotEmpty) return keys.toList();
  return {
    for (final tagged in findTaggedTexts(catalog, root))
      if (tagged.rect.contains(local)) ...tagged.keys,
  }.toList();
}

/// Every tagged text currently on screen below [root].
///
/// Walks the tree the way semantics does, which skips offstage children such
/// as the routes below an opaque page, so their text isn't reported.
///
/// With [uncoveredOnly], texts covered by something drawn over them, such as
/// a dialog and its barrier, are left out too; [root] must then be a
/// [RenderBox].
List<TaggedText> findTaggedTexts(
  L10nCatalog catalog,
  RenderObject root, {
  bool uncoveredOnly = false,
}) {
  final found = <TaggedText>[];
  void visit(RenderObject node) {
    if (node is RenderBox && node.hasSize) {
      final text = _textOf(node);
      if (text != null) {
        final keys = keysIn(catalog, text);
        if (keys.isNotEmpty) {
          final rect = MatrixUtils.transformRect(
            node.getTransformTo(root),
            Offset.zero & node.size,
          );
          if (!uncoveredOnly || !_isCovered(root as RenderBox, node, rect)) {
            found.add(TaggedText(rect, keys));
          }
        }
      }
    }
    node.visitChildrenForSemantics(visit);
  }

  visit(root);
  return found;
}

/// Whether a hit test at the center of [node] (at [rect] in [root]) lands
/// first on something that is neither [node] nor one of its ancestors. Text
/// under `IgnorePointer` isn't covered: the hit lands on an ancestor.
bool _isCovered(RenderBox root, RenderObject node, Rect rect) {
  final result = BoxHitTestResult();
  root.hitTest(result, position: rect.center);
  // The deepest render object hit; text spans may come before it.
  final top = result.path
      .map((entry) => entry.target)
      .whereType<RenderObject>()
      .firstOrNull;
  if (top == null) return false;
  for (RenderObject? n = node; n != null; n = n.parent) {
    if (identical(n, top)) return false;
    if (identical(n, root)) break;
  }
  return true;
}

String? _textOf(HitTestTarget target) => switch (target) {
  RenderParagraph(:final text) => text.toPlainText(),
  RenderEditable(:final text?) => text.toPlainText(),
  _ => null,
};
