import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/l10n_access_data_source.dart';
import '../../data/datasources/l10n_translation_data_source.dart';
import '../../data/repositories/editor_access_repository_impl.dart';
import '../../data/repositories/translation_repository_impl.dart';
import '../../domain/entities/messages_by_language.dart';
import '../../domain/entities/translation_snapshot.dart';
import '../../domain/usecases/import_bundled.dart';
import '../../domain/usecases/publish_drafts.dart';
import '../../domain/usecases/save_draft.dart';
import '../../domain/usecases/watch_editor_access.dart';
import '../../domain/usecases/watch_translations.dart';
import '../bloc/editor_session/editor_session_bloc.dart';
import '../bloc/editor_tools/editor_tools_cubit.dart';
import '../bloc/translations/translations_bloc.dart';
import '../l10n/l10n_override_delegate.dart';
import 'editor_config.dart';
import 'l10n_edit_overlay.dart';

/// What [InContextEditor.builder] plugs into `MaterialApp`.
class InContextL10n {
  const InContextL10n._({required this.delegate, required this.overlay});

  /// Use in `localizationsDelegates` in place of the gen-l10n delegate.
  /// Editors get their drafts, tagged so they can be picked on screen;
  /// everyone else gets the delegate passed to [InContextEditor].
  final LocalizationsDelegate<Object?> delegate;

  /// Use as `MaterialApp.builder`. To keep a builder of your own, nest it:
  /// `builder: (context, child) => l10n.overlay(context, mine(context, child))`.
  final TransitionBuilder overlay;
}

/// Adds in-context translation editing to an app.
///
/// Wrap `MaterialApp` (or `CupertinoApp`, `WidgetsApp`) with it:
///
/// ```dart
/// InContextEditor(
///   delegate: const AppLocalizationsOverrideDelegate(),
///   accessDataSource: MyAccessDataSource(),
///   translationDataSource: MyTranslationDataSource(),
///   builder: (context, l10n) => MaterialApp(
///     localizationsDelegates: [
///       l10n.delegate,
///       ...GlobalMaterialLocalizations.delegates,
///     ],
///     builder: l10n.overlay,
///     home: const HomePage(),
///   ),
/// )
/// ```
///
/// The data sources are read once, when the editor first builds.
class InContextEditor extends StatefulWidget {
  /// Creates the editor.
  const InContextEditor({
    required this.delegate,
    required this.accessDataSource,
    required this.translationDataSource,
    required this.builder,
    this.onRequestAccess,
    this.onSignOut,
    this.label,
    this.navigatorKey,
    this.enabled = true,
    super.key,
  });

  /// The generated `...OverrideDelegate`, carrying any messages delivered
  /// over the air. Its catalog lists the keys the editor offers.
  final L10nOverrideDelegate<Object?> delegate;

  /// Decides who may edit.
  final L10nAccessDataSource accessDataSource;

  /// Stores drafts and published messages.
  final L10nTranslationDataSource translationDataSource;

  /// Builds the app with the [InContextL10n] to plug in.
  final Widget Function(BuildContext context, InContextL10n l10n) builder;

  /// Called by the Edit button shown to people without access, to start the
  /// app's own way of granting it. Access itself always comes from
  /// [accessDataSource]. Without it there is no Edit button.
  final L10nAccessRequest? onRequestAccess;

  /// Called by the toolbar's sign-out button. Without it there is no button.
  final Future<void> Function()? onSignOut;

  /// Shown in the toolbar, e.g. the backend project name.
  final String? label;

  /// The app's Navigator, for dialogs and the key table. Found automatically
  /// when null.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// False builds the app with [delegate] and no editor at all.
  final bool enabled;

  @override
  State<InContextEditor> createState() => _InContextEditorState();
}

class _InContextEditorState extends State<InContextEditor> {
  _EditorBlocs? _blocs;

  _EditorBlocs get _ensureBlocs => _blocs ??= _EditorBlocs.create(widget);

  @override
  void dispose() {
    _blocs?.close();
    super.dispose();
  }

  static Widget _passthrough(BuildContext context, Widget? child) =>
      child ?? const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.builder(
        context,
        InContextL10n._(delegate: widget.delegate, overlay: _passthrough),
      );
    }
    final blocs = _ensureBlocs;
    return RepositoryProvider.value(
      value: EditorConfig(
        catalog: widget.delegate.catalog,
        label: widget.label,
        onRequestAccess: widget.onRequestAccess,
        onSignOut: widget.onSignOut,
        navigatorKey: widget.navigatorKey,
      ),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: blocs.session),
          BlocProvider.value(value: blocs.translations),
          BlocProvider.value(value: blocs.tools),
        ],
        child: BlocListener<EditorSessionBloc, EditorSessionState>(
          listenWhen: (previous, current) => previous.user != current.user,
          listener: (context, session) {
            final user = session.user;
            blocs.translations.add(
              user == null
                  ? const TranslationsUnsubscribed()
                  : TranslationsSubscriptionRequested(user),
            );
            blocs.tools.reset();
          },
          child: Builder(builder: _buildApp),
        ),
      ),
    );
  }

  Widget _buildApp(BuildContext context) {
    final isEditor = context.select<EditorSessionBloc, bool>(
      (bloc) => bloc.state.isEditor,
    );
    final snapshot = context.select<TranslationsBloc, TranslationSnapshot>(
      (bloc) => bloc.state.snapshot,
    );
    final delegate = widget.delegate;
    return widget.builder(
      context,
      InContextL10n._(
        delegate: isEditor
            ? delegate.copyWith(
                messages: _editorMessages(delegate.messages, snapshot),
                tagKeys: true,
              )
            : delegate,
        overlay: (context, child) =>
            L10nEditOverlay(child: child ?? const SizedBox.shrink()),
      ),
    );
  }

  /// Drafts over published over the app's own messages, so an editor sees
  /// the app's OTA text until the editor's data arrives.
  MessagesByLanguage _editorMessages(
    MessagesByLanguage base,
    TranslationSnapshot snapshot,
  ) => {
    for (final lang in {
      ...widget.delegate.catalog.languages,
      ...base.keys,
      ...snapshot.drafts.keys,
      ...snapshot.published.keys,
    })
      lang: {...?base[lang], ...snapshot.effectiveDraft(lang)},
  };
}

/// The editor's blocs, wired to the app's data sources.
class _EditorBlocs {
  _EditorBlocs._(this.session, this.translations, this.tools);

  factory _EditorBlocs.create(InContextEditor widget) {
    final catalog = widget.delegate.catalog;
    final access = EditorAccessRepositoryImpl(widget.accessDataSource);
    final translations = TranslationRepositoryImpl(
      widget.translationDataSource,
    );
    return _EditorBlocs._(
      EditorSessionBloc(watchEditorAccess: WatchEditorAccess(access))
        ..add(const EditorSessionStarted()),
      TranslationsBloc(
        catalog: catalog,
        watchDrafts: WatchDrafts(translations),
        watchPublished: WatchPublished(translations),
        saveDraft: SaveDraft(translations, catalog),
        importBundled: ImportBundled(translations, catalog),
        publishDrafts: PublishDrafts(translations, catalog),
      ),
      EditorToolsCubit(),
    );
  }

  final EditorSessionBloc session;
  final TranslationsBloc translations;
  final EditorToolsCubit tools;

  void close() {
    session.close();
    translations.close();
    tools.close();
  }
}
