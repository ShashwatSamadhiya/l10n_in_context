import 'dart:io';

import 'package:l10n_in_context/src/generator/generator.dart';

/// `dart run l10n_in_context:generate [--output=<path>] [--check]`
Future<void> main(List<String> args) async {
  exitCode = await runGenerator(args);
}
