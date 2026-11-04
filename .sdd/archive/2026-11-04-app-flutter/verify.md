# Verificación: app-flutter

2026-11-04, M2 Pro, macOS 27.0.1. Base `628be6b`, el commit de T17, más los cambios de esta fase en `.sdd/`. Sin cambios de código en `verify`.

## Motor

| Requisito | Estado | Evidencia |
|---|---|---|
| E1 Workspace | cumplido | `dart test` y `dart compile exe` en la salida 2 |
| E2 `listBottles` | cumplido | Test `listBottles`: lista con aplicación, lista sin ella e incompleta. Datos reales en la salida 6 |
| E3 `bottleSettings` | cumplido | Test `settings`; real en la salida 6 |
| E4 `removeBottle` | cumplido | Test `removeBottle`: el enlace externo sobrevive y una botella que no existe da error. Real: `DELETED true`, salida 6 |
| E5 Rosetta y runtime | cumplido | Test `hasRuntime`; la salida 4 muestra que la app pasa la comprobación |
| E6 Instalador descargado | cumplido, con límite | Test `installEntry with a downloaded setup`. Solo con Wine falso: ver U3 |
| E7 `bottleLogs` | cumplido | Test `bottleLogs`; real en la salida 6 |
| E8 `addApp` | cumplido | Test `addApp`, dentro y fuera de `drive_c`; tu Blur real en U5 |
| E9 `pinnedBackend` | cumplido | `backends_test.dart:96-98`; descarga real de DXVK con ese SHA, salida 6 |

## Base

| Requisito | Estado | Evidencia |
|---|---|---|
| B1 Proyecto | cumplido | Salida 3. Abierta con `open`, la app lanza el motor con su entorno: salida 4. Wine real desde la app: logs de U1, con `flutter run` |
| B2 Capas | cumplido | `check_layers.sh` pasa, y falla con cada regla rota (salida 5). Sin imports relativos ni dos widgets en un archivo de `widgets/` (salida 3) |
| B3 Tema | cumplido | Test `ThemeBloc`; salida 3 |
| B4 Router | cumplido | Test `router`; salida 3 |
| B5 Breakpoints | cumplido | Test `MainShell` a 1000 y 600 px; mismos valores que TeeShot (salida 3); 36 tests de pantallas sin desbordes |
| B6 Errores | cumplido | Test de repositorio; textos reales del motor en la salida 6 |
| B7 Inyección y generado | cumplido | build_runner y `flutter analyze` limpios; salida 3 |
| B8 Assets | cumplido, con desviación | 7 SVG con `spider`. Desviación 3 |
| B9 Reglas | cumplido | `.claude/CLAUDE.md` y sus 3 reglas; nombran versiones y capas (salida 3) |

## Pantallas

| Requisito | Estado | Evidencia |
|---|---|---|
| P1 Rosetta y runtime | cumplido, con límite | Test `SetupBloc`, los 4 casos. Nadie ha pulsado esta pantalla con archivos reales: tu runtime ya estaba instalado |
| P2 Lista y búsqueda | cumplido | Tests `CatalogBloc` y `the 7 of the catalog`; tu búsqueda real en U2 |
| P3 Ficha | cumplido | Test `the detail offers each case`, los 4 botones |
| P4 Instalar | cumplido, con límite | Tests `InstallBloc`, los 5 casos, y `Downloader`, con HTTPS real en la salida 7. Instalación real de un launcher: ver U3 |
| P5 Anti-cheat | cumplido, con corrección | Tests `AntiCheatRepository`, los 3 casos; 1.166 juegos reales (salida 7). Desviaciones 2 y 4 |
| P6 Lista | cumplido | Test `LibraryBloc`, lista y vacía |
| P7 Abrir y parar | cumplido | Tests `LibraryBloc`, los 4 casos; logs reales de U1 |
| P8 Avisos | cumplido, con límite | Test `a hint comes out once`; el temporizador de 5 s, con reloj falso en la salida 8; 3,8 ms por lectura en la salida 9. Sin juego real: ver U8 |
| P9 Otra aplicación | cumplido, con límite | Tests `AddAppBloc`, incluidos los 3 casos; tu Blur en U5. Instalador con la botella real, pero usando la sonda: salida 6 |
| P10 Lista de botellas | cumplido | Test `a bottle says what it is` |
| P11 Detalle | cumplido | Tests `BottleDetailBloc`, los 4 casos, y repositorio con 2.000 líneas; real en la salida 6 |
| P12 Backends | cumplido | Tests `BackendsBloc`; descarga real, SHA erróneo y sin restos: salida 6 |
| P13 D3DMetal | cumplido | Test `D3DMetal is imported, never downloaded`; importación real y rechazo de CrossOver: salida 6 |
| P14 Comprobar | cumplido | Test `BackendsBloc`; DXMT real (salida 6) y tu D3DMetal real (U7) |

