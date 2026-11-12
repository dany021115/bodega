import 'package:file_selector/file_selector.dart';

// What the Switch page's pickers take (switch-support SA14, SA16). Each
// handler builds its group before its await. The groups carry no label: the
// Mac's picker shows none.

/// The uniform type of a Mac app bundle.
const appBundleType = 'com.apple.application-bundle';

/// Any app bundle, for the emulator's app: the engine tells whether it is
/// the emulator.
XTypeGroup emulatorAppTypes() =>
    const XTypeGroup(uniformTypeIdentifiers: [appBundleType]);

/// Game files of [extensions], and app bundles, so that a native game can be
/// picked: the engine refuses an app that is not one.
XTypeGroup gameFileTypes(List<String> extensions) => XTypeGroup(
  extensions: extensions,
  uniformTypeIdentifiers: const [appBundleType],
);

/// The user's own keys files, which Bodega copies where the emulator reads
/// them.
XTypeGroup keysFileTypes() => const XTypeGroup(extensions: ['keys']);

/// A firmware file the emulator's own installer takes.
XTypeGroup firmwareFileTypes() => const XTypeGroup(extensions: ['zip', 'xci']);
