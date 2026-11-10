import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_error.freezed.dart';

/// Lives in domain, not in data as in TeeShot, so that repository interfaces
/// don't import the data layer. It holds values, never a sentence: the app
/// turns it into words (`app/shared/error_text.dart`).
@freezed
sealed class AppError with _$AppError {
  /// The engine's English text, shown as is.
  const factory AppError.engine(String message) = EngineError;

  /// What the network layer said went wrong.
  const factory AppError.network(String detail) = NetworkError;

  const factory AppError.unknown(String message) = UnknownError;

  /// An install into a new [bottle] that already exists.
  const factory AppError.bottleExists(String bottle) = BottleExistsError;

  /// The file at [path] isn't there.
  const factory AppError.fileMissing(String path) = FileMissingError;

  /// A backend Bodega has no installer for.
  const factory AppError.backendNotPinned(String backend) =
      BackendNotPinnedError;

  /// This build can't update itself.
  const factory AppError.updateUnsupported() = UpdateUnsupportedError;

  /// The release has no SHA256 for [file].
  const factory AppError.updateNoChecksum(String file) = UpdateNoChecksumError;

  /// The download of [file] doesn't match its SHA256.
  const factory AppError.updateChecksumMismatch(String file) =
      UpdateChecksumMismatchError;

  /// The running app isn't inside a `.app` bundle at [path].
  const factory AppError.updateNotInBundle(String path) =
      UpdateNotInBundleError;

  /// The app can't write to [dir], where it lives.
  const factory AppError.updateNotWritable(String dir) = UpdateNotWritableError;

  /// The downloaded dmg has no `Bodega.app`.
  const factory AppError.updateNoApp() = UpdateNoAppError;

  /// [exe] exited with [code].
  const factory AppError.processFailed(String exe, int code, String stderr) =
      ProcessFailedError;

  /// The download stopped at [received] of [total] bytes.
  const factory AppError.downloadCut(int received, int total) =
      DownloadCutError;

  /// A download, or where it redirected, isn't HTTPS.
  const factory AppError.downloadNotHttps(String url) = DownloadNotHttpsError;
}
