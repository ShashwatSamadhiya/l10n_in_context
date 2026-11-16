import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/messages_by_language.dart';
import '../../domain/usecases/export_arb.dart';
import '../bloc/translations/translations_bloc.dart';
import 'editor_config.dart';
import 'spacing.dart';

/// Opens the dialog that copies edited messages as ARB files.
Future<void> showExportArbDialog(BuildContext context) {
  final export = ArbExport(context.read<EditorConfig>().catalog);
  return showDialog<void>(
    context: context,
    builder: (_) => ExportArbDialog(export: export),
  );
}

/// Which messages [ExportArbDialog] exports.
enum ArbExportSource {
  /// What app users see.
  published('Published'),

  /// Drafts layered over the published messages.
  drafts('Drafts');

  const ArbExportSource(this.label);

  /// Shown on the toggle.
  final String label;
}

/// Lists, per language, the messages that differ from the bundled ARB and
/// copies each language as an ARB file.
class ExportArbDialog extends StatefulWidget {
  /// Creates the dialog.
  const ExportArbDialog({required this.export, super.key});

  /// Builds the ARB files.
  final ArbExport export;

  @override
  State<ExportArbDialog> createState() => _ExportArbDialogState();
}

class _ExportArbDialogState extends State<ExportArbDialog> {
  ArbExportSource _source = ArbExportSource.published;

  MessagesByLanguage _messages(TranslationsState state) => switch (_source) {
    ArbExportSource.published => state.snapshot.published,
    ArbExportSource.drafts => {
      for (final lang in widget.export.catalog.languages)
        lang: state.snapshot.effectiveDraft(lang),
    },
  };

  Future<void> _copy(String text, String what) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Copied $what. Paste it into $_fileName and run the merge command.',
          ),
        ),
      );
  }

  static const String _fileName = 'l10n_changes.json';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<TranslationsBloc>().state;
    final changes = widget.export.changes(_messages(state));
    final total = changes.values.fold(0, (n, m) => n + m.length);
    final code = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return AlertDialog(
      title: const Text('Export ARB'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Writes the edited strings back into your ARB files. Only '
                'strings that differ from the bundled ARB are copied.',
              ),
              gapSm,
              const Text('1. Copy all languages (or just one below).'),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '2. Paste into a new file, e.g. '),
                    TextSpan(text: _fileName, style: code),
                    const TextSpan(text: ', in the app’s root.'),
                  ],
                ),
              ),
              const Text('3. Run there:'),
              gapSm,
              SelectableText(
                'dart run l10n_in_context:merge $_fileName',
                style: code,
              ),
              gapMd,
              SegmentedButton<ArbExportSource>(
                showSelectedIcon: false,
                segments: [
                  for (final source in ArbExportSource.values)
                    ButtonSegment(value: source, label: Text(source.label)),
                ],
                selected: {_source},
                onSelectionChanged: (selection) =>
                    setState(() => _source = selection.first),
              ),
              gapSm,
              for (final lang in widget.export.catalog.languages)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(lang.toUpperCase()),
                  subtitle: Text(switch (changes[lang]?.length ?? 0) {
                    0 => 'Same as bundled',
                    1 => '1 changed message',
                    final n => '$n changed messages',
                  }),
                  trailing: TextButton.icon(
                    onPressed: changes[lang] == null
                        ? null
                        : () => _copy(
                            widget.export.arb(lang, changes[lang]!),
                            lang.toUpperCase(),
                          ),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: total == 0
              ? null
              : () => _copy(widget.export.arbs(changes), 'every language'),
          icon: const Icon(Icons.copy_all, size: 18),
          label: Text('Copy all languages ($total)'),
        ),
      ],
    );
  }
}
