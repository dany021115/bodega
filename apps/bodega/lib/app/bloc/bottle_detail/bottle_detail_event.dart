part of 'bottle_detail_bloc.dart';

@freezed
sealed class BottleDetailEvent with _$BottleDetailEvent {
  const factory BottleDetailEvent.load(String name) = BottleDetailLoadEvent;
  const factory BottleDetailEvent.setBackend(String backend) =
      BottleDetailSetBackendEvent;
  const factory BottleDetailEvent.setSync(String sync) =
      BottleDetailSetSyncEvent;
  const factory BottleDetailEvent.removeException(String exe) =
      BottleDetailRemoveExceptionEvent;
  const factory BottleDetailEvent.delete() = BottleDetailDeleteEvent;
  const factory BottleDetailEvent.openLog(String path) =
      BottleDetailOpenLogEvent;
}
