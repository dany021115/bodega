# Base de la app

## B1 · Proyecto
`apps/bodega`, creado con `flutter create --platforms=macos --org com.dany021115 --project-name bodega`. `com.apple.security.app-sandbox` fuera de los dos `.entitlements`. Ventana con tamaño mínimo de 720×480 (`MainFlutterWindow.swift`) y título Bodega.

**Comprobación:** `flutter build macos` termina; la app abierta con `open` lanza Wine (`design.md` §7).

## B2 · Capas
Estructura de `TS/lib`: `main.dart`, `di.dart`, `app/{router.dart,bloc,presentation,shared/widgets}`, `data/{api,entities,repository,service}`, `device/{router,theme,helpers}`, `domain/{entities,repository}`, `resources`.

Reglas:
- `domain/` no importa `flutter`, `dart:io`, `engine`, `data/`, `device/` ni `app/`.
- `data/` es la única capa que importa `package:engine`.
- `device/` no importa `data/` ni `domain/`.
- Imports absolutos `package:bodega/…`. Un widget por archivo en `widgets/`. UI en español, código en inglés.

**Comprobación (T15):** `grep` que falla si `domain/` importa algo de eso, o si otra capa importa `package:engine`.

## B3 · Tema
`device/theme/{color,radius,spacing,typography,theme}.dart`, como TeeShot. Oscuro por defecto, acento burdeos, `AppTextStyle.fontFamily` en `null` para SF Pro. `ThemeBloc` en `app/bloc/theme/` con la preferencia en `shared_preferences`.

**Escenario (test `ThemeBloc`):** arranca oscuro; `toggle` cambia y se guarda.

## B4 · Router
`enum AppRoute` y `GoRouter` en `app/router.dart`; `RouterManager`, `PageTransitions` y `StackObserver` en `device/router/`. `ShellRoute` con `MainShell` para las cuatro secciones. Se navega por id.

Redirección: sin runtime o sin Rosetta, siempre a `/setup`; con ellos, `/setup` lleva a `/library`.

**Escenario (test `router`):** la redirección devuelve esas rutas en cada caso.

## B5 · Breakpoints
`ResponsiveBreakpoints.builder` con los valores de `TS/lib/main.dart:170-175`. Desde `DESKTOP`, barra lateral con texto, y en la cuadrícula del catálogo dos columnas; por debajo, barra compacta de iconos y una columna.

**Escenario (test de widget `MainShell`):** a 1000 px se ve el texto, a 600 px solo los iconos.

## B6 · Errores y avisos
`AppError` sealed en `domain/entities/`: `EngineError(message)`, `NetworkError(message)` y `UnknownError(message)`. Los repositorios capturan lo que lance el motor y devuelven `Left`. Los bloc lo guardan en el estado. `AppToast` en `device/helpers/`.

**Escenario (test de repositorio):** un error del motor llega como `Left(EngineError)` con su texto.

## B7 · Inyección y código generado
get_it e injectable con `@InjectableInit`, `preResolve` para `SharedPreferences`, `build.yaml` como TeeShot sin `envied`. `*.g.dart`, `*.freezed.dart` y `di.config.dart` en `.gitignore`, y excluidos del analizador.

**Comprobación:** `dart run build_runner build` genera sin errores y `flutter analyze` queda limpio.

## B8 · Assets
7 SVG de `simple-icons` en `assets/icons/catalog/`, con `spider.yaml` y constantes en `resources/`. Se pintan con el color de marca, o con el del tema si es negro.

## B9 · Reglas del repo
`.claude/CLAUDE.md`, y `rules/{architecture,code-style,widget-standards}.md`, adaptados de TeeShot, sin lo específico de iOS, y con lo propio de este repo: versiones, motor solo en `data/`, y `.sdd`.
