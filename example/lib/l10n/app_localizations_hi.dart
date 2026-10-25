// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'तालाब डायरी';

  @override
  String greeting(String name) {
    return 'सुप्रभात, $name';
  }

  @override
  String pondCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count तालाब',
      one: '1 तालाब',
      zero: 'अभी कोई तालाब नहीं',
    );
    return '$_temp0';
  }

  @override
  String get addPond => 'तालाब जोड़ें';

  @override
  String get canEditLabel => 'सभी संपादित कर सकते हैं';
}
