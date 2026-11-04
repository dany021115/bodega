import 'package:bodega/domain/entities/library_app.dart';
import 'package:engine/engine.dart';

/// The engine's applications with their pictures. It reads executables, so it
/// runs inside `Isolate.run`: some games have huge ones (design §3).
List<LibraryApp> libraryApps(String home, List<InstalledApp> apps) => [
  for (final app in apps)
    LibraryApp(
      bottle: app.bottle,
      key: app.key,
      id: app.id,
      title: app.title,
      iconPath: appIcon(home, app),
    ),
];
