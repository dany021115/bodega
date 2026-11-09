import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PreferenceKey {
  darkTheme,
  collapsedSections,
  libraryViewGrid,
  updateCheckedAt,
  updateSkipped,
}

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

  DateTime? getUpdateCheckedAt() =>
      switch (_prefs.getInt(PreferenceKey.updateCheckedAt.name)) {
        final ms? => DateTime.fromMillisecondsSinceEpoch(ms),
        null => null,
      };

  Future<void> saveUpdateCheckedAt(DateTime value) => _prefs.setInt(
    PreferenceKey.updateCheckedAt.name,
    value.millisecondsSinceEpoch,
  );

  String? getUpdateSkipped() =>
      _prefs.getString(PreferenceKey.updateSkipped.name);

  Future<void> saveUpdateSkipped(String version) =>
      _prefs.setString(PreferenceKey.updateSkipped.name, version);
}
