import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext
{
  /// Translated strings for the current locale. Outside a localized app
  /// (e.g. a bare MaterialApp in a test) falls back to [AppL10n.current].
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? AppL10n.current;
}

/// Strings for code that has no [BuildContext] (validators, error mapping,
/// models). Kept in sync with the app's locale by `main.dart`; defaults to
/// Romanian, e.g. in plain unit tests.
abstract final class AppL10n
{
  static AppLocalizations? _current;

  static AppLocalizations get current => _current ?? lookupAppLocalizations(const Locale('ro'));

  static void update(AppLocalizations strings) => _current = strings;

  /// Supported phone language, otherwise English.
  static Locale resolve(Locale? device, Iterable<Locale> supported)
  {
    for(final locale in supported)
    {
      if(locale.languageCode == device?.languageCode) return locale;
    }
    return const Locale('en');
  }
}
