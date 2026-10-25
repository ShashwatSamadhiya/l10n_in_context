# l10n_in_context example

A small app with English and Hindi strings that runs the in-context editor on
in-memory data sources, so it needs no backend.

```bash
flutter pub get
flutter gen-l10n
dart run l10n_in_context:generate
flutter run -d chrome
```

Tap the edit button and sign in with any email and the password `demo`, or
turn on **Everyone can edit**. Then pick a text on screen, change it, and see
the draft live. Nothing is stored.
