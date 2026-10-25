import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/src/generator/generator.dart';

/// The parts of a gen-l10n output the generator reads.
const String _generated = '''
import 'package:flutter/widgets.dart';

abstract class AppStrings {
  AppStrings(String locale) : localeName = locale;

  final String localeName;

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// In en, this message translates to:
  /// **'{name} registered'**
  String farmerRegistered(String name);

  String lastSeen(DateTime date);

  String price(double amount);
}
''';

const Map<String, dynamic> _template = {
  '@@locale': 'en',
  'retry': 'Retry',
  '@retry': {'description': "Farmer's retry button"},
  'farmerRegistered': '{name} registered',
  '@farmerRegistered': {
    'placeholders': {
      'name': {'type': 'String', 'example': r'Ramesh $1'},
    },
  },
  'lastSeen': 'Seen {date}',
  'price': '{amount}',
  '@price': {
    'placeholders': {
      'amount': {'type': 'double', 'format': 'currency'},
    },
  },
};

const L10nConfig _config = L10nConfig(
  arbDir: 'lib/l10n',
  templateArbFile: 'app_en.arb',
  outputDir: 'lib/l10n',
  outputFile: 'app_strings.dart',
  outputClass: 'AppStrings',
);

void main() {
  group('parseMembers', () {
    test('reads getters and methods with their parameters', () {
      final members = parseMembers(_generated, 'AppStrings');
      expect(members.map((m) => m.name), [
        'retry',
        'farmerRegistered',
        'lastSeen',
        'price',
      ]);
      expect(members.first.parameters, isNull);
      expect(members[1].parameters!.single.type, 'String');
    });

    test('fails clearly when the class is missing', () {
      expect(
        () => parseMembers(_generated, 'AppLocalizations'),
        throwsA(isA<GeneratorException>()),
      );
    });
  });

  group('bundledOnlyReason', () {
    final members = parseMembers(_generated, 'AppStrings');
    final formatted = formattedPlaceholders(_template);

    test('allows plain types without a format', () {
      expect(bundledOnlyReason(members[1], formatted), isNull);
    });

    test('rejects types the runtime formatter cannot render', () {
      expect(bundledOnlyReason(members[2], formatted), 'date is DateTime');
    });

    test('rejects placeholders with a format', () {
      expect(bundledOnlyReason(members[3], formatted), contains('amount'));
    });
  });

  group('L10nConfig.parse', () {
    test('ignores trailing comments and quotes', () {
      final config = L10nConfig.parse('''
# Localization settings
arb-dir: lib/l10n # ARB files
template-arb-file: "app_en.arb"  # the template
output-class: 'Strings' # generated class
output-localization-file: strings.dart
''');
      expect(config.arbDir, 'lib/l10n');
      expect(config.templateArbFile, 'app_en.arb');
      expect(config.outputClass, 'Strings');
      expect(config.generatedFilePath, 'lib/l10n/strings.dart');
    });

    test('keeps # inside quotes and without a space before it', () {
      final config = L10nConfig.parse('''
arb-dir: 'lib/l10n #1' # comment
output-class: App#Strings
''');
      expect(config.arbDir, 'lib/l10n #1');
      expect(config.outputClass, 'App#Strings');
    });

    test('rejects synthetic-package even with a comment', () {
      expect(
        () => L10nConfig.parse('synthetic-package: true # legacy'),
        throwsA(isA<GeneratorException>()),
      );
    });

    test('uses gen-l10n defaults', () {
      final config = L10nConfig.parse('');
      expect(config.arbDir, 'lib/l10n');
      expect(config.outputClass, 'AppLocalizations');
    });
  });

  test('defaults the output next to the gen-l10n file', () {
    expect(_config.defaultOutputPath, 'lib/l10n/app_strings_override.dart');
  });

  group('renderOverrideFile', () {
    final source = renderOverrideFile(
      config: _config,
      outputPath: 'lib/l10n/app_strings_override.dart',
      members: parseMembers(_generated, 'AppStrings'),
      template: _template,
      bundled: {
        'en': {'retry': 'Retry', 'farmerRegistered': '{name} registered'},
        'hi': {'retry': 'फिर से'},
      },
    );

    test('names everything after the gen-l10n class', () {
      expect(source, contains('const L10nCatalog appStringsCatalog'));
      expect(source, contains('class AppStringsOverride extends AppStrings'));
      expect(
        source,
        contains(
          'class AppStringsOverrideDelegate '
          'extends L10nOverrideDelegate<AppStrings>',
        ),
      );
      expect(source, contains('lookupAppStrings(locale)'));
      expect(source, contains("import 'app_strings.dart';"));
    });

    test('lists every ARB language', () {
      expect(source, contains("languages: ['en', 'hi']"));
    });

    test('resolves overridable keys by catalog index', () {
      expect(
        source,
        contains("_messages.resolve(0, 'retry', () => _bundled.retry)"),
      );
      expect(
        source,
        contains(
          "_messages.resolve(1, 'farmerRegistered', "
          "() => _bundled.farmerRegistered(name), {'name': name})",
        ),
      );
    });

    test('keeps unsupported keys bundled but tagged', () {
      expect(source, contains('// Bundled only: date is DateTime.'));
      expect(
        source,
        contains('_messages.bundledOnly(2, () => _bundled.lastSeen(date))'),
      );
      expect(source, contains('overridable: false'));
    });

    test('escapes quotes and dollar signs in literals', () {
      expect(source, contains(r"description: 'Farmer\'s retry button'"));
      expect(source, contains(r"example: 'Ramesh \$1'"));
    });
  });

  group('GeneratorOptions', () {
    test('parses output and check', () {
      final options = GeneratorOptions.parse(['--output=a.dart', '--check']);
      expect(options.output, 'a.dart');
      expect(options.check, isTrue);
      expect(GeneratorOptions.parse(['--output', 'b.dart']).output, 'b.dart');
    });

    test('rejects unknown options', () {
      expect(
        () => GeneratorOptions.parse(['--nope']),
        throwsA(isA<GeneratorException>()),
      );
    });
  });
}
