import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/src/generator/arb_merge.dart';
import 'package:l10n_in_context/src/generator/generator.dart';

void main() {
  group('mergeArb', () {
    const original = '''
{
    "@@locale": "en",
    "welcomeTitle": "Welcome",
    "@welcomeTitle": {
        "description": "Heading on the home screen"
    },
    "retry": "Retry"
}
''';

    test('replaces messages in place and keeps metadata and indent', () {
      final merge = mergeArb(original, {
        'welcomeTitle': 'Hello',
        'retry': 'Retry',
      });
      expect(merge.changedKeys, ['welcomeTitle']);
      expect(merge.contents, '''
{
    "@@locale": "en",
    "welcomeTitle": "Hello",
    "@welcomeTitle": {
        "description": "Heading on the home screen"
    },
    "retry": "Retry"
}
''');
    });

    test('appends new keys at the end', () {
      final merge = mergeArb(original, {'getStarted': 'Get started'});
      expect(merge.changedKeys, ['getStarted']);
      expect(
        merge.contents,
        endsWith('    "retry": "Retry",\n    "getStarted": "Get started"\n}\n'),
      );
    });

    test('returns the original text untouched when nothing changes', () {
      const compact = '{"@@locale":"en","retry":"Retry"}';
      final merge = mergeArb(compact, {'retry': 'Retry'});
      expect(merge.changedKeys, isEmpty);
      expect(merge.contents, compact);
    });

    test('writes non-ASCII text as is', () {
      final merge = mergeArb('{\n  "@@locale": "hi"\n}', {'retry': 'फिर से'});
      expect(merge.contents, '{\n  "@@locale": "hi",\n  "retry": "फिर से"\n}');
    });

    test('leaves compact metadata and other formatting untouched', () {
      const compact = '''
{
  "@@locale": "en",
  "appTitle": "Pond diary",
  "@appTitle": {"description": "App bar title, with \\"quotes\\" {x}"},
  "addPond":"Add pond",
  "@addPond": {"placeholders": {"n": {"type": "int"}}}
}
''';
      final merge = mergeArb(compact, {
        'appTitle': 'Pond "log"',
        'addPond': 'New pond',
        'retry': 'Retry',
      });
      expect(merge.changedKeys, ['appTitle', 'addPond', 'retry']);
      expect(merge.contents, '''
{
  "@@locale": "en",
  "appTitle": "Pond \\"log\\"",
  "@appTitle": {"description": "App bar title, with \\"quotes\\" {x}"},
  "addPond":"New pond",
  "@addPond": {"placeholders": {"n": {"type": "int"}}},
  "retry": "Retry"
}
''');
    });

    test('appends to an empty object', () {
      expect(
        mergeArb('{}', {'a': 'x', 'b': 'y'}).contents,
        '{\n  "a": "x",\n  "b": "y"}',
      );
    });

    test('rejects a file that is not JSON', () {
      expect(
        () => mergeArb('{', {'retry': 'x'}),
        throwsA(isA<GeneratorException>()),
      );
    });
  });

  group('exportedArbs', () {
    test('reads one ARB or a list of them', () {
      expect(exportedArbs('{"@@locale": "en", "a": "x"}', 'f'), [
        {'@@locale': 'en', 'a': 'x'},
      ]);
      expect(exportedArbs('[{"@@locale": "en"}, {"@@locale": "hi"}]', 'f'), [
        {'@@locale': 'en'},
        {'@@locale': 'hi'},
      ]);
    });

    test('names the item without a locale', () {
      expect(
        () => exportedArbs('[{"@@locale": "en"}, {"a": "x"}]', 'f'),
        throwsA(
          isA<GeneratorException>().having(
            (e) => e.message,
            'message',
            'f: item 2 is not an ARB with "@@locale"',
          ),
        ),
      );
    });

    test('rejects text that is not JSON', () {
      expect(
        () => exportedArbs('Copied!', 'f'),
        throwsA(isA<GeneratorException>()),
      );
    });
  });

  group('exportedMessages', () {
    test('skips metadata', () {
      expect(
        exportedMessages({
          '@@locale': 'en',
          'retry': 'Again',
          '@retry': {'description': 'x'},
        }, 'a.arb'),
        {'retry': 'Again'},
      );
    });

    test('rejects a message that is not a string', () {
      expect(
        () => exportedMessages({'retry': 3}, 'a.arb'),
        throwsA(
          isA<GeneratorException>().having(
            (e) => e.message,
            'message',
            'a.arb: "retry" is not a string',
          ),
        ),
      );
    });
  });
}
