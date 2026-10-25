// Generates the override file from the gen-l10n output: the key catalog,
// an `...Override` subclass of the gen-l10n class that prefers override
// messages per key, and the `...OverrideDelegate` that loads it.
//
// Signatures are read from the generated abstract class, so parameter names,
// types and order always match gen-l10n exactly. The template ARB is read
// only to find placeholders with a `format` (dates, compact numbers…), which
// IcuMessageFormatter can't reproduce; those keys always use the bundled
// string. The catalog takes descriptions, examples and the raw bundled
// messages of every language from the ARB files.

import 'dart:convert';
import 'dart:io';

/// Types whose `toString()` matches gen-l10n's output when no `format` is set.
const Set<String> _overridableTypes = {
  'String',
  'int',
  'num',
  'double',
  'Object',
};

const String _usage = '''
Usage: dart run l10n_in_context:generate [options]

Run from the app's root, after `flutter gen-l10n`.

Options:
  --output=<path>  File to write. Defaults to <output-dir>/<file>_override.dart
                   next to the gen-l10n output.
  --check          Write nothing; exit 1 if the file is missing or stale (CI).
  -h, --help       Show this help.''';

/// Runs the generator with command-line [args]. Returns the exit code.
Future<int> runGenerator(List<String> args) async {
  final GeneratorOptions options;
  try {
    options = GeneratorOptions.parse(args);
  } on GeneratorException catch (e) {
    stderr
      ..writeln('l10n_in_context: ${e.message}')
      ..writeln(_usage);
    return 64;
  }
  if (options.help) {
    stdout.writeln(_usage);
    return 0;
  }
  try {
    final config = L10nConfig.read(File('l10n.yaml'));
    final outputPath = options.output ?? config.defaultOutputPath;
    final members = parseMembers(
      File(config.generatedFilePath).readAsStringSync(),
      config.outputClass,
    );
    final template = File(config.templateArbPath).readAsStringSync();
    final source = await _format(
      outputPath,
      renderOverrideFile(
        config: config,
        outputPath: outputPath,
        members: members,
        template: jsonDecode(template) as Map<String, dynamic>,
        bundled: readBundledMessages(config.arbDir),
      ),
    );

    final file = File(outputPath);
    if (options.check) {
      if (!file.existsSync() || file.readAsStringSync() != source) {
        stderr.writeln(
          '$outputPath is stale. Run: dart run l10n_in_context:generate',
        );
        return 1;
      }
      stdout.writeln('$outputPath is up to date.');
      return 0;
    }
    file.writeAsStringSync(source);
    stdout.writeln('Wrote $outputPath (${members.length} keys).');
    final formatted = formattedPlaceholders(jsonDecode(template) as Map);
    for (final member in members) {
      final reason = bundledOnlyReason(member, formatted);
      if (reason != null) {
        stdout.writeln('  bundled only: ${member.name} ($reason)');
      }
    }
    return 0;
  } on FileSystemException catch (e) {
    stderr.writeln(
      'l10n_in_context: cannot read ${e.path}; '
      'run `flutter gen-l10n` from the app root first',
    );
    return 2;
  } on GeneratorException catch (e) {
    stderr.writeln('l10n_in_context: ${e.message}');
    return 2;
  }
}

/// A problem the user can fix, reported without a stack trace.
final class GeneratorException implements Exception {
  /// Creates the exception.
  const GeneratorException(this.message);

  /// What went wrong.
  final String message;
}

/// Parsed command-line options.
final class GeneratorOptions {
  /// Creates options.
  const GeneratorOptions({this.output, this.check = false, this.help = false});

  /// Parses [args].
  factory GeneratorOptions.parse(List<String> args) {
    String? output;
    var check = false;
    var help = false;
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--check') {
        check = true;
      } else if (arg == '-h' || arg == '--help') {
        help = true;
      } else if (arg.startsWith('--output=')) {
        output = arg.substring('--output='.length);
      } else if (arg == '--output' && i + 1 < args.length) {
        output = args[++i];
      } else {
        throw GeneratorException('Unknown option "$arg".');
      }
    }
    return GeneratorOptions(output: output, check: check, help: help);
  }

  /// `--output`, if given.
  final String? output;

  /// `--check`.
  final bool check;

  /// `--help`.
  final bool help;
}

