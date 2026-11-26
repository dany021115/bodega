import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/native_option.dart';
import 'package:engine/engine.dart' hide NativeOption;

/// The engine's applications with their pictures. It reads executables, so it
/// runs inside `Isolate.run`: some games have huge ones (design §3).
List<LibraryApp> libraryApps(String home, List<InstalledApp> apps) {
  final native = <String, bool>{};
  bool nativeEngine(String bottle) =>
      native[bottle] ??= bottleRuntime(home, bottle) == RuntimeKind.mach9;
  // AA1: an ARM64 Windows program runs only on the Native engine, and the
  // list says so before a launch fails.
  final arm64 = <String, Set<String>>{};
  Set<String> arm64In(String bottle) =>
      arm64[bottle] ??= _arm64OrNone(home, bottle);
  return [
    for (final app in apps)
      LibraryApp(
        bottle: app.bottle,
        key: app.key,
        id: app.id,
        title: app.title,
        exe: app.exe.startsWith('/')
            ? app.exe
            : 'C:\\${app.exe.replaceAll('/', r'\')}',
        args: app.args,
        iconPath: appIcon(home, app),
        inLibrary: app.inLibrary,
        hud: app.hud,
        nativeEngine: nativeEngine(app.bottle),
        outsideBottle: app.exe.startsWith('/') && !app.exe.startsWith('$home/'),
        arm64: arm64In(app.bottle).contains(app.key),
        nativeOptions: nativeEngine(app.bottle)
            ? {
                for (final option in nativeOptions(home, app.bottle, app.key))
                  NativeOption.values.byName(option.name),
              }
            : const {},
      ),
  ];
}

/// [arm64Apps] for the library, whose bottles may be gone from under it.
Set<String> _arm64OrNone(String home, String bottle) {
  try {
    return arm64Apps(home, bottle);
  } on EngineFailure {
    return const {};
  }
}
