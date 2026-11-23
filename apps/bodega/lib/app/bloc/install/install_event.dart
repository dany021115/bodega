part of 'install_bloc.dart';

@freezed
sealed class InstallEvent with _$InstallEvent {
  /// In [bottle], an existing one, or in its own; with [setup], a local
  /// installer instead of downloading it.
  const factory InstallEvent.start(
    CatalogApp app, {
    String? bottle,
    String? setup,

    /// The engine of a bottle of its own (PA3).
    @Default(RuntimeKind.bodega) RuntimeKind runtime,
  }) = InstallStartEvent;
  const factory InstallEvent.cancel() = InstallCancelEvent;
  const factory InstallEvent.dismiss() = InstallDismissEvent;
  const factory InstallEvent.removeBottle() = InstallRemoveBottleEvent;
}
