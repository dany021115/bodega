import 'package:freezed_annotation/freezed_annotation.dart';

part 'host_capabilities.freezed.dart';

/// What the host supports, so the UI only offers what works here.
@freezed
abstract class HostCapabilities with _$HostCapabilities {
  const factory HostCapabilities({
    @Default(true) bool highRes,
    @Default(true) bool avx,
    @Default(true) bool dlss,
    @Default(true) bool d3dmetal,
    @Default(true) bool sdl,
    @Default(false) bool gpu,
    @Default(false) bool gameMode,
    @Default(['msync', 'none']) List<String> syncModes,
  }) = _HostCapabilities;
}