## Aceptación del usuario

Dijiste que todo salió bien. Esto es lo que dejaron esas pruebas en disco, porque de lo demás solo tengo tu palabra.

| Prueba | Resultado | Evidencia en disco |
|---|---|---|
| T17 Commit | hecho | `628be6b`, con tu identidad y sin atribución de IA. El único `claude` del mensaje es la carpeta `.claude` |
| U1 Biblioteca | aceptada | Logs de Steam a las 15:53, 15:59 y 16:01 UTC, con `backend dxmt (exe)`. El último sale con 1, lo esperable al pararlo |
| U2 Catálogo | aceptada | `cache/anticheat.json` creado a las 10:58: hubo una búsqueda real |
| **U3 Instalar** | **sin confirmar** | **Ninguna botella de otro launcher.** Steam es del 3 de noviembre, por CLI. `downloads/` cambió a las 11:00, así que algo se descargó, y pudo borrarse después |
| U4 Cancelar | aceptada | `downloads/` vacío, sin `.part` ni botella de sobra. Es compatible, no lo prueba |
| U5 Otra aplicación | aceptada | Botella `games`: `custom`, `Blur.exe`, `exit=0`, `backend wine (auto)`. **Su título es `Games`, no `Blur`** |
| **U6 Botellas** | **sin confirmar** | **Ni `prueba` ni `games` tienen `settings.json`, y el de `steam` es del 3 de noviembre.** Cambiar el backend siempre lo escribe, así que el cambio no fue en estas tres. Tampoco se ha borrado ninguna desde las 12:12 |
| U7 Backends | aceptada | D3DMetal en `games`: `probe-64`, `probe-64` y `probe-32`, todos con `exit=0` y `backend d3dmetal (opcion)` |
| **U8 Anti-cheat** | **no ejecutada** | Ninguna botella tiene carpeta `EasyAntiCheat`: no hay juego con el que probarlo. La lectura del log se probó con el CLI en `catalogo`; la unión con la app solo con mocks |
| U9 Reabrir | aceptada | No deja rastro: solo tu palabra. El mecanismo está en el test `rebuilds what is running` |

## Al archivar

Se archiva con tu aprobación y con esto abierto:

- **U3, U6 y U8:** sin confirmar, y sin marcar en `tasks.md`.
- **Título `Games` de tu Blur:** no se sabe si lo escribiste tú. El título por defecto sale del nombre del archivo y ninguna ruta del código da `Games`, pero no se ha descartado un fallo.

## Desviaciones

1. **Descarga:** `Downloader` lee el stream a mano en vez de usar `dio.download`, y pide `identity`. `design.md` §4 ya lo dice. Sus tests están en `test/data/downloader_test.dart`, no en un repositorio, porque lo usan dos.
2. **Anti-cheat:** se lee la caché antes que la red, porque la lista está fijada a un commit y no cambia. Los 3 escenarios de P5 se cumplen.
3. **Colores:** en tema oscuro, los colores de marca se aclaran un 25 %, y el `313131` de Epic cuenta como negro. Si no, apenas se verían.
4. **POLYGON:** la especificación decía que no estaba en la lista, y sí está. P5 ya está corregida.
5. **`Incompleta`:** solo significa prefijo sin terminar, como dice E2. `design.md` §6 decía otra cosa y ya está corregido.
6. **Lecturas de EAC:** no se limitan a cuando el log cambia. Medido, no hace falta (salida 9).
7. **Añadidos que no estaban en la especificación:** `Parar` en el detalle de botella, `El instalador ya terminó`, el botón de tema y la ventana inicial de 1100×720.
8. **Dependencias quitadas:** `package_info_plus` y `cupertino_icons`, sin uso.

## Sin comprobar

