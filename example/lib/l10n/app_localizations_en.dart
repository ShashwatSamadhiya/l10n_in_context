// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pond diary';

  @override
  String greeting(String name) {
    return 'Good morning, $name';
  }

  @override
  String pondCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ponds',
      one: '1 pond',
      zero: 'No ponds yet',
    );
    return '$_temp0';
  }

  @override
  String get addPond => 'Add pond';

  @override
  String get canEditLabel => 'Everyone can edit';
}
