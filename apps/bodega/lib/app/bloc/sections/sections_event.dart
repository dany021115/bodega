part of 'sections_bloc.dart';

@freezed
sealed class SectionsEvent with _$SectionsEvent {
  const factory SectionsEvent.toggle(String id) = SectionsToggleEvent;
}
