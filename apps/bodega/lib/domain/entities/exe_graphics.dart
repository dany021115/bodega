import 'package:freezed_annotation/freezed_annotation.dart';

part 'exe_graphics.freezed.dart';

/// What an exe draws with (G1), and the backends that don't suit it (G3).
@freezed
abstract class ExeGraphics with _$ExeGraphics {
  const ExeGraphics._();

  const factory ExeGraphics({
    required int bits,

    /// `DX12`, `DX11`, `DX10`, `DX9`, or empty when the exe names none.
    required String directx,
    @Default([]) List<String> misfits,
  }) = _ExeGraphics;

  /// `DX9 · 32 bits`, or `32 bits` (G2).
  String get label => directx.isEmpty ? '$bits bits' : '$directx · $bits bits';

  /// G4: why [backend] does not suit [title], or null if it does.
  String? warning(String title, String backend) => misfits.contains(backend)
      ? '$title es de $bits bits con DirectX ${directx.substring(2)}: '
            '$backend no le sirve. Usa Automático.'
      : null;
}
