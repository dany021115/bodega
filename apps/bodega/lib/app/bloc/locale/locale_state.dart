part of 'locale_bloc.dart';

@freezed
abstract class LocaleState with _$LocaleState {
  /// [code] is the chosen language, one the app speaks, or null (System):
  /// the system's ordered list decides.
  const factory LocaleState({String? code}) = _LocaleState;
}
