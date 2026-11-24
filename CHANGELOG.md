## 0.2.1

- Pick mode stays on after editing a picked text, so the next text can be
  picked straight away. Tap **Pick a text** again to leave it.
- The highlight outlines and the editor toolbar no longer show on top of
  dialogs: text covered by a dialog isn't outlined, and the toolbar is
  hidden while the dialogs opened by picking a text are showing.

## 0.2.0

- **Export to ARB**: the key table's **Export ARB…** copies the published or
  draft messages that differ from the bundled ARB, for every language at
  once or for one. `dart run l10n_in_context:merge <file>` writes them into
  the project's ARB files, changing only those messages. `ArbExport` does
  the same from code.
- **Discard drafts**: discard a key's unpublished drafts from the edit
  dialog, or every unpublished draft from the key table.
- **Breaking**: `L10nTranslationDataSource` has a new method,
  `discardDrafts({editor, keys})`, which deletes the given drafts
  (`languageCode -> keys`). Custom data sources must implement it; see the
  README for a Firestore version. `TranslationsOperation` has a new
  `discard` value.

## 0.1.2

- Shorten the package description to pub.dev's 180-character limit.

## 0.1.1

- Docs: a complete Firebase (Firestore) data source example with security
  rules, a list of supported platforms, and a clearer package description.

## 0.1.0

- First release.
- `InContextEditor`: pick a string on screen, edit it in every language with
  validation and a live preview, import bundled ARB text and publish.
- `L10nAccessDataSource` and `L10nTranslationDataSource` to connect any
  backend, plus in-memory implementations for tests and demos.
- `dart run l10n_in_context:generate`: generates the key catalog, the
  override localizations class and its delegate from the gen-l10n output.
- `showEmailPasswordSignInDialog`: optional ready-made sign-in dialog.
