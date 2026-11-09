import 'package:bodega/domain/entities/library_app.dart';
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
    @Default(false) bool dlss,
    @Default(true) bool avx,
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
  }) = _BottleDetail;
}
