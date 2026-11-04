# Exploración: app-flutter

**Rutas:** `P` = `bodega/packages/engine`; `TS` = `~/Documents/GitHub/TeeShot/TeeShot`; `SF` = `~/Documents/GitHub/SuperFuel23`. Solo lectura; no se ha compilado ni probado nada de esta exploración.

## 1. Problema y alcance

Bodega funciona solo por línea de comandos. El usuario quiere la app de escritorio, como CrossOver, dentro de este repo como **monorepo**, con la arquitectura y las herramientas de TeeShot: clean architecture, `go_router` estructurado, carpeta de `theme` organizada, generación de código, breakpoints, `dio` "y demás cosas que hay ahí".

Pantallas ya acordadas: catálogo con buscador e instalación con avance, biblioteca, ajustes por botella (backend y msync), "instalar otra aplicación" e instrucciones para instalar D3DMetal.

## 2. Arquitectura de TeeShot

Fuentes: `TS/.claude/CLAUDE.md`, `TS/.claude/rules/{architecture,code-style,widget-standards}.md`, `TS/.claude/skills/create-feature`.

```
lib/
├── main.dart            # MultiBlocProvider + MaterialApp.router
├── di.dart / di.config.dart   # get_it + injectable
├── app/
│   ├── router.dart      # GoRouter, enum AppRoute, ShellRoute
│   ├── bloc/            # blocs globales (nav, theme…)
│   ├── presentation/{feature}/  # página, bloc/, widgets/
│   └── shared/widgets/  # main_shell, custom_loading, empty_state…
├── data/
│   ├── api/             # rest_client (retrofit), catch_error (AppError)
│   ├── constants/  entities/  repository/  service/  utils/
├── device/
│   ├── router/          # manager, observer, transitions
│   ├── theme/           # color, radius, spacing, theme, typography
│   └── helpers/         # app_toast
├── domain/
│   ├── entities/        # freezed, inmutables
│   └── repository/      # interfaces
└── resources/           # assets generados con spider
```

**Reglas que hay que respetar:**
- `domain/` no importa nada de `data/`, `device/` ni `app/`. `data/` implementa las interfaces de `domain/`. `device/` no importa `data/` ni `domain/`. `app/` puede importar todas (`architecture.md`).
- Repositorios: interfaz en `domain/repository/`, implementación con `@LazySingleton(as: …)`, y métodos que devuelven `Future<Either<AppError, T>>` con fpdart (`TS/lib/data/repository/app_config_repository_impl.dart`; `AppError` en `TS/lib/data/api/catch_error.dart`).
- Bloc: freezed en eventos y estado, un solo estado con `@Default` y `copyWith`, `@injectable` o `@singleton`. Los globales en `app/bloc/`, los de cada pantalla en `app/presentation/{feature}/bloc/` (ejemplo: `TS/lib/app/bloc/theme/`).
- Router: `enum AppRoute` y `GoRouter` en `TS/lib/app/router.dart:38`, `ShellRoute` con `MainShell` en `:248`, `RouterManager` con rutas tipadas en `TS/lib/device/router/manager.dart`, y `PageTransitions` en `transitions.dart`. Se navega por id, no por `extra` (memoria del usuario).
- Theme: `AppColor`, `AppRadius`, `AppSpacing`, `AppTextStyle` y `AppTheme` en un archivo cada uno (`TS/lib/device/theme/`), más `ThemeBloc`.
- Breakpoints: `responsive_framework`, móvil 0–450, tableta 451–800, escritorio 801–1920, 4K desde 1921 (`TS/lib/main.dart:168-176`).
- Widgets: uno por archivo en `app/presentation/{feature}/widgets/`. Sin saltos de layout: `Opacity` en vez de `if` para elementos que aparecen y desaparecen. Usar los widgets compartidos, como `CustomLoading` (`widget-standards.md`).
- Otros: imports absolutos `package:…`, UI en español y código en inglés, `AppToast` con toastification (`TS/lib/device/helpers/app_toast.dart`).

## 3. Dependencias

| Grupo | Paquetes | Uso en Bodega |
|---|---|---|
| Se usan igual | `flutter_bloc`, `bloc`, `go_router`, `responsive_framework`, `get_it`, `injectable`, `fpdart`, `freezed`, `json_serializable`, `build_runner`, `toastification`, `shared_preferences`, `url_launcher`, `package_info_plus`, `flutter_svg`, `mocktail`, `spider` | Tal cual |
| Hay que darles un uso real | `dio`, `retrofit` | §5 |
| Sin uso claro | `envied` | Bodega no tiene secretos (§8) |
| No aplican | Firebase, Sentry, RevenueCat, mapas, geolocalización, notificaciones, Phoenix, TTS, anuncios | Son del producto móvil o de login |

**Trampa de versiones.** TeeShot fija `freezed ^2`, `build_runner ^2.4` e `injectable ^2`, con la sintaxis `@freezed class X with _$X`. Con Dart moderno eso rompe: `build_runner` 2.4 arrastra un analyzer que se cuelga con dot-shorthands (memoria del usuario, `wa_catalog`). Este Mac tiene Dart 3.13 y Flutter 3.47. `SF/pubspec.yaml` es la referencia moderna: `freezed ^3.2`, `build_runner ^2.15`, `injectable ^3`, `json_serializable ^6.14`. En freezed 3 se escribe `abstract class` para estado y `sealed class` para eventos. **Copiamos la estructura de TeeShot, no sus versiones.** Falta comprobar la compatibilidad de `retrofit_generator`.

