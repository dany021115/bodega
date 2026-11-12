import 'package:bodega/app/shared/text/problem_text.dart';
import 'package:bodega/app/shared/text/progress_text.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/user_name_problem.dart';
import 'package:bodega/domain/entities/wine_tool.dart';
import 'package:bodega/l10n/l10n.dart';

/// An [AppError] in the user's language: the one place that words a failure
/// (design §6). Where the engine's message gives a command, this says what to
/// do in Bodega instead (L8). `detail` is never worded: it is for copying.
///
/// One case per code and no default, so a code added to [AppError] fails the
/// build here until it has its words.
extension AppErrorText on AppError {
  String localized(AppL10n l10n) => switch (this) {
    BottleNotFoundError(:final bottle) => l10n.errBottleNotFound(bottle),
    BottleExistsError(:final bottle) => l10n.errBottleExists(bottle),
    BottleNotReadyError(:final bottle) => l10n.errBottleNotReady(bottle),
    BottleOpenError(:final bottle) => l10n.errBottleOpen(bottle),
    BottleSetupFailedError(:final log, timedOut: true) =>
      l10n.errBottleSetupTimedOut(log),
    BottleSetupFailedError(:final log, timedOut: false) =>
      l10n.errBottleSetupFailed(log),
    BadBottleNameError(:final name) => l10n.errBadBottleName(
      name,
      l10n.bottleNameRule,
    ),
    BadUserNameError(:final user, problem: UserNameProblem.taken) =>
      l10n.errUserNameTaken(user),
    BadUserNameError(:final user, :final problem) => l10n.errBadUserName(
      user,
      userNameProblemText(l10n, problem),
    ),
    BadPathError(:final problem) => pathProblemText(l10n, problem),
    AppNotFoundError(:final bottle, key: null) => l10n.errNoApps(bottle),
    AppNotFoundError(:final bottle, :final key?) => l10n.errAppNotFound(
      bottle,
      key,
    ),
    AppAlreadyAddedError(:final bottle) => l10n.errAppAlreadyAdded(bottle),
    BadEnvLineError(:final line, :final text) => l10n.errBadEnvLine(line, text),
    NoRuntimeError() => l10n.errNoRuntime,
    AlreadyInstalledError(:final path) => l10n.errAlreadyInstalled(path),
    ChecksumMismatchError(:final file) => l10n.errChecksumMismatch(file),
    IncompleteArchiveError(:final archive, :final missing) =>
      l10n.errIncompleteArchive(archive, missing),
    CorruptDataError(:final source) => l10n.errCorruptData(source),
    BackendNotInstalledError(:final backend) => l10n.errBackendNotInstalled(
      backend,
      l10n.navBackends,
    ),
    NoD3DMetalError(:final source, :final missing) => l10n.errNoD3DMetal(
      source,
      missing,
    ),
    CrossOverCopyError() => l10n.errCrossOverCopy,
    MountFailedError(:final image) => l10n.errMountFailed(image),
    LicenseNotAcceptedError() => l10n.errLicenseNotAccepted,
    CancelledError() => l10n.errCancelled,
    WineToolFailedError(:final tool, :final exitCode, :final log) =>
      switch (tool) {
        WineTool.wineboot => l10n.errWinebootFailed(exitCode, log),
        WineTool.reg => l10n.errRegFailed(exitCode, log),
        WineTool.installer => l10n.errInstallerFailed(exitCode, log),
        WineTool.winecfg => l10n.errWinecfgFailed(exitCode, log),
      },
    InstallerNoExeError(:final exe, :final log) => l10n.errInstallerNoExe(
      exe,
      log,
    ),
    ProcessFailedError(:final command, exitCode: null) =>
      l10n.errProcessNoAnswer(command),
    ProcessFailedError(:final command, :final exitCode?) =>
      l10n.errProcessFailed(command, exitCode),
    NoEmulatorError(:final name, :final app) => l10n.errNoEmulator(name, app),
    NotAnEmulatorError(:final path, :final name) => l10n.errNotAnEmulator(
      path,
      name,
    ),
    NotASwitchGameError(:final path) => l10n.errNotASwitchGame(path),
    SwitchGameNotFoundError(:final path) => l10n.errSwitchGameNotFound(path),
    SwitchGameRunningError(:final path) => l10n.errSwitchGameRunning(path),
    NoSwitchKeysError(:final source) => l10n.errNoSwitchKeys(source),
    DownloadCutError(:final received, :final total) => l10n.errDownloadCut(
      megabytes(received),
      megabytes(total),
    ),
    UpdateNotInstallableError() => l10n.errUpdateNotInstallable,
    UpdateNoChecksumError(:final file) => l10n.errUpdateNoChecksum(file),
    UpdateNotWritableError(:final folder) => l10n.errUpdateNotWritable(folder),
    NetworkError() => l10n.errNetwork,
    UnknownError() => l10n.errUnknown,
  };
}
