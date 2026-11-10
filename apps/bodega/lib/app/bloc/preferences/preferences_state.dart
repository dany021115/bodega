part of 'preferences_bloc.dart';

@freezed
abstract class PreferencesState with _$PreferencesState {
  const factory PreferencesState({
    @Default('') String dataFolder,

    /// The installer cache's size; null until it is measured.
    int? cacheBytes,
    @Default(false) bool isClearing,
    AppError? error,
  }) = _PreferencesState;
}
