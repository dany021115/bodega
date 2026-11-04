part of 'setup_bloc.dart';

@freezed
sealed class SetupEvent with _$SetupEvent {
  const factory SetupEvent.check() = SetupCheckEvent;
  const factory SetupEvent.engineChosen(String path) = SetupEngineChosenEvent;
  const factory SetupEvent.hostlibsChosen(String path) =
      SetupHostlibsChosenEvent;
  const factory SetupEvent.install() = SetupInstallEvent;
}
