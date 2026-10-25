import 'package:flutter/widgets.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

/// Hand-written equivalent of a generated override file, for a tiny app
/// with English and Hindi.
const L10nCatalog testCatalog = L10nCatalog(
  languages: ['en', 'hi'],
  keys: [
    L10nKeyInfo(
      name: 'welcomeTitle',
      description: 'Heading on the home screen',
      placeholders: [],
      bundled: {'en': 'Welcome', 'hi': 'स्वागत है'},
      overridable: true,
    ),
    L10nKeyInfo(
      name: 'retry',
      description: '',
      placeholders: [],
      bundled: {'en': 'Retry', 'hi': 'फिर से प्रयास करें'},
      overridable: true,
    ),
    L10nKeyInfo(
      name: 'getStarted',
      description: '',
      placeholders: [],
      bundled: {'en': 'Get started', 'hi': 'शुरू करें'},
      overridable: true,
    ),
    L10nKeyInfo(
      name: 'farmerRegistered',
      description: '',
      placeholders: [
        L10nPlaceholder(name: 'name', type: 'String', example: 'Ramesh'),
      ],
      bundled: {'en': '{name} registered', 'hi': '{name} पंजीकृत हो गए'},
      overridable: true,
    ),
    L10nKeyInfo(
      name: 'pondCount',
      description: '',
      placeholders: [L10nPlaceholder(name: 'count', type: 'int')],
      bundled: {
        'en': '{count, plural, =0{No ponds} =1{1 pond} other{{count} ponds}}',
        'hi': '{count, plural, =0{कोई तालाब नहीं} other{{count} तालाब}}',
      },
      overridable: true,
    ),
    L10nKeyInfo(
      name: 'lastSeen',
      description: '',
      placeholders: [L10nPlaceholder(name: 'date', type: 'DateTime')],
      bundled: {'en': 'Seen {date}', 'hi': '{date} को देखा'},
      overridable: false,
    ),
  ],
);

/// Stands in for a gen-l10n class.
class TestStrings {
  TestStrings(this.localeName);

  final String localeName;

  bool get _hi => localeName == 'hi';

  String get welcomeTitle => _hi ? 'स्वागत है' : 'Welcome';
  String get retry => _hi ? 'फिर से प्रयास करें' : 'Retry';
  String get getStarted => _hi ? 'शुरू करें' : 'Get started';
  String farmerRegistered(String name) =>
      _hi ? '$name पंजीकृत हो गए' : '$name registered';
  String pondCount(int count) => '$count';
  String lastSeen(DateTime date) => 'Seen ${date.year}';
}

/// What the generator writes for [TestStrings].
class TestStringsOverride extends TestStrings {
  TestStringsOverride(this._bundled, this._messages)
    : super(_bundled.localeName);

  final TestStrings _bundled;
  final L10nMessageResolver _messages;

  @override
  String get welcomeTitle =>
      _messages.resolve(0, 'welcomeTitle', () => _bundled.welcomeTitle);
  @override
  String get retry => _messages.resolve(1, 'retry', () => _bundled.retry);
  @override
  String get getStarted =>
      _messages.resolve(2, 'getStarted', () => _bundled.getStarted);
  @override
  String farmerRegistered(String name) => _messages.resolve(
    3,
    'farmerRegistered',
    () => _bundled.farmerRegistered(name),
    {'name': name},
  );
  @override
  String pondCount(int count) => _messages.resolve(
    4,
    'pondCount',
    () => _bundled.pondCount(count),
    {'count': count},
  );
  @override
  String lastSeen(DateTime date) =>
      _messages.bundledOnly(5, () => _bundled.lastSeen(date));
}

class TestStringsDelegate extends L10nOverrideDelegate<TestStrings> {
  const TestStringsDelegate({super.messages, super.tagKeys});

  @override
  L10nCatalog get catalog => testCatalog;

  @override
  bool isSupported(Locale locale) =>
      const {'en', 'hi'}.contains(locale.languageCode);

  @override
  TestStrings lookupBundled(Locale locale) => TestStrings(locale.languageCode);

  @override
  TestStrings createOverride(
    TestStrings bundled,
    Map<String, String> messages,
  ) => TestStringsOverride(
    bundled,
    L10nMessageResolver(
      localeName: bundled.localeName,
      messages: messages,
      tagKeys: tagKeys,
    ),
  );

  @override
  TestStringsDelegate copyWith({MessagesByLanguage? messages, bool? tagKeys}) =>
      TestStringsDelegate(
        messages: messages ?? this.messages,
        tagKeys: tagKeys ?? this.tagKeys,
      );
}

const EditorUser testEditor = EditorUser(
  id: 'u1',
  displayName: 'ed@example.com',
);

/// In-memory data source whose writes can be made to fail.
class FailingTranslationDataSource extends InMemoryL10nTranslationDataSource {
  FailingTranslationDataSource({super.drafts, super.published});

  Exception? failWith;

  /// `(lang, key, value, previousValue)` of every successful save.
  final List<(String, String, String, String?)> saves = [];

  @override
  Future<void> saveDraft({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    String? previousValue,
  }) async {
    if (failWith case final error?) throw error;
    saves.add((languageCode, key, value, previousValue));
    return super.saveDraft(
      editor: editor,
      languageCode: languageCode,
      key: key,
      value: value,
      previousValue: previousValue,
    );
  }

  @override
  Future<void> publish({
    required EditorUser editor,
    required MessagesByLanguage messages,
    required List<String> changedKeys,
  }) async {
    if (failWith case final error?) throw error;
    return super.publish(
      editor: editor,
      messages: messages,
      changedKeys: changedKeys,
    );
  }
}
