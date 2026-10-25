# l10n_in_context

[![pub package](https://img.shields.io/pub/v/l10n_in_context.svg)](https://pub.dev/packages/l10n_in_context)
[![CI](https://github.com/ShashwatSamadhiya/l10n_in_context/actions/workflows/ci.yml/badge.svg)](https://github.com/ShashwatSamadhiya/l10n_in_context/actions/workflows/ci.yml)

In-context translation editing and over-the-air (OTA) translation updates
for Flutter apps that use `flutter gen-l10n` and ARB files.

Translators and reviewers open the running app, tap any string, edit it in
every language, and see their draft on screen immediately. When the drafts
look right, they publish them to every user: you update translations without
an app release or a store review.

It is self-hosted live translation editing, in the spirit of the in-context
editors of translation management tools, but the strings stay in your own
Firebase, Supabase or REST backend.

<p align="center">
  <img src="https://raw.githubusercontent.com/ShashwatSamadhiya/l10n_in_context/main/doc/screenshots/demo.gif" alt="Tapping a string, editing it and seeing the draft live" width="300">
  <img src="https://raw.githubusercontent.com/ShashwatSamadhiya/l10n_in_context/main/doc/screenshots/edit_dialog.png" alt="Edit dialog with every language and a live preview" width="300">
</p>

- Works with your existing ARB files and `AppLocalizations.of(context)`.
  Screens don't change.
- Works with **any backend**. You implement two small interfaces, so
  Firestore, Supabase, a REST API or a local file all work.
- **You decide who may edit**: everyone in a QA build, users with a role, or
  people who pass your own login, OTP or SSO flow.
- Messages are validated before saving: ICU syntax, plurals and selects, and
  placeholders that must match the ARB.

## Platforms

| Android | iOS | Web | macOS | Windows | Linux |
| :-----: | :-: | :-: | :---: | :-----: | :---: |
|    ✅    |  ✅  |  ✅  |   ✅   |    ✅    |   ✅   |

Pure Dart and Flutter, with no platform channels. Requires Flutter 3.32 or
later (Dart 3.8).

## How it works

```
ARB files ─flutter gen-l10n─► AppLocalizations
                                   │
              dart run l10n_in_context:generate
                                   ▼
            app_localizations_override.dart (generated)
            ├─ appLocalizationsCatalog          every key, for the editor
            ├─ AppLocalizationsOverride         override message → bundled fallback
            └─ AppLocalizationsOverrideDelegate replaces AppLocalizations.delegate

InContextEditor ── L10nAccessDataSource       (your code: who may edit)
                └─ L10nTranslationDataSource  (your code: drafts and published)
```

For each key the app uses the override message when there is a usable one,
and falls back to the bundled ARB string when it is missing, empty or
malformed. Editors see their drafts. Everyone else sees the messages you pass
to the delegate, for example published strings you fetch over the air.

## Setup

### 1. Add the package and generate the override file

```bash
flutter pub add l10n_in_context
flutter gen-l10n
dart run l10n_in_context:generate
```

Run the generator again whenever the ARB files change. In CI,
`dart run l10n_in_context:generate --check` fails when the file is stale.

The generator reads `l10n.yaml` and writes
`<output-dir>/<file>_override.dart` next to the gen-l10n output. Pass
`--output=<path>` to write it somewhere else. `synthetic-package: true` is
not supported.

### 2. Implement the two data sources

```dart
/// Who may edit. Emit the editor, or null when nobody may edit.
class MyAccessDataSource implements L10nAccessDataSource {
  @override
  Stream<EditorUser?> watchEditor() => myAuth.userChanges().map(
    (user) => user != null && user.isTranslator
        ? EditorUser(id: user.id, displayName: user.email)
        : null,
  );
}

/// Where drafts and published messages live.
class MyTranslationDataSource implements L10nTranslationDataSource {
  @override
  Stream<MessagesByLanguage> watchDrafts() => ...;
  @override
  Stream<MessagesByLanguage> watchPublished() => ...;
  @override
  Future<void> saveDraft({...}) => ...;
  @override
  Future<void> importDrafts({...}) => ...;
  @override
  Future<void> publish({...}) => ...;
}
```

`MessagesByLanguage` is `languageCode -> key -> raw ICU message`. Throw
`L10nDataSourceException('readable message')` on failure, and the editor
shows that message. The rules each method must follow are in the API docs of
`L10nTranslationDataSource`.

To try the package without a backend, use `InMemoryL10nAccessDataSource` and
`InMemoryL10nTranslationDataSource`. For a complete backend, see
[Example: Firebase (Firestore)](#example-firebase-firestore).

### 3. Wrap `MaterialApp`

```dart
InContextEditor(
  delegate: const AppLocalizationsOverrideDelegate(),
  accessDataSource: MyAccessDataSource(),
  translationDataSource: MyTranslationDataSource(),
  onRequestAccess: (context) => openMyLogin(context), // optional
  onSignOut: mySignOut,                               // optional
  builder: (context, l10n) => MaterialApp(
    localizationsDelegates: [
      l10n.delegate, // was AppLocalizations.delegate
      ...GlobalMaterialLocalizations.delegates,
    ],
    builder: l10n.overlay,
    home: const HomePage(),
  ),
)
```

That is the only change to existing code. If you already use
`MaterialApp.builder`, nest yours:
`builder: (context, child) => l10n.overlay(context, myBuilder(context, child))`.

## Example: Firebase (Firestore)

Store each language in one document per collection, with message keys as
fields: `l10n_drafts/{lang}` and `l10n_published/{lang}`. gen-l10n keys are
Dart identifiers, so they are valid field names.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:l10n_in_context/l10n_in_context.dart';

/// Signed-in users with a `translator` custom claim may edit.
class FirebaseAccessDataSource implements L10nAccessDataSource {
  @override
  Stream<EditorUser?> watchEditor() =>
      FirebaseAuth.instance.idTokenChanges().asyncMap((user) async {
        if (user == null) return null;
        final token = await user.getIdTokenResult();
        if (token.claims?['translator'] != true) return null;
        return EditorUser(id: user.uid, displayName: user.email);
      });
}

class FirestoreTranslationDataSource implements L10nTranslationDataSource {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _drafts =>
      _db.collection('l10n_drafts');
  CollectionReference<Map<String, dynamic>> get _published =>
      _db.collection('l10n_published');

  @override
  Stream<MessagesByLanguage> watchDrafts() => _watch(_drafts);

  @override
  Stream<MessagesByLanguage> watchPublished() => _watch(_published);

  @override
  Future<void> saveDraft({
    required EditorUser editor,
    required String languageCode,
    required String key,
    required String value,
    String? previousValue,
  }) => _guard(
    () => _drafts.doc(languageCode).set({key: value}, SetOptions(merge: true)),
  );

  @override
  Future<void> importDrafts({
    required EditorUser editor,
    required MessagesByLanguage messages,
  }) => _guard(() {
    final batch = _db.batch();
    messages.forEach((lang, byKey) {
      batch.set(_drafts.doc(lang), byKey, SetOptions(merge: true));
    });
    return batch.commit();
  });

  @override
  Future<void> publish({
    required EditorUser editor,
    required MessagesByLanguage messages,
    required List<String> changedKeys,
  }) => _guard(() {
    final batch = _db.batch();
    // No merge: each language becomes exactly these messages.
    messages.forEach((lang, byKey) => batch.set(_published.doc(lang), byKey));
    batch.set(_db.collection('l10n_audit').doc(), {
      'editor': editor.id,
      'changedKeys': changedKeys,
      'at': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  });

  Stream<MessagesByLanguage> _watch(
    CollectionReference<Map<String, dynamic>> collection,
  ) => collection.snapshots().map(
    (snapshot) => {
      for (final doc in snapshot.docs)
        doc.id: doc.data().map((key, value) => MapEntry(key, '$value')),
    },
  );

  Future<void> _guard(Future<void> Function() write) async {
    try {
      await write();
    } on FirebaseException catch (e) {
      throw L10nDataSourceException(e.message ?? e.code, cause: e);
    }
  }
}
```

Enforce the same rule in `firestore.rules`:

```
match /l10n_published/{lang} {
  allow read: if true;
  allow write: if request.auth.token.translator == true;
}
match /{collection}/{doc} {
  allow read, write: if collection in ['l10n_drafts', 'l10n_audit']
    && request.auth.token.translator == true;
}
```

For over-the-air updates in every user's app, read `l10n_published` once at
startup (or listen to it) and pass the result to
`AppLocalizationsOverrideDelegate(messages: ...)`.

## Who may edit

The package never signs anyone in. It shows the editor tools while
`watchEditor()` emits a user.

| Who may edit | `watchEditor()` | `onRequestAccess` |
| --- | --- | --- |
| Everyone, e.g. a QA build | `Stream.value(EditorUser(id: deviceId))` | not set |
| Users who already have a role | your auth stream, filtered by role | not set |
| People who sign in separately | your auth stream | opens your sign-in UI |

When `onRequestAccess` is set, people without access see an Edit button that
calls it. For email and password, `showEmailPasswordSignInDialog` is ready
to use:

```dart
onRequestAccess: (context) => showEmailPasswordSignInDialog(
  context,
  signIn: (email, password) async {
    final error = await myAuth.signIn(email, password);
    return error; // null closes the dialog
  },
),
```

## Using it with over-the-air translations

Pass the published messages your app fetched to the delegate. They apply to
every user, with or without the editor:

```dart
AppLocalizationsOverrideDelegate(messages: {'hi': fetchedHindiMessages})
```

In edit mode the editor layers its drafts and published messages on top.

## Leaving the editor out of release builds

Guard the editor with a compile-time constant, so the compiler drops the
editor and your data sources from builds without it:

```dart
const editMode = bool.fromEnvironment('L10N_EDIT_MODE');

Widget build(BuildContext context) {
  const delegate = AppLocalizationsOverrideDelegate();
  if (!editMode) return buildApp(delegate, null);
  return InContextEditor(
    delegate: delegate,
    // ...
    builder: (context, l10n) => buildApp(l10n.delegate, l10n.overlay),
  );
}
```

`InContextEditor(enabled: false)` turns the editor off at runtime, but its
code still ships.

## Security

Hiding the editor UI is not security. Your backend must enforce the same rule
as `watchEditor()`:

- only editors may read or write drafts,
- only editors may publish,
- published messages can be public, because the same strings ship inside the
  app.

Every write receives the `EditorUser`, so the backend can check it and keep
an audit log.

## State management

The editor is built with `flutter_bloc`. `EditorSessionBloc`,
`TranslationsBloc` and `EditorToolsCubit` are provided below
`InContextEditor`, so your own widgets can read them, for example to show an
unpublished-changes count:

```dart
context.select<TranslationsBloc, int>((bloc) => bloc.state.unpublishedCount)
```

## Limitations

- Placeholders with a `format` (dates, currencies, compact numbers) and types
  other than `String`, `int`, `num`, `double` and `Object` always use the
  bundled string. The generator lists them, and the editor marks them.
- ICU support covers what gen-l10n accepts: `{arg}`, `plural` (`=N`, CLDR
  categories, `#`) and `select`.
- The editor UI is in English.
