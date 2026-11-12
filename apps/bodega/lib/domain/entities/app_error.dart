import 'package:bodega/domain/entities/path_problem.dart';
import 'package:bodega/domain/entities/user_name_problem.dart';
import 'package:bodega/domain/entities/wine_tool.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_error.freezed.dart';

/// What went wrong, as a code that `app/` words in the user's language
/// (`app/shared/text/error_text.dart`). A code holds what its text names; most
/// follow the engine failure of the same name (design §5).
///
/// [detail] is the raw text behind the code: the engine's English message, a
/// tool's stderr or Dio's text. It is set in `data/`, for copying only: never
/// worded, never shown (E13).
///
/// Lives in domain, not in data as in TeeShot, so that repository interfaces
/// don't import the data layer. A sealed union, so that wording it is one
/// exhaustive switch, and an [Exception], because `data/` throws it.
@freezed
sealed class AppError with _$AppError implements Exception {
  // Bottles.
  const factory AppError.bottleNotFound(String bottle, {String? detail}) =
      BottleNotFoundError;
  const factory AppError.bottleExists(String bottle, {String? detail}) =
      BottleExistsError;

  /// The bottle has no prefix ready to run.
  const factory AppError.bottleNotReady(String bottle, {String? detail}) =
      BottleNotReadyError;

  /// The bottle runs, and what was asked needs it stopped.
  const factory AppError.bottleOpen(String bottle, {String? detail}) =
      BottleOpenError;

  /// wineboot ended, but the bottle did not come out ready: [timedOut] when
  /// `wineserver -w` ran past its 10 minutes and the bottle was stopped,
  /// otherwise the prefix lacks a file it must hold. [log] is wineboot's.
  const factory AppError.bottleSetupFailed(
    String log,
    bool timedOut, {
    String? detail,
  }) = BottleSetupFailedError;
  const factory AppError.badBottleName(String name, {String? detail}) =
      BadBottleNameError;
  const factory AppError.badUserName(
    String user,
    UserNameProblem problem, {
    String? detail,
  }) = BadUserNameError;

  /// A path that cannot be used: nothing is there, or Windows refuses it.
  const factory AppError.badPath(PathProblem problem, {String? detail}) =
      BadPathError;

  // Apps.

  /// [key] is the app asked for; null when the bottle has none to open.
  const factory AppError.appNotFound(
    String bottle,
    String? key, {
    String? detail,
  }) = AppNotFoundError;
  const factory AppError.appAlreadyAdded(String bottle, {String? detail}) =
      AppAlreadyAddedError;

  /// Line [line], from 1, of the run options' variables is [text], which is
  /// not `NAME=value`.
  const factory AppError.badEnvLine(int line, String text, {String? detail}) =
      BadEnvLineError;

  // The runtime, backends and D3DMetal.
  const factory AppError.noRuntime({String? detail}) = NoRuntimeError;

  /// A runtime or a backend is already at [path].
  const factory AppError.alreadyInstalled(String path, {String? detail}) =
      AlreadyInstalledError;
  const factory AppError.checksumMismatch(String file, {String? detail}) =
      ChecksumMismatchError;

  /// [archive] lacks [missing], a file it must hold.
  const factory AppError.incompleteArchive(
    String archive,
    String missing, {
    String? detail,
  }) = IncompleteArchiveError;

  /// A file of the engine's that it cannot read: [source]. Why is in
  /// [detail].
  const factory AppError.corruptData(String source, {String? detail}) =
      CorruptDataError;
  const factory AppError.backendNotInstalled(String backend, {String? detail}) =
      BackendNotInstalledError;

  /// No D3DMetal at [source], a dmg or a folder: it lacks [missing].
  const factory AppError.noD3DMetal(
    String source,
    String missing, {
    String? detail,
  }) = NoD3DMetalError;

  /// A D3DMetal import from inside CrossOver.app.
  const factory AppError.crossOverCopy({String? detail}) = CrossOverCopyError;

  /// hdiutil could not open [image]; what it said is in [detail].
  const factory AppError.mountFailed(String image, {String? detail}) =
      MountFailedError;
  const factory AppError.licenseNotAccepted({String? detail}) =
      LicenseNotAcceptedError;

  /// The user cancelled the D3DMetal import.
  const factory AppError.cancelled({String? detail}) = CancelledError;

  // Programs.

  /// A Wine program run in a bottle exited with [exitCode]; [log] is its log.
  const factory AppError.wineToolFailed(
    WineTool tool,
    int exitCode,
    String log, {
    String? detail,
  }) = WineToolFailedError;

  /// The installer ended well, but [exe], which it should leave, is not there.
  const factory AppError.installerNoExe(
    String exe,
    String log, {
    String? detail,
  }) = InstallerNoExeError;

  /// A host program failed: [exitCode] is null when it ran but did not answer
  /// as expected. What it printed is in [detail].
  const factory AppError.processFailed(
    String command,
    int? exitCode, {
    String? detail,
  }) = ProcessFailedError;

  // Switch games.

  /// No [name] where Bodega looks for [app], its file name, and no pick that
  /// is one.
  const factory AppError.noEmulator(String name, String app, {String? detail}) =
      NoEmulatorError;

  /// [path], picked as the emulator [name], is another app.
  const factory AppError.notAnEmulator(
    String path,
    String name, {
    String? detail,
  }) = NotAnEmulatorError;

  /// [path] is neither a game file the emulator opens nor an nxnative app.
  /// The extensions it opens are in [detail].
  const factory AppError.notASwitchGame(String path, {String? detail}) =
      NotASwitchGameError;

  /// [path] is not in the list of Switch games, and has no run.
  const factory AppError.switchGameNotFound(String path, {String? detail}) =
      SwitchGameNotFoundError;

  /// [path] already runs.
  const factory AppError.switchGameRunning(String path, {String? detail}) =
      SwitchGameRunningError;

  // Downloads and updates.

  /// The server stopped sending at [received] of [total] bytes. The next try
  /// goes on from there.
  const factory AppError.downloadCut(
    int received,
    int total, {
    String? detail,
  }) = DownloadCutError;

  /// This release has nothing this copy of Bodega can install by itself.
  const factory AppError.updateNotInstallable({String? detail}) =
      UpdateNotInstallableError;

  /// The release lists no SHA-256 for [file], so it is not installed.
  const factory AppError.updateNoChecksum(String file, {String? detail}) =
      UpdateNoChecksumError;

  /// The new version cannot be put in [folder], where Bodega is.
  const factory AppError.updateNotWritable(String folder, {String? detail}) =
      UpdateNotWritableError;
  const factory AppError.network({String? detail}) = NetworkError;
  const factory AppError.unknown({String? detail}) = UnknownError;
}