## 4. Monorepo

Hoy el repo tiene `packages/engine`, `.sdd/` y `build/`. Falta `apps/`.

- La app iría en `apps/bodega`, y el motor quedaría como `packages/engine`, con un *pub workspace* en la raíz (Dart 3.13 lo admite; sin probar aún con Flutter y `build_runner`).
- La app importa `package:engine/engine.dart` y `data/` hace de adaptador. `domain/` nunca ve el motor.
- El programa `bodega` sigue existiendo. `P/bin` y sus tests no deberían cambiar.
- Solo macOS: `flutter create --platforms=macos`.

## 5. Dónde encaja `dio`

Hoy la app no tendría ninguna llamada HTTP propia: el motor descarga con `curl` (`P/lib/backends.dart`, `_download`). Usos reales:

1. **Descargas con barra de progreso y cancelación.** `curl` no da avance a la app. `Dio.download` sí, con `onReceiveProgress`, `CancelToken` y `Range` para reanudar. Hace falta que `installEntry` acepte un instalador ya descargado (§6).
2. **Lista de anti-cheat antes de descargar.** `db/anticheat.json` de `highball-db` (1.166 juegos, MIT) por `retrofit`, con caché local. Cumple lo prometido: avisar antes de bajar un juego. POLYGON no está en esa lista, así que no cubre todos los casos.

## 6. Lo que le falta al motor para la app

| Falta | Hoy | Ref |
|---|---|---|
| Listar botellas, también las que no vienen del catálogo | `installedApps` solo ve las que tienen `app.json` | `P/lib/catalog.dart:215` |
| Leer los ajustes de una botella | `_settings` es privado | `P/lib/backends.dart` |
| Borrar una botella | No existe | — |
| Comprobar Rosetta y si hay runtime | Rosetta solo en el CLI; `currentRuntime` lanza un error | `P/bin/bodega.dart`; `P/lib/engine.dart:173` |
| Pasar un instalador ya descargado | `installEntry` siempre descarga | `P/lib/catalog.dart:66` |
| Saber si una botella sigue abierta | `exitOf` se equivoca con launchers que se relanzan: Steam dio `exit=42` y seguía vivo (`verify.md` de `catalogo`) | `P/lib/engine.dart:319` |
| Leer los logs de una botella | Solo se escriben | — |

Para lo de "sigue abierta" basta `waitBottle` (`wineserver -w`, `P/lib/engine.dart:303`): termina cuando se va el último proceso y vuelve al instante si no hay servidor.

## 7. Trampas

1. **Sandbox apagado:** la plantilla de Flutter activa `com.apple.security.app-sandbox`. Con él no se puede lanzar Wine ni escribir fuera del contenedor (`INFORME-FINAL.md` §9.2).
2. **Bloquear la interfaz:** el motor hace lecturas síncronas (`antiCheatHints`, `_settings`, `importD3DMetal`). Son cortas, salvo el log de EAC de unos 600 KB y copiar módulos. Habrá que medirlo.
3. **El juego no depende de la app:** los programas corren desacoplados. Si se cierra Bodega, siguen abiertos, y al volver hay que reconstruir el estado desde el disco.
4. **Instalación a medias:** si se cierra la app durante una instalación, queda una botella sin `app.json`. La biblioteca debe mostrarla como incompleta y dejar borrarla.
5. **Entorno al abrir desde Finder:** `bodegaHome` lee `HOME` y `wineEnv` copia `USER`, `LOGNAME` y `TMPDIR` de `Platform.environment`. Hay que confirmarlo fuera de la Terminal.
6. **Reglas de iOS en TeeShot:** las de App Store no aplican. Aplican su equivalente en macOS: `AppTextStyle.fontFamily` en `null` da SF Pro.
7. **`dart:io`:** TeeShot lo prohíbe por la web. Aquí es solo macOS y el motor lo usa, pero sigue fuera de `domain/`.

## 8. Dudas para la propuesta

1. **Ruta y nombre:** `apps/bodega`, paquete `bodega`, bundle `com.dany021115.bodega`.
2. **`envied`:** Bodega no tiene claves. ¿Se deja fuera hasta que haga falta?
3. **Primer arranque:** el repo del runtime es privado, así que la app no puede bajarlo sin token. ¿Pantalla que elige los tarballs locales con `file_selector`?
4. **Iconos:** ¿logos de `simple-icons` (por confirmar su licencia y que estén los 7), con su SVG en `assets` y `spider`?
5. **Aspecto:** tema oscuro por defecto como tu captura, con barra lateral en escritorio. ¿Algún color de marca?
6. **Pantalla de botellas y backends:** ¿sección propia, o dentro de cada aplicación?
7. **Reglas para el futuro:** ¿creo `.claude/CLAUDE.md` y `rules/` en este repo, como en TeeShot, para que la arquitectura no se pierda?
