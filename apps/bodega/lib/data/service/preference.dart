import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PreferenceKey { darkTheme }

@lazySingleton
class Preferences {
  final SharedPreferences _prefs;

  Preferences(this._prefs);

  bool? getDarkTheme() => _prefs.getBool(PreferenceKey.darkTheme.name);

  Future<void> saveDarkTheme(bool value) =>
      _prefs.setBool(PreferenceKey.darkTheme.name, value);
}
