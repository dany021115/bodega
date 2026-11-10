part of 'preferences_bloc.dart';

@freezed
sealed class PreferencesEvent with _$PreferencesEvent {
  const factory PreferencesEvent.load() = PreferencesLoadEvent;

  /// Empties the installer cache.
  const factory PreferencesEvent.clear() = PreferencesClearEvent;
}
