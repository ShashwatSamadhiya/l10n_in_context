// Merges ARBs exported from the editor into the project's ARB files:
// each message replaces the one with the same key in the ARB file with the
// same `@@locale`. Key order, metadata (`@key`) and indentation are kept.

import 'dart:convert';
import 'dart:io';

import 'generator.dart';

const String _usage = '''
Usage: dart run l10n_in_context:merge <file>... [options]

Run from the app's root. Each file is text copied from the editor's
Export ARB dialog: one ARB, or every language at once. Each language's
messages are written into the project's ARB file with the same @@locale.
Pass - to read from standard input.

Options:
  --dry-run   Print what would change; write nothing.
  -h, --help  Show this help.''';

/// Runs the merge with command-line [args]. Returns the exit code.
Future<int> runMerge(List<String> args) async {
  final inputs = <String>[];
  var dryRun = false;
  for (final arg in args) {
    if (arg == '-h' || arg == '--help') {
      stdout.writeln(_usage);
      return 0;
    } else if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg.startsWith('-') && arg != '-') {
      stderr
        ..writeln('l10n_in_context: Unknown option "$arg".')
        ..writeln(_usage);
      return 64;
    } else {
      inputs.add(arg);
    }
  }
  if (inputs.isEmpty) {
    stderr
      ..writeln('l10n_in_context: No ARB files given.')
      ..writeln(_usage);
    return 64;
  }

  try {
    final config = L10nConfig.read(File('l10n.yaml'));
    final templateKeys =
        (jsonDecode(File(config.templateArbPath).readAsStringSync())
                as Map<String, dynamic>)
            .keys
            .toSet();
    final targets = _arbFilesByLocale(config.arbDir);

    // Read and check every input before writing anything.
    final writes = <File, String>{};
    final exports = [
      for (final input in inputs)
        for (final arb in exportedArbs(
          input == '-'
              ? await stdin.transform(utf8.decoder).join()
              : File(input).readAsStringSync(),
          input == '-' ? 'standard input' : input,
        ))
          (input, arb),
    ];
    for (final (input, exported) in exports) {
      final locale = exported['@@locale'];
      final target = targets[locale];
      if (target == null) {
        throw GeneratorException(
          '$input: no ARB file in ${config.arbDir} has "@@locale": '
          '"$locale"',
        );
      }
      final messages = exportedMessages(exported, input);
      final unknown = messages.keys.where((k) => !templateKeys.contains(k));
      if (unknown.isNotEmpty) {
        throw GeneratorException(
          '$input: keys not in ${config.templateArbPath}: '
          '${unknown.join(', ')}',
        );
      }
      final original = writes[target] ?? target.readAsStringSync();
      final merge = mergeArb(original, messages);
      writes[target] = merge.contents;
      stdout.writeln(
        '${target.path}: ${merge.changedKeys.length} changed'
        '${merge.changedKeys.isEmpty ? '' : ' (${merge.changedKeys.join(', ')})'}',
      );
    }

    if (dryRun) {
      stdout.writeln('Dry run: nothing written.');
      return 0;
    }
    writes.forEach((file, contents) => file.writeAsStringSync(contents));
    stdout.writeln(
      'Next: flutter gen-l10n && dart run l10n_in_context:generate',
    );
    return 0;
  } on FileSystemException catch (e) {
    stderr.writeln('l10n_in_context: cannot read ${e.path}');
    return 2;
  } on GeneratorException catch (e) {
    stderr.writeln('l10n_in_context: ${e.message}');
    return 2;
  }
}

/// The ARBs in an exported [source]: one ARB object, or a list of them as
/// the editor's "Copy all languages" writes. Each needs an `@@locale`.
List<Map<String, dynamic>> exportedArbs(String source, String name) {
  final Object? json;
  try {
    json = jsonDecode(source);
  } on FormatException catch (e) {
    throw GeneratorException('$name is not valid JSON: ${e.message}');
  }
  final arbs = json is List ? json : [json];
  return [
    for (final (index, arb) in arbs.indexed)
      if (arb is Map<String, dynamic> && arb['@@locale'] is String)
        arb
      else
        throw GeneratorException(
          json is List
              ? '$name: item ${index + 1} is not an ARB with "@@locale"'
              : '$name is not an ARB with "@@locale"',
        ),
  ];
}

