part of 'backends_bloc.dart';

@freezed
sealed class BackendsEvent with _$BackendsEvent {
  const factory BackendsEvent.load() = BackendsLoadEvent;
  const factory BackendsEvent.download(String name) = BackendsDownloadEvent;
  const factory BackendsEvent.cancel() = BackendsCancelEvent;
  const factory BackendsEvent.installFile(String name, String tarball) =
      BackendsInstallFileEvent;
  const factory BackendsEvent.importD3DMetal(String folder) =
      BackendsImportEvent;
  const factory BackendsEvent.check(String bottle, String backend) =
      BackendsCheckEvent;
}
