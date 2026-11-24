import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/native_option.dart';
import 'package:engine/engine.dart' hide NativeOption;

/// The engine's applications with their pictures. It reads executables, so it
/// runs inside `Isolate.run`: some games have huge ones (design §3).
List<LibraryApp> libraryApps(String home, List<InstalledApp> apps) {
  final native = <String, bool>{};
  bool nativeEngine(String bottle) =>
      native[bottle] ??= bottleRuntime(home, bottle) == RuntimeKind.mach9;
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
        nativeOptions: nativeEngine(app.bottle)
            ? {
                for (final option in nativeOptions(home, app.bottle, app.key))
                  NativeOption.values.byName(option.name),
              }
            : const {},
      ),
  ];
}
