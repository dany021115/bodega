import 'package:bodega/domain/entities/backend_role.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/l10n/l10n.dart';

/// What [backend] is, under its name on its card. Null for a backend this
/// table does not know: its card already shows the name, so it shows no
/// description rather than the name twice.
String? backendDescriptionText(AppL10n l10n, String backend) =>
    switch (backend) {
      'wine' => l10n.backendDescriptionWine,
      'dxmt' => l10n.backendDescriptionDxmt,
      'dxvk' => l10n.backendDescriptionDxvk,
      'd3dmetal' => l10n.backendDescriptionD3dMetal,
      _ => null,
    };

/// What a backend is for, on its card after "Used for" (G3). One case per
/// role and no default, so a role added to [BackendRole] fails the build here
/// until it has its words.
String backendRoleText(AppL10n l10n, BackendRole role) => switch (role) {
  BackendRole.dx11to12x64 => l10n.backendRoleDx11to12x64,
  BackendRole.dx10to11 => l10n.backendRoleDx10to11,
  BackendRole.everythingElse => l10n.backendRoleEverythingElse,
  BackendRole.dx8to12 => l10n.backendRoleDx8to12,
  BackendRole.everythingSlower => l10n.backendRoleEverythingSlower,
};

/// What an exe draws with (G2): `DX9 · 32 bits`, or `32 bits` when it names
/// no DirectX.
String graphicsLabelText(AppL10n l10n, ExeGraphics graphics) =>
    graphics.directx.isEmpty
    ? l10n.graphicsBits(graphics.bits)
    : l10n.graphicsLabel(graphics.directx, graphics.bits);

/// G4: why [backend] does not suit [program], an exe that draws with
/// [graphics], or null if it does. It points to the Automatic option by that
/// option's own text.
String? graphicsMisfitText(
  AppL10n l10n,
  ExeGraphics graphics, {
  required String program,
  required String backend,
}) => graphics.misfits.contains(backend)
    ? l10n.graphicsMisfitWarning(
        program,
        graphics.bits,
        graphics.directx.replaceFirst('DX', ''),
        backend,
        l10n.bottleGraphicsAuto,
      )
    : null;
