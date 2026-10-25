/// Raw ICU messages: `languageCode -> key -> message`.
///
/// Language codes are the `@@locale` values of the ARB files, e.g. `en` or
/// `pt_BR`.
typedef MessagesByLanguage = Map<String, Map<String, String>>;
