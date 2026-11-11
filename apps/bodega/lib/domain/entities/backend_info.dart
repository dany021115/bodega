import 'package:bodega/domain/entities/backend_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backend_info.freezed.dart';

@freezed
abstract class BackendInfo with _$BackendInfo {
  const factory BackendInfo({
    required String name,
    required bool installed,

    /// Has a pinned tarball to download.
    required bool downloadable,

    /// What it is for (G3). Without it, its card does not say.
    BackendRole? role,

    /// The version installed, where Bodega can tell (D3DMetal's, I1).
    String? version,
  }) = _BackendInfo;
}

/// A Game Porting Toolkit version that brings D3DMetal (I1).
@freezed
abstract class GptkRelease with _$GptkRelease {
  const factory GptkRelease({
    required String version,

    /// Checked with Bodega.
    required bool tested,

    /// Where Apple serves it, behind an Apple ID.
    required String url,
  }) = _GptkRelease;
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
