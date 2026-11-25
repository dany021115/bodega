import 'package:bodega/domain/entities/runtime_block.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'runtime_info.freezed.dart';

/// One runtime kind on this host (MR3): the engine's `RuntimeInfo` plus the
/// pinned release's numbers the engine card shows.
@freezed
abstract class RuntimeInfo with _$RuntimeInfo {
  const RuntimeInfo._();

  const factory RuntimeInfo({
    required RuntimeKind kind,
    required bool installed,

    /// The installed version; null when not installed or not known.
    String? version,

    /// Bodega's graphics check passed on this version when it was installed
    /// (MU4).
    @Default(true) bool checked,

    /// Why this host cannot run it; null when it can.
    RuntimeBlock? blocked,

    /// A Mach9.app found in Applications, and its version.
    String? appPath,
    String? appVersion,

    /// Mach9's latest release as Bodega last looked it up (MU5), and the
    /// sizes of its download and of its copy on disk, in bytes; null or 0
    /// when not known.
    String? latestVersion,

    /// The graphics names a bottle of this kind can choose, besides auto,
    /// once it is installed: `wine`, `dxmt` and `mtld3d` for mach9 (MG1).
    @Default([]) List<String> backends,
    @Default(0) int downloadBytes,
    @Default(0) int diskBytes,

    /// The oldest macOS it runs on, for a Mac that is too old.
    String? minimumMacos,
  }) = _RuntimeInfo;

  /// Usable: installed and not blocked.
  bool get usable => installed && blocked == null;

  /// The found app is the latest release or newer, or the latest is not
  /// known: installing copies it.
  bool get appIsLatest =>
      appPath != null &&
      (latestVersion == null ||
          compareVersions(appVersion ?? '0', latestVersion!) >= 0);

  /// Installed, at an older version than the latest release.
  bool get updateAvailable {
    final installed = version;
    final latest = latestVersion;
    if (!this.installed || installed == null || latest == null) return false;
    return compareVersions(installed, latest) < 0;
  }

  /// Compares dotted versions number by number.
  static int compareVersions(String a, String b) {
    final x = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final y = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    for (var i = 0; i < x.length || i < y.length; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d.sign;
    }
    return 0;
  }
}
