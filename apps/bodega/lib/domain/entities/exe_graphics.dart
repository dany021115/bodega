import 'package:freezed_annotation/freezed_annotation.dart';

part 'exe_graphics.freezed.dart';

/// What an exe draws with (G1), and the backends that don't suit it (G3).
/// `app/` words its label and the warning for a misfit (G2, G4).
@freezed
abstract class ExeGraphics with _$ExeGraphics {
  const factory ExeGraphics({
    required int bits,

    /// `DX12`, `DX11`, `DX10`, `DX9`, or empty when the exe names none.
    required String directx,
    @Default([]) List<String> misfits,
  }) = _ExeGraphics;
}
