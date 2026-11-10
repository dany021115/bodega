import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/l10n/app_localizations.dart';

/// An [AppError] in the user's language. An engine error is the engine's
/// English, shown as is.
extension AppErrorText on AppError {
  String text(AppLocalizations l10n) => switch (this) {
    EngineError(:final message) => message,
    NetworkError(:final detail) => l10n.errorNetwork(detail),
    UnknownError(:final message) => message,
    BottleExistsError(:final bottle) => l10n.errorBottleExists(bottle),
    FileMissingError(:final path) => l10n.errorFileMissing(path),
    BackendNotPinnedError(:final backend) => l10n.errorBackendNotPinned(
      backend,
    ),
    UpdateUnsupportedError() => l10n.errorUpdateUnsupported,
    UpdateNoChecksumError(:final file) => l10n.errorUpdateNoChecksum(file),
    UpdateChecksumMismatchError(:final file) =>
      l10n.errorUpdateChecksumMismatch(file),
    UpdateNotInBundleError(:final path) => l10n.errorUpdateNotInBundle(path),
    UpdateNotWritableError(:final dir) => l10n.errorUpdateNotWritable(dir),
    UpdateNoAppError() => l10n.errorUpdateNoApp,
    // Trimmed whole, so an empty stderr leaves no trailing colon space.
    ProcessFailedError(:final exe, :final code, :final stderr) =>
      l10n.errorProcessFailed(exe, code, stderr).trim(),
    DownloadCutError(:final received, :final total) => l10n.errorDownloadCut(
      received,
      total,
    ),
    DownloadNotHttpsError(:final url) => l10n.errorDownloadNotHttps(url),
  };
}
