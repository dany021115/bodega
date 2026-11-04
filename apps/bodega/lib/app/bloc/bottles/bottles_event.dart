part of 'bottles_bloc.dart';

@freezed
sealed class BottlesEvent with _$BottlesEvent {
  const factory BottlesEvent.load() = BottlesLoadEvent;
}
