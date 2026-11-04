import 'package:freezed_annotation/freezed_annotation.dart';

part 'backend_info.freezed.dart';

@freezed
abstract class BackendInfo with _$BackendInfo {
  const factory BackendInfo({
    required String name,
    required bool installed,

    /// Has a pinned tarball to download.
    required bool downloadable,
  }) = _BackendInfo;
}

@freezed
abstract class ProbeResult with _$ProbeResult {
  const factory ProbeResult({
    required int bits,
    required String d3d,
    required bool ok,
    required String log,
  }) = _ProbeResult;
}
