import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_update.freezed.dart';

/// A newer release than the one running (A1, A2).
@freezed
abstract class AppUpdate with _$AppUpdate {
  const AppUpdate._();

  const factory AppUpdate({
    required String version,
    required String current,
    @Default('') String notes,

    /// The release on GitHub.
    required String page,

    /// The installer for this machine and its checksums, or null when the app
    /// cannot install it (a Linux package, or a release without them).
    String? installer,
    String? sums,

    /// How to update by hand, for Linux packages.
    @Default('') String command,
  }) = _AppUpdate;

  bool get installable => installer != null && sums != null;
}