/// The subset of `l10n.yaml` that decides where gen-l10n writes its output.
final class L10nConfig {
  /// Creates a config.
  const L10nConfig({
    required this.arbDir,
    required this.templateArbFile,
    required this.outputDir,
    required this.outputFile,
    required this.outputClass,
  });

  /// `arb-dir`.
  final String arbDir;

  /// `template-arb-file`.
  final String templateArbFile;

  /// `output-dir`.
  final String outputDir;

  /// `output-localization-file`.
  final String outputFile;

  /// `output-class`.
  final String outputClass;

  /// Path of the template ARB.
  String get templateArbPath => '$arbDir/$templateArbFile';

  /// Path of the file gen-l10n writes.
  String get generatedFilePath => '$outputDir/$outputFile';

  /// `app_localizations.dart` → `app_localizations_override.dart`, next to
  /// the gen-l10n output.
  String get defaultOutputPath {
    final stem = outputFile.endsWith('.dart')
        ? outputFile.substring(0, outputFile.length - 5)
        : outputFile;
    return '$outputDir/${stem}_override.dart';
  }

  /// Reads [file]. `l10n.yaml` is flat `key: value`, so a line parser avoids
  /// a yaml dependency. Defaults mirror gen-l10n's.
  static L10nConfig read(File file) {
    if (!file.existsSync()) {
      throw const GeneratorException(
        'l10n.yaml not found; run from the app root',
      );
    }
    final values = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final match = RegExp(r'^([\w-]+)\s*:\s*(.+?)\s*$').firstMatch(line);
      if (match == null) continue;
      values[match.group(1)!] = match
          .group(2)!
          .replaceAll(RegExp('''^['"]|['"]\$'''), '');
    }
    if (values['synthetic-package'] == 'true') {
      throw const GeneratorException(
        'synthetic-package: true is not supported; set it to false so '
        'gen-l10n writes into the project',
      );
    }
    final arbDir = values['arb-dir'] ?? 'lib/l10n';
    return L10nConfig(
      arbDir: arbDir,
      templateArbFile: values['template-arb-file'] ?? 'app_en.arb',
      outputDir: values['output-dir'] ?? arbDir,
      outputFile:
          values['output-localization-file'] ?? 'app_localizations.dart',
      outputClass: values['output-class'] ?? 'AppLocalizations',
    );
  }
}

/// One parameter of a localized method.
final class Parameter {
  /// Creates a parameter.
  const Parameter(this.type, this.name);

  /// The Dart type.
  final String type;

  /// The parameter name.
  final String name;
}

/// One getter or method of the gen-l10n class.
final class Member {
  /// Creates a member.
  const Member(this.name, this.parameters);

  /// The ARB key.
  final String name;

  /// Null for getters.
  final List<Parameter>? parameters;
}

/// Reads `String get key;` and `String key(Type a, Type b);` declarations
/// from the body of the generated abstract class [className].
List<Member> parseMembers(String generated, String className) {
  final start = generated.indexOf('abstract class $className');
  if (start < 0) {
    throw GeneratorException(
      'abstract class $className not found; run flutter gen-l10n first',
    );
  }
  final body = generated.substring(start);
  final pattern = RegExp(
    r'^\s*String\s+(?:get\s+(\w+)|(\w+)\s*\(([^)]*)\))\s*;',
    multiLine: true,
  );
  final members = <Member>[];
  for (final match in pattern.allMatches(body)) {
    final getter = match.group(1);
    if (getter != null) {
      members.add(Member(getter, null));
      continue;
    }
    final parameters = match
        .group(3)!
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) {
          final parts = p.split(RegExp(r'\s+'));
          if (parts.length != 2) {
            throw GeneratorException(
              'Unsupported parameter "$p" in ${match.group(2)}',
            );
          }
          return Parameter(parts[0], parts[1]);
        })
        .toList();
    members.add(Member(match.group(2)!, parameters));
  }
  if (members.isEmpty) {
    throw GeneratorException('No members found in $className');
  }
  return members;
}

/// `key -> placeholder names` that declare a `format` or a custom date format.
Map<String, Set<String>> formattedPlaceholders(Map<dynamic, dynamic> arb) {
  final result = <String, Set<String>>{};
  for (final MapEntry(:key, :value) in arb.entries) {
    if (key is! String ||
        !key.startsWith('@') ||
        key.startsWith('@@') ||
        value is! Map) {
      continue;
    }
    final placeholders = value['placeholders'];
    if (placeholders is! Map) continue;
    for (final MapEntry(key: name, value: meta) in placeholders.entries) {
      if (meta is Map &&
          (meta.containsKey('format') ||
              meta['isCustomDateFormat'] == 'true')) {
        result.putIfAbsent(key.substring(1), () => {}).add(name as String);
      }
    }
  }
  return result;
}

