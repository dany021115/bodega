import 'package:bodega/domain/entities/native_move_step.dart';
import 'package:bodega/domain/entities/native_option.dart';
import 'package:bodega/domain/entities/retina_mode.dart';
import 'package:bodega/l10n/l10n.dart';

// The Native engine's retina modes and app options in the user's language
// (PA6). One case per code and no default: a code added to the domain fails
// the build here until it has its words.

/// An option of a Native engine bottle's retina dropdown.
String retinaModeText(AppL10n l10n, RetinaMode mode) => switch (mode) {
  RetinaMode.auto => l10n.retinaAuto,
  RetinaMode.on => l10n.retinaOn,
  RetinaMode.off => l10n.retinaOff,
};

/// The name of a switch of the Native engine options dialog.
String nativeOptionText(AppL10n l10n, NativeOption option) => switch (option) {
  NativeOption.noForceNx => l10n.nativeNoForceNx,
  NativeOption.largeAddressAware => l10n.nativeLargeAddressAware,
  NativeOption.notDpiAware => l10n.nativeNotDpiAware,
  NativeOption.cglOpenGl => l10n.nativeCglOpenGl,
  NativeOption.vulkanWined3d => l10n.nativeVulkanWined3d,
  NativeOption.strictCodeTracking => l10n.nativeStrictCodeTracking,
  NativeOption.fullX87Precision => l10n.nativeFullX87Precision,
};

/// The line under that switch: when to turn it on.
String nativeOptionHintText(AppL10n l10n, NativeOption option) =>
    switch (option) {
      NativeOption.noForceNx => l10n.nativeNoForceNxHint,
      NativeOption.largeAddressAware => l10n.nativeLargeAddressAwareHint,
      NativeOption.notDpiAware => l10n.nativeNotDpiAwareHint,
      NativeOption.cglOpenGl => l10n.nativeCglOpenGlHint,
      NativeOption.vulkanWined3d => l10n.nativeVulkanWined3dHint,
      NativeOption.strictCodeTracking => l10n.nativeStrictCodeTrackingHint,
      NativeOption.fullX87Precision => l10n.nativeFullX87PrecisionHint,
    };

/// What moving a bottle to the Native engine is doing (PA8).
String nativeMoveStepText(AppL10n l10n, NativeMoveStep step) => switch (step) {
  NativeMoveStep.creating => l10n.moveStepCreating,
  NativeMoveStep.copying => l10n.moveStepCopying,
  NativeMoveStep.finishing => l10n.moveStepFinishing,
};
