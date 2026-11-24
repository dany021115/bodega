import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/retina_mode.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bottle_detail.freezed.dart';

@freezed
abstract class ProgramBackend with _$ProgramBackend {
  const factory ProgramBackend({required String exe, required String backend}) =
      _ProgramBackend;
}

@freezed
abstract class BottleLogEntry with _$BottleLogEntry {
  const factory BottleLogEntry({
    required String path,
    required String name,
    required DateTime modified,
    int? exitCode,
  }) = _BottleLogEntry;
}

@freezed
abstract class BottleDetail with _$BottleDetail {
  const factory BottleDetail({
    required String name,
    required bool ready,
    required String backend,
    required String sync,
    @Default(false) bool highRes,

    /// A Native engine bottle's retina mode (PA1); Rosetta's is [highRes].
    @Default(RetinaMode.auto) RetinaMode retina,

    /// The Native engine is installed, so a Rosetta bottle can move to it
    /// (PA8).
    @Default(false) bool nativeInstalled,
    @Default(false) bool dlss,

    /// D3DMetal's Metal 4 path for a Rosetta bottle (ER8).
    @Default(false) bool metal4,
    @Default(true) bool avx,

    /// DXVK compiles shaders in the background (RE8).
    @Default(false) bool dxvkAsync,
    @Default('auto') String gpu,
    @Default(false) bool gamemode,
    @Default('win10') String windows,

    /// The Windows user its games see; empty for [macUser] (U1).
    @Default('') String user,

    /// The host's user name, which Wine takes when [user] is empty.
    @Default('') String macUser,

    /// Where `C:` is, to show it in the file manager.
    @Default('') String driveC,
    @Default([]) List<LibraryApp> apps,
    @Default([]) List<ProgramBackend> exceptions,
    @Default([]) List<BottleLogEntry> logs,
    @Default([]) List<String> installedBackends,

    /// The Wine it runs on: its prefix's (D2).
    @Default(RuntimeKind.bodega) RuntimeKind runtime,

    /// A native bottle without Wine Mono (MB7).
    @Default(false) bool monoMissing,
  }) = _BottleDetail;
}