/// Why [member] always uses its bundled string, or null when it can be
/// overridden.
String? bundledOnlyReason(Member member, Map<String, Set<String>> formatted) {
  final formattedNames = formatted[member.name];
  if (formattedNames != null) {
    return 'formatted placeholder: ${formattedNames.join(', ')}';
  }
  for (final parameter in member.parameters ?? const <Parameter>[]) {
    if (!_overridableTypes.contains(parameter.type)) {
      return '${parameter.name} is ${parameter.type}';
    }
  }
  return null;
}

/// `@@locale -> key -> raw message` from every `*.arb` file in [arbDir].
Map<String, Map<String, String>> readBundledMessages(String arbDir) {
  final result = <String, Map<String, String>>{};
  final files =
      Directory(arbDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final locale = json['@@locale'];
    if (locale is! String) {
      throw GeneratorException('${file.path} has no "@@locale"');
    }
    result[locale] = {
      for (final MapEntry(:key, :value) in json.entries)
        if (!key.startsWith('@') && value is String) key: value,
    };
  }
  return result;
}

/// The unformatted source of the override file.
String renderOverrideFile({
  required L10nConfig config,
  required String outputPath,
  required List<Member> members,
  required Map<String, dynamic> template,
  required Map<String, Map<String, String>> bundled,
}) {
  final className = config.outputClass;
  final overrideClass = '${className}Override';
  final delegateClass = '${className}OverrideDelegate';
  final catalogName = '${_lowerFirst(className)}Catalog';
  final formatted = formattedPlaceholders(template);

  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln(
      '// Source: ${config.generatedFilePath} and the ARB files in '
      '${config.arbDir}',
    )
    ..writeln('// Regenerate: dart run l10n_in_context:generate')
    ..writeln()
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln("import 'package:l10n_in_context/l10n_in_context.dart';")
    ..writeln()
    ..writeln(
      "import '${_relativeImport(outputPath, config.generatedFilePath)}';",
    )
    ..writeln()
    ..writeln('/// Every ARB key in template order, for the in-context editor.')
    ..writeln('const L10nCatalog $catalogName = L10nCatalog(')
    ..writeln('  languages: [${bundled.keys.map(_literal).join(', ')}],')
    ..writeln('  keys: [');
  for (final member in members) {
    final meta = template['@${member.name}'];
    final metaMap = meta is Map ? meta : const {};
    final placeholderMeta = metaMap['placeholders'];
    final description = metaMap['description'];
    out
      ..writeln('    L10nKeyInfo(')
      ..writeln('      name: ${_literal(member.name)},')
      ..writeln(
        '      description: '
        '${_literal(description is String ? description : '')},',
      )
      ..writeln('      placeholders: [');
    for (final parameter in member.parameters ?? const <Parameter>[]) {
      final parameterMeta = placeholderMeta is Map
          ? placeholderMeta[parameter.name]
          : null;
      final example = parameterMeta is Map ? parameterMeta['example'] : null;
      out.writeln(
        '        L10nPlaceholder(name: ${_literal(parameter.name)}, '
        'type: ${_literal(parameter.type)}'
        '${example == null ? '' : ', example: ${_literal('$example')}'}),',
      );
    }
    out
      ..writeln('      ],')
      ..writeln('      bundled: {');
    for (final MapEntry(key: locale, value: messages) in bundled.entries) {
      final message = messages[member.name];
      if (message != null) {
        out.writeln('        ${_literal(locale)}: ${_literal(message)},');
      }
    }
    out
      ..writeln('      },')
      ..writeln(
        '      overridable: '
        '${bundledOnlyReason(member, formatted) == null},',
      )
      ..writeln('    ),');
  }
  out
    ..writeln('  ],')
    ..writeln(');')
    ..writeln()
    ..writeln(
      '/// [$className] that prefers override messages, such as strings',
    )
    ..writeln(
      '/// delivered over the air or editor drafts, and falls back to the',
    )
    ..writeln(
      '/// bundled ARB string per key when the override is missing, empty or',
    )
    ..writeln('/// malformed.')
    ..writeln('class $overrideClass extends $className {')
    ..writeln(
      '  /// Wraps [bundled] with the override messages of [_messages].',
    )
    ..writeln(
      '  $overrideClass(this._bundled, this._messages) '
      ': super(_bundled.localeName);',
    )
    ..writeln()
    ..writeln('  final $className _bundled;')
    ..writeln('  final L10nMessageResolver _messages;');

  for (final (index, member) in members.indexed) {
    out.writeln();
    final name = member.name;
    final parameters = member.parameters;
    final reason = bundledOnlyReason(member, formatted);
    if (reason != null) {
      out.writeln('  // Bundled only: $reason.');
    }
    out.writeln('  @override');
    if (parameters == null) {
      out.writeln(
        reason != null
            ? '  String get $name => '
                  '_messages.bundledOnly($index, () => _bundled.$name);'
            : '  String get $name => '
                  "_messages.resolve($index, '$name', () => _bundled.$name);",
      );
      continue;
    }
    final signature = parameters.map((p) => '${p.type} ${p.name}').join(', ');
    final call = '_bundled.$name(${parameters.map((p) => p.name).join(', ')})';
    if (reason != null) {
      out.writeln(
        '  String $name($signature) => '
        '_messages.bundledOnly($index, () => $call);',
      );
      continue;
    }
    final argsMap = parameters.map((p) => "'${p.name}': ${p.name}").join(', ');
    out.writeln(
      '  String $name($signature) => '
      "_messages.resolve($index, '$name', () => $call, {$argsMap});",
    );
  }
  out
    ..writeln('}')
    ..writeln()
    ..writeln('/// Use in place of [$className.delegate]. Pass override')
    ..writeln(
      '/// [messages] per language, e.g. strings delivered over the air.',
    )
    ..writeln('class $delegateClass extends L10nOverrideDelegate<$className> {')
    ..writeln('  /// Creates the delegate.')
    ..writeln('  const $delegateClass({super.messages, super.tagKeys});')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  L10nCatalog get catalog => $catalogName;')
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  bool isSupported(Locale locale) => '
      '$className.delegate.isSupported(locale);',
    )
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  $className lookupBundled(Locale locale) => '
      'lookup$className(locale);',
    )
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  $className createOverride($className bundled, '
      'Map<String, String> messages) => $overrideClass(',
    )
    ..writeln('    bundled,')
    ..writeln(
      '    L10nMessageResolver(localeName: bundled.localeName, '
      'messages: messages, tagKeys: tagKeys),',
    )
    ..writeln('  );')
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  $delegateClass copyWith({MessagesByLanguage? messages, '
      'bool? tagKeys}) => $delegateClass(',
    )
    ..writeln('    messages: messages ?? this.messages,')
    ..writeln('    tagKeys: tagKeys ?? this.tagKeys,')
    ..writeln('  );')
    ..writeln('}');
  return out.toString();
}