- Instalar un launcher real desde la app (U3), y un instalador real con ventana por `Es un instalador`.
- `Comprobar` con `wine` y `dxvk` desde la app; sí se probaron con el CLI en `backends-graficos`.
- Los selectores `Elegir archivo…`, `Elegir carpeta…` y los de `/setup`, con archivos reales.
- La imagen actual de D3DMetal de Apple; solo las copias de Whisky y Sikarugir, y por eso la pantalla lo avisa.
- Cómo se ve. El agente no lo juzga.

## Salidas

### 1. App
```
$ flutter analyze
No issues found! (ran in 2.1s)
$ flutter test
00:03 +112: All tests passed!
resultados por test (--reporter json): {'success': 112}; 36 de pantallas a 720, 801, 1100 y 1921 px, todos correctos
$ tool/check_layers.sh
Capas correctas
exit=0
$ flutter build macos
✓ Built build/macos/Build/Products/Release/Bodega.app (48.9MB)
```

### 2. Motor
```
$ dart analyze
No issues found!
$ dart test
00:18 +30 ~2: All tests passed!
$ dart compile exe bin/bodega.dart -o ../../build/bodega
Generated: /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
$ build/bodega catalog list
steam             Steam                     tested
rockstar          Rockstar Games Launcher   reported
ea-app            EA app                    reported
ubisoft-connect   Ubisoft Connect           reported
battle-net        Battle.net                untested
epic-games        Epic Games Launcher       blocked
gog-galaxy        GOG Galaxy                blocked
```

### 3. Contraste con el código
```
B1  10: self.minSize = NSSize(width: 720, height: 480)
    Release.entitlements:0  DebugProfile.entitlements:0   (app-sandbox)
    <window title="Bodega"   PRODUCT_NAME = Bodega   PRODUCT_BUNDLE_IDENTIFIER = com.dany021115.bodega
B2  archivos de widgets/ con más de un widget: ninguno.  imports relativos: 0
B3  color.dart radius.dart spacing.dart theme.dart typography.dart
    static String? get fontFamily => null;
    super(ThemeState(isDark: preferences.getDarkTheme() ?? true))
B4  27: enum AppRoute   40: setupRedirect   54: StackObserver   55: refreshListenable   72: ShellRoute
    manager.dart observer.dart transitions.dart
B5  Bodega y TeeShot: 0-450 MOBILE, 451-800 TABLET, 801-1920 DESKTOP, 1921+ 4K
B6  AppError.engine = EngineError, .network = NetworkError, .unknown = UnknownError
B7  build.yaml: explicit_to_json, include_if_null   .gitignore: *.g.dart *.freezed.dart *.config.dart
    @preResolve   @InjectableInit(initializerName: 'init', asExtension: true)
B8  7 SVG   lib/resources/assets_catalog_icons.dart
B9  .claude: CLAUDE.md rules/{architecture,code-style,widget-standards}.md
```

### 4. Compilación release abierta con `open`
Carpeta vacía:
```
dart_ran=yes after=2s dirs=bottles runtimes
new_pid=30030 alive=yes rss_mb=120
log: Using the Impeller rendering backend (MetalSDF).
stopped=yes others_kept=[25779 ] now=[25779 ]
new_crash_reports=0
```
Carpeta temporal con un `wineserver` falso que anota cómo lo llaman:
```
engine_called=yes after=1s
args: -w
HOME=~
LOGNAME=quasar
PATH=/usr/bin:/bin:/usr/sbin:/sbin
TMPDIR=(presente)
USER=quasar
WINEMSYNC=1
WINEPREFIX=<home>/bottles/una/prefix
env_vars=16
```
Un intento anterior con tus datos reales, buscando `wineserver` cada 0,1 s, vio 0 procesos. No prueba nada: sin servidor dura unos 0,03 s. Por eso se hizo la prueba del `wineserver` falso.

### 5. Comprobación de capas con cada regla rota
En copias temporales. La última línea es un import permitido, de control:
```
exit=1 NO: domain/ es Dart puro: sin flutter, dart:io, motor ni otras capas   (dart:io)
exit=1 NO: domain/ es Dart puro: sin flutter, dart:io, motor ni otras capas   (flutter)
exit=1 NO: domain/ es Dart puro: sin flutter, dart:io, motor ni otras capas   (data/)
exit=1 NO: solo data/ importa package:engine   (app/)
exit=1 NO: solo data/ importa package:engine   (device/)
exit=1 NO: device/ no importa data/ ni domain/
exit=1 NO: solo data/ importa package:engine   (main.dart)
exit=1 NO: imports absolutos: package:bodega/...
exit=0 Capas correctas
```

