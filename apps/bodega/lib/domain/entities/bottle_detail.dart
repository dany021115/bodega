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
    required String backend,
    required String sync,
    @Default([]) List<ProgramBackend> exceptions,
    @Default([]) List<BottleLogEntry> logs,
    @Default([]) List<String> installedBackends,
  }) = _BottleDetail;
}
