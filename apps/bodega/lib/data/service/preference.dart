import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PreferenceKey { darkTheme, collapsedSections, libraryViewGrid }

@lazySingleton
class Preferences {
  final SharedPreferences _prefs;

  Preferences(this._prefs);

  bool? getDarkTheme() => _prefs.getBool(PreferenceKey.darkTheme.name);

  Future<void> saveDarkTheme(bool value) =>
      _prefs.setBool(PreferenceKey.darkTheme.name, value);

  bool? getLibraryViewGrid() =>
      _prefs.getBool(PreferenceKey.libraryViewGrid.name);

  Future<void> saveLibraryViewGrid(bool value) =>
      _prefs.setBool(PreferenceKey.libraryViewGrid.name, value);

  List<String> getCollapsedSections() =>
      _prefs.getStringList(PreferenceKey.collapsedSections.name) ?? const [];

  Future<void> saveCollapsedSections(List<String> value) =>
      _prefs.setStringList(PreferenceKey.collapsedSections.name, value);
}
