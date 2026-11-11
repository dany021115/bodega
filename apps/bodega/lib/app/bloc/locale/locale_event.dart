part of 'locale_bloc.dart';

@freezed
sealed class LocaleEvent with _$LocaleEvent {
  /// [code] is a language code, or null to follow the system's language.
  const factory LocaleEvent.set(String? code) = LocaleSetEvent;
}
