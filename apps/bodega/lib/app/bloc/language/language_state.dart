part of 'language_bloc.dart';

@freezed
abstract class LanguageState with _$LanguageState {
  /// [code] null follows the system.
  const factory LanguageState({String? code}) = _LanguageState;
}
