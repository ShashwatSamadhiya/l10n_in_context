import 'dart:io';

import 'package:l10n_in_context/src/generator/arb_merge.dart';

/// `dart run l10n_in_context:merge <file>... [--dry-run]`
Future<void> main(List<String> args) async {
  exitCode = await runMerge(args);
}