/// The messages of an exported ARB: every key that isn't metadata.
Map<String, String> exportedMessages(Map<String, dynamic> arb, String name) {
  final result = <String, String>{};
  for (final MapEntry(:key, :value) in arb.entries) {
    if (key.startsWith('@')) continue;
    if (value is! String) {
      throw GeneratorException('$name: "$key" is not a string');
    }
    result[key] = value;
  }
  return result;
}

/// The result of [mergeArb].
typedef ArbMerge = ({String contents, List<String> changedKeys});

/// [original] ARB contents with [messages] written in. Only the changed
/// values are rewritten, in place; new keys are appended with the file's
/// indentation. Every other byte, including metadata formatting, is kept.
/// [ArbMerge.changedKeys] lists the keys whose text changed.
ArbMerge mergeArb(String original, Map<String, String> messages) {
  final arb = _decode(original, 'ARB file');
  final changedKeys = [
    for (final MapEntry(:key, :value) in messages.entries)
      if (arb[key] != value) key,
  ];
  if (changedKeys.isEmpty) {
    return (contents: original, changedKeys: changedKeys);
  }
  final layout = _scanTopLevel(original);
  final indent =
      RegExp(r'^([ \t]+)"', multiLine: true).firstMatch(original)?.group(1) ??
      '  ';
  // (start, end, replacement), applied from the end so offsets stay valid.
  final edits = <(int, int, String)>[];
  var appended = '';
  for (final key in changedKeys) {
    final value = jsonEncode(messages[key]);
    final span = layout.values[key];
    if (span != null) {
      edits.add((span.$1, span.$2, value));
    } else {
      final comma = layout.values.isEmpty && appended.isEmpty ? '' : ',';
      appended += '$comma\n$indent${jsonEncode(key)}: $value';
    }
  }
  if (appended.isNotEmpty) {
    edits.add((layout.lastEnd, layout.lastEnd, appended));
  }
  edits.sort((a, b) => b.$1.compareTo(a.$1));
  var contents = original;
  for (final (start, end, replacement) in edits) {
    contents = contents.replaceRange(start, end, replacement);
  }
  return (contents: contents, changedKeys: changedKeys);
}

/// Where each top-level value of the valid JSON object [s] sits:
/// `key -> (start, end)`, and where the last value ends (just after `{`
/// when the object is empty).
({Map<String, (int, int)> values, int lastEnd}) _scanTopLevel(String s) {
  int skipSpace(int i) {
    while (i < s.length && ' \t\r\n'.contains(s[i])) {
      i++;
    }
    return i;
  }

  // From an opening quote to just after the closing one.
  int skipString(int i) {
    i++;
    while (s[i] != '"') {
      i += s[i] == r'\' ? 2 : 1;
    }
    return i + 1;
  }

  int skipValue(int i) {
    if (s[i] == '"') return skipString(i);
    if (s[i] == '{' || s[i] == '[') {
      var depth = 0;
      do {
        final c = s[i];
        if (c == '"') {
          i = skipString(i);
          continue;
        }
        if (c == '{' || c == '[') depth++;
        if (c == '}' || c == ']') depth--;
        i++;
      } while (depth > 0);
      return i;
    }
    while (i < s.length && !',}] \t\r\n'.contains(s[i])) {
      i++;
    }
    return i;
  }

  final values = <String, (int, int)>{};
  var i = s.indexOf('{') + 1;
  var lastEnd = i;
  while (true) {
    i = skipSpace(i);
    if (s[i] == '}') return (values: values, lastEnd: lastEnd);
    if (s[i] == ',') i = skipSpace(i + 1);
    final keyEnd = skipString(i);
    final key = jsonDecode(s.substring(i, keyEnd)) as String;
    final start = skipSpace(skipSpace(keyEnd) + 1); // past the colon
    final end = skipValue(start);
    values[key] = (start, end);
    lastEnd = i = end;
  }
}

Map<String, dynamic> _decode(String source, String name) {
  try {
    final json = jsonDecode(source);
    if (json is Map<String, dynamic>) return json;
  } on FormatException catch (e) {
    throw GeneratorException('$name is not valid JSON: ${e.message}');
  }
  throw GeneratorException('$name is not an ARB object');
}

/// `@@locale -> file` for every ARB file in [arbDir] that has a locale.
Map<String, File> _arbFilesByLocale(String arbDir) {
  final result = <String, File>{};
  for (final file in Directory(arbDir).listSync().whereType<File>()) {
    if (!file.path.endsWith('.arb')) continue;
    final locale = _decode(file.readAsStringSync(), file.path)['@@locale'];
    if (locale is String) result[locale] = file;
  }
  return result;
}
