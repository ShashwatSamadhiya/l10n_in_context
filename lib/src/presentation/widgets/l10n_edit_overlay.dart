import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/editor_session/editor_session_bloc.dart';
import '../bloc/editor_tools/editor_tools_cubit.dart';
import '../bloc/translations/translations_bloc.dart';
import '../pages/l10n_key_table_page.dart';
import 'edit_key_dialog.dart';
import 'editor_config.dart';
import 'spacing.dart';
import 'tagged_text_finder.dart';

/// Wraps the app (via `MaterialApp.builder`) with the in-context editor:
/// an Edit button, the editor toolbar, pick mode and the highlight layer.
///
/// It sits above the app's Navigator, so dialogs and pages are opened
/// through that Navigator. Editor UI text is plain English and never
/// localized, so it carries no key tags and can't be picked by mistake.
class L10nEditOverlay extends StatefulWidget {
  /// Wraps [child], the Navigator built by `MaterialApp`.
  const L10nEditOverlay({required this.child, super.key});

  /// The app content.
  final Widget child;

  @override
  State<L10nEditOverlay> createState() => _L10nEditOverlayState();
}

class _L10nEditOverlayState extends State<L10nEditOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _contentKey = GlobalKey();

  /// Re-measures highlights every frame while they are shown, so they follow
  /// scrolling and route changes.
  late final Ticker _ticker = createTicker((_) => _updateHighlights());
  List<Rect> _highlights = const [];

  /// A dialog opened by picking a text is showing.
  bool _dialogOpen = false;

  /// How far the toolbar (or Edit button) was dragged from the bottom-right
  /// corner. Kept here so it stays put while it is hidden or swapped.
  Offset _toolbarOffset = Offset.zero;

  EditorConfig get _config => context.read<EditorConfig>();

  RenderBox? get _contentBox =>
      _contentKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// The app's Navigator: the configured key, else the first Navigator
  /// below the overlay, which is the one `MaterialApp` builds.
  NavigatorState? get _navigator {
    final configured = _config.navigatorKey?.currentState;
    if (configured != null) return configured;
    NavigatorState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        found = element.state as NavigatorState;
        return;
      }
      element.visitChildren(visit);
    }

    _contentKey.currentContext?.visitChildElements(visit);
    return found;
  }

  void _syncHighlight() {
    final on =
        context.read<EditorSessionBloc>().state.isEditor &&
        context.read<EditorToolsCubit>().state.highlight;
    if (on && !_ticker.isActive) {
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
      setState(() => _highlights = const []);
    }
  }

  void _updateHighlights() {
    final box = _contentBox;
    if (box == null || !box.hasSize) return;
    final rects = [
      // Texts under a dialog aren't outlined: the outlines are drawn above
      // the app's Navigator, so they would show on top of the dialog.
      for (final tagged in findTaggedTexts(
        _config.catalog,
        box,
        uncoveredOnly: true,
      ))
        tagged.rect,
    ];
    if (!listEquals(rects, _highlights)) setState(() => _highlights = rects);
  }

  /// Pick mode stays on across picks: its layer is lifted while the dialogs
  /// are open, so they get the taps, and put back once they close.
  Future<void> _pick(Offset globalPosition) async {
    final box = _contentBox;
    final navigatorContext = _navigator?.context;
    if (box == null || navigatorContext == null) return;
    final keys = keysAt(_config.catalog, box, globalPosition);
    if (keys.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text("This text isn't from the ARB files.")),
      );
      return;
    }
    final tools = context.read<EditorToolsCubit>()..setPickMode(false);
    // The toolbar is drawn above the app's Navigator, so it is hidden
    // while the dialogs are open instead of showing on top of them.
    setState(() => _dialogOpen = true);
    try {
      await _editPicked(navigatorContext, keys);
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
      // Unless edit access ended meanwhile, which resets the tools.
      if (mounted && context.read<EditorSessionBloc>().state.isEditor) {
        tools.setPickMode(true);
      }
    }
  }

  Future<void> _editPicked(
    BuildContext navigatorContext,
    List<String> keys,
  ) async {
    final key = keys.length == 1
        ? keys.single
        : await showDialog<String>(
            context: navigatorContext,
            builder: (context) => SimpleDialog(
              title: const Text('Which string?'),
              children: [
                for (final key in keys)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, key),
                    child: Text(key),
                  ),
              ],
            ),
          );
    if (key == null || !navigatorContext.mounted) return;
    await showEditKeyDialog(navigatorContext, key);
  }

  void _requestAccess() {
    final request = _config.onRequestAccess;
    final navigatorContext = _navigator?.context;
    if (request == null || navigatorContext == null) return;
    request(navigatorContext);
  }

  /// The key table is open. The toolbar stays on top of it, so another tap
  /// on All keys must not push a second copy.
  bool _keyTableOpen = false;

  Future<void> _openKeyTable() async {
    final navigator = _navigator;
    if (_keyTableOpen || navigator == null) return;
    setState(() => _keyTableOpen = true);
    try {
      await navigator.push(
        MaterialPageRoute<void>(builder: (_) => const L10nKeyTablePage()),
      );
    } finally {
      if (mounted) setState(() => _keyTableOpen = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final config = _config;
    return MultiBlocListener(
      listeners: [
        BlocListener<EditorSessionBloc, EditorSessionState>(
          listener: (context, state) {
            _syncHighlight();
            final failure = state.failure;
            if (failure != null) _showError(failure.message);
          },
        ),
        BlocListener<EditorToolsCubit, EditorToolsState>(
          listener: (context, _) => _syncHighlight(),
        ),
        // Save failures are shown inside the edit dialog instead.
        BlocListener<TranslationsBloc, TranslationsState>(
          listenWhen: (previous, current) =>
              previous.outcome != current.outcome &&
              current.outcome?.failure != null &&
              current.outcome?.operation != TranslationsOperation.save,
          listener: (context, state) =>
              _showError(state.outcome!.failure!.message),
        ),
      ],
      child: Builder(
        builder: (context) {
          final session = context.watch<EditorSessionBloc>().state;
          final tools = context.watch<EditorToolsCubit>().state;
          final unpublished = context.select<TranslationsBloc, int>(
            (bloc) => bloc.state.unpublishedCount,
          );
          final cubit = context.read<EditorToolsCubit>();
          final isEditor = session.isEditor;
          // The editor UI sits above the app's Navigator, so it brings its
          // own Overlay for tooltips.
          return Overlay.wrap(
            child: Stack(
              fit: StackFit.expand,
              children: [
                KeyedSubtree(key: _contentKey, child: widget.child),
                if (isEditor && tools.highlight)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _HighlightPainter(_highlights, colors.tertiary),
                    ),
                  ),
                if (isEditor && tools.pickMode)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _pick(details.globalPosition),
                    child: ColoredBox(
                      color: colors.primary.withValues(alpha: 0.06),
                    ),
                  ),
                if (!_dialogOpen &&
                    (isEditor || config.onRequestAccess != null))
                  Positioned.fill(
                    child: SafeArea(
                      child: Padding(
                        padding: paddingMd,
                        child: _Movable(
                          fromCorner: _toolbarOffset,
                          onMoved: (offset) =>
                              setState(() => _toolbarOffset = offset),
                          child: isEditor
                              ? _EditorToolbar(
                                  label: config.label,
                                  tools: tools,
                                  unpublished: unpublished,
                                  onPick: cubit.togglePickMode,
                                  onHighlight: cubit.toggleHighlight,
                                  keysOpen: _keyTableOpen,
                                  onKeys: _openKeyTable,
                                  onSignOut: config.onSignOut,
                                )
                              : FloatingActionButton.small(
                                  heroTag: null,
                                  tooltip: 'Edit translations',
                                  onPressed:
                                      session.status ==
                                          EditorSessionStatus.checking
                                      ? null
                                      : _requestAccess,
                                  child: const Icon(Icons.edit_note),
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Places [child] [fromCorner] away from the bottom-right corner of the
/// available space, and lets it be dragged anywhere inside that space.
///
/// Taps still reach [child]: a drag only starts once the pointer moves.
class _Movable extends StatefulWidget {
  const _Movable({
    required this.fromCorner,
    required this.onMoved,
    required this.child,
  });

  /// Distance from the right (dx) and bottom (dy) edges.
  final Offset fromCorner;
  final ValueChanged<Offset> onMoved;
  final Widget child;

  @override
  State<_Movable> createState() => _MovableState();
}

class _MovableState extends State<_Movable> {
  final GlobalKey _childKey = GlobalKey();

  /// The offset during a drag.
  Offset? _dragged;

  Size get _childSize {
    final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize ? box.size : Size.zero;
  }

  /// [offset] kept inside [bounds], so the child can't leave the screen,
  /// also after a rotation or a resize.
  Offset _clamp(Offset offset, Size bounds) {
    final child = _childSize;
    return Offset(
      offset.dx.clamp(0, math.max(0, bounds.width - child.width)),
      offset.dy.clamp(0, math.max(0, bounds.height - child.height)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final offset = _clamp(widget.fromCorner, bounds);
        // A Stack without a background only takes the hits its children
        // take, so the app below stays usable.
        return Stack(
          children: [
            Positioned(
              right: offset.dx,
              bottom: offset.dy,
              child: GestureDetector(
                key: _childKey,
                onPanStart: (_) => _dragged = offset,
                onPanUpdate: (details) {
                  // Kept here as well: several updates can arrive before
                  // the parent rebuilds with the new offset.
                  final moved = _clamp(
                    (_dragged ?? offset) -
                        Offset(details.delta.dx, details.delta.dy),
                    bounds,
                  );
                  _dragged = moved;
                  widget.onMoved(moved);
                },
                onPanEnd: (_) => _dragged = null,
                onPanCancel: () => _dragged = null,
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: widget.child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.label,
    required this.tools,
    required this.unpublished,
    required this.onPick,
    required this.onHighlight,
    required this.keysOpen,
    required this.onKeys,
    required this.onSignOut,
  });

  final String? label;
  final EditorToolsState tools;
  final int unpublished;
  final VoidCallback onPick;
  final VoidCallback onHighlight;
  final bool keysOpen;
  final VoidCallback onKeys;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = this.label;
    final onSignOut = this.onSignOut;
    return Material(
      elevation: 4,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Spacing.md),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
              child: Text(
                tools.pickMode
                    ? 'Tap a text to edit it'
                    : label == null
                    ? 'Editing drafts'
                    : 'Editing drafts · $label',
                style: theme.textTheme.labelSmall,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The whole toolbar can be dragged; this shows that it can.
                Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                IconButton(
                  tooltip: 'Pick a text',
                  isSelected: tools.pickMode,
                  onPressed: onPick,
                  icon: const Icon(Icons.ads_click),
                ),
                IconButton(
                  tooltip: 'Highlight texts',
                  isSelected: tools.highlight,
                  onPressed: onHighlight,
                  icon: const Icon(Icons.highlight_alt),
                ),
                IconButton(
                  tooltip: 'All keys',
                  isSelected: keysOpen,
                  onPressed: onKeys,
                  icon: Badge(
                    isLabelVisible: unpublished > 0,
                    label: Text('$unpublished'),
                    child: const Icon(Icons.table_rows_outlined),
                  ),
                ),
                if (onSignOut != null)
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  const _HighlightPainter(this.rects, this.color);

  final List<Rect> rects;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    for (final rect in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      !listEquals(old.rects, rects) || old.color != color;
}
