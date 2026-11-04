part of 'install_bloc.dart';

@freezed
sealed class InstallEvent with _$InstallEvent {
  const factory InstallEvent.start(CatalogApp app) = InstallStartEvent;
  const factory InstallEvent.cancel() = InstallCancelEvent;
  const factory InstallEvent.dismiss() = InstallDismissEvent;
  const factory InstallEvent.removeBottle() = InstallRemoveBottleEvent;
}