String _lowerFirst(String value) =>
    value.isEmpty ? value : value[0].toLowerCase() + value.substring(1);

/// A single-quoted Dart string literal for [value].
String _literal(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return "'$escaped'";
}

/// Import path from [from]'s directory to [to], both relative to the root.
String _relativeImport(String from, String to) {
  final fromDir = from.split('/')..removeLast();
  final target = to.split('/');
  var common = 0;
  while (common < fromDir.length &&
      common < target.length &&
      fromDir[common] == target[common]) {
    common++;
  }
  return [
    for (var i = common; i < fromDir.length; i++) '..',
    ...target.skip(common),
  ].join('/');
}

/// Formats with the same `dart` that runs this script. `--stdin-name` makes
/// the formatter use the app's language version, so the result matches
/// `dart format lib` and `--check` stays stable.
Future<String> _format(String path, String source) async {
  final process = await Process.start(Platform.resolvedExecutable, [
    'format',
    '--stdin-name=$path',
  ]);
  process.stdin.write(source);
  await process.stdin.close();
  final (formatted, errors, exitCode) = await (
    process.stdout.transform(utf8.decoder).join(),
    process.stderr.transform(utf8.decoder).join(),
    process.exitCode,
  ).wait;
  if (exitCode != 0) {
    throw GeneratorException('dart format failed:\n$errors');
  }
  return formatted;
}
