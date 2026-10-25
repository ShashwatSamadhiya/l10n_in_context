## 0.1.0

- First release.
- `InContextEditor`: pick a string on screen, edit it in every language with
  validation and a live preview, import bundled ARB text and publish.
- `L10nAccessDataSource` and `L10nTranslationDataSource` to connect any
  backend, plus in-memory implementations for tests and demos.
- `dart run l10n_in_context:generate`: generates the key catalog, the
  override localizations class and its delegate from the gen-l10n output.
- `showEmailPasswordSignInDialog`: optional ready-made sign-in dialog.
