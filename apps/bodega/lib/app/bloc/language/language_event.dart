part of 'language_bloc.dart';

@freezed
sealed class LanguageEvent with _$LanguageEvent {
  /// Null goes back to the system's language.
  const factory LanguageEvent.set(String? code) = SetLanguageEvent;
}