### 6. Repositorios reales, hito 3
Con un test temporal, ya borrado. La botella se creó y se borró en tu carpeta real; las descargas e importaciones fueron a una carpeta temporal:
```
BOTTLE prueba ready=true app=null
BOTTLE steam ready=true app=Steam
DETAIL backend=auto sync=none exceptions=[ProgramBackend(exe: steam.exe, backend: dxmt)] logs=8 installed=[wine, dxmt, dxvk, d3dmetal]
LOG 2026-11-04T16-01-38.949831Z-steam.log exit=1 lines=99 size=6335 ms=7
DOWNLOAD true last=(2785833, 2785833) d3d11=true
AGAIN ya instalado: …/backends/dxvk. Para cambiarlo: rm -rf "…/backends/dxvk"
BADFILE AppError.engine(message: checksum incorrecto en …/dxmt-falso.tar.gz: e1c1b2e9…, se esperaba 89e731b8…)
DXMT_INSTALLED false TMP false
IMPORT true null ms=75 link=../../external/libd3dshared.dylib
CROSSOVER no se importa desde CrossOver.app: usa tu propia copia de D3DMetal
CREATED zz-prueba-app ms=13364
FREE [prueba, zz-prueba-app]
SET true true
EXC true
DETAIL dxmt none [ProgramBackend(exe: probe-64.exe, backend: dxvk)]
RESET auto msync []
INSTALLER true ms=7513 drive=true
ADDAPP true null
LIBRARY [steam:steam:Steam, zz-prueba-app:custom:Zz Prueba: App!]
CHECK ms=2791 [64/D3D11=true, 32/D3D11=true]
LOGS [2026:0, 2026:0, 2026:0, 2026:0]
DELETED true exists=false rootOk=true
```

### 7. Repositorios reales, hito 2
```
LIB [LibraryApp(bottle: steam, id: steam, title: Steam)]
WAIT steam 752 ms
FIRST_EXIT 2271 ms exit=3
EMPTY 5339 ms
ANTICHEAT 1166 … blocked=31 polygon=1
CACHE 251114 bytes
CANCEL returned=null part=false
RESUME first=(101378, 251114) last=(251114, 251114) same=true
REDIRECT size=251114
HTTP refused
```

### 8. Temporizador de P8
Con reloj falso y un test temporal, ya borrado. Comprueba a los 5 y 10 s, siempre con la misma hora de apertura, una vez más al cerrarse, y ninguna en los 30 s siguientes:
```
P8 checks=3 atClose=3 hintsIn=1
00:00 +1: All tests passed!
```

### 9. Lectura del log de EAC
20 lecturas de un log sintético:
```
size=614525 hints=1 median=3.815 ms max=12.523 ms
```

### 10. Rastros en tu carpeta real
```
games | 2026-11-04T17-17-33.872514Z-probe-32.log | exit=0 | # backend d3dmetal (opcion)
games | 2026-11-04T17-17-28.556041Z-probe-64.log | exit=0 | # backend d3dmetal (opcion)
games | 2026-11-04T17-16-55.986537Z-probe-64.log | exit=0 | # backend d3dmetal (opcion)
games | 2026-11-04T17-12-58.592738Z-Blur.log | exit=0 | # backend wine (auto)
games | 2026-11-04T17-12-39.049315Z-wineboot.log | exit=0 |
steam | 2026-11-04T16-01-38.949831Z-steam.log | exit=1 | # backend dxmt (exe)
steam | 2026-11-04T15-59-58.610277Z-steam.log | exit=0 | # backend dxmt (exe)
steam | 2026-11-04T15-53-14.001090Z-steam.log | exit=0 | # backend dxmt (exe)
games app.json: {'id': 'custom', 'title': 'Games', 'exe': '/Users/quasar/Documents/Games/Blur/Blur.exe', …}
settings.json: games no, prueba no, steam 14:29 del 3 de noviembre
carpetas (hora local): bottles 12:12, bottles/games 12:12, downloads 11:00, cache 10:58
carpetas EasyAntiCheat en todas las botellas: 0
```
