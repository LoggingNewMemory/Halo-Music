// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Halo Music';

  @override
  String get sort => 'Sort';

  @override
  String get refresh => 'Refresh';

  @override
  String get search => 'Search';

  @override
  String get songs => 'Songs';

  @override
  String get unknownTitle => 'Unknown Title';

  @override
  String get unknownArtist => 'Unknown Artist';

  @override
  String get upNext => 'Up Next';

  @override
  String get settings => 'Settings';

  @override
  String get general => 'General';

  @override
  String get theme => 'Theme';

  @override
  String get about => 'About';

  @override
  String get permissionDenied =>
      'Storage permission is required to list music.';

  @override
  String get noSongsFound => 'No songs found';
}
