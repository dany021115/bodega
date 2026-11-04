/// The catalog (C1), from gauthierpiarrette/highball-db at f0bf6a2 (CC0-1.0).
/// Text in the app, not a file, because `dart compile exe` carries no assets.
/// Nothing here comes from CrossOver's data.
const catalogJson = r'''
[
  {
    "id": "steam",
    "title": "Steam",
    "status": "tested",
    "statusNote": "Probado en Bodega el 2026-11-04 (M2 Pro, macOS 27.0.1): instala, abre, inicia sesión, descarga y lanza juegos. Muck (D3D11) corrió con DXMT. Los juegos con Easy Anti-Cheat, como POLYGON, no arrancan.",
    "installer": {
      "url": "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe",
      "sha256": null,
      "args": ["/S"],
      "msi": false
    },
    "exe": "Program Files (x86)/Steam/steam.exe",
    "args": [],
    "backend": "dxmt",
    "sync": "none",
    "env": {},
    "registry": [],
    "notes": [
      "El primer arranque baja el cliente de 64 bits (unos 235 MB) y lo descomprime: bajo Rosetta tarda 15-25 min y puede parecer colgado. Si se cierra, ábrelo otra vez: continúa.",
      "Deja activada la opción Ajustes > Interfaz > aceleración por GPU en vistas web: sin ella, la ventana sale en negro en Wine 11.",
      "Esta botella va sin msync porque la ventana de Steam se cuelga con él. Highball reporta que los juegos rinden en torno a un 40 % más con msync.",
      "Si un juego falla con el overlay de Steam, desactívalo en los ajustes de Steam, sección En la partida."
    ],
    "knownIssues": [
      {
        "symptom": "NO CONNECTION justo después de iniciar sesión",
        "fix": "Cierra el Steam nativo de Mac."
      },
      {
        "symptom": "Un juego con Easy Anti-Cheat no arranca: error 206, Failed to load the anti-cheat module",
        "fix": "Sin solución en Bodega: depende de los desarrolladores del juego y de Epic. Comprobado con POLYGON, que tampoco arranca en CrossOver."
      },
      {
        "symptom": "Un cliente recién instalado se cierra unos tres minutos después de su primera actualización, antes de iniciar sesión",
        "fix": "Ábrelo otra vez; solo pasa en esa primera ejecución."
      },
      {
        "symptom": "Error nested exception on signal stack durante la primera actualización",
        "fix": "Ábrelo otra vez; continúa donde iba."
      },
      {
        "symptom": "La descarga se para hacia 215/235 MB",
        "fix": "bodega stop steam y ábrelo otra vez; continúa."
      },
      {
        "symptom": "Steam Client Service no arranca (GLE 126)",
        "fix": "No importa para la mayoría de los juegos; solo lo necesitan algunos anti-cheat o drivers."
      },
      {
        "symptom": "La ventana de Steam sale en negro en Wine 11, con DXMT y con DXVK",
        "fix": "Hay que activar la aceleración por GPU en vistas web. Highball lo hace pasando un momento por su motor Wine 10, que Bodega no tiene: sin solución probada aquí."
      }
    ],
    "source": {
      "repo": "gauthierpiarrette/highball-db",
      "commit": "f0bf6a2",
      "path": "recipes/launchers/steam.json",
      "license": "CC0-1.0",
      "verified": "2026-08-24, x64-sikarugir10.0_6-r0, macOS 14.6, M1 Pro"
    }
  },
  {
    "id": "rockstar",
    "title": "Rockstar Games Launcher",
    "status": "reported",
    "statusNote": "Highball lo verificó en un motor del árbol de CrossOver 26.3 (r15): instalador, servicio y ventana de inicio de sesión con DXVK. Sin probar en Bodega, y nuestro DXVK es otra versión.",
    "installer": {
      "url": "https://gamedownloads.rockstargames.com/public/installer/Rockstar-Games-Launcher.exe",
      "sha256": null,
      "args": [],
      "msi": false
    },
    "exe": "Program Files/Rockstar Games/Launcher/Launcher.exe",
    "args": [],
    "backend": "dxvk",
    "sync": "none",
    "env": {},
    "registry": [
      {
        "key": "HKLM\\System\\CurrentControlSet\\Control",
        "name": "ServicesPipeTimeout",
        "type": "REG_SZ",
        "data": "60000"
      },
      {
        "key": "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Image File Execution Options\\Rockstar-Games-Launcher.exe",
        "name": "GlobalFlag",
        "type": "REG_DWORD",
        "data": "16"
      }
    ],
    "notes": [
      "El instalador trae lo que necesita de Social Club.",
      "Si se congela en el logo, prueba bodega open --backend d3dmetal rockstar. Highball también sugiere vcrun2019, que Bodega aún no instala."
    ],
    "knownIssues": [
      {
        "symptom": "La ventana de inicio de sesión sale vacía",
        "fix": "bodega stop rockstar y ábrelo otra vez."
      },
      {
        "symptom": "El instalador se queda para siempre en Preparing to Install...",
        "fix": "Sin solución conocida."
      },
      {
        "symptom": "Error #1.000.7 o #1.500.7 al iniciar sesión",
        "fix": "Pon la hora del Mac con zona horaria automática e inténtalo otra vez."
      }
    ],
    "source": {
      "repo": "gauthierpiarrette/highball-db",
      "commit": "f0bf6a2",
      "path": "recipes/launchers/rockstar.json",
      "license": "CC0-1.0",
      "verified": "2026-09-18, x64-crossover26.3-r15, macOS 26.6.2, M1 Pro"
    }
  },
  {
    "id": "ea-app",
    "title": "EA app",
    "status": "reported",
    "statusNote": "Highball lo verificó en un motor del árbol de CrossOver 26.3 (r15): instalación, servicio y ventana de inicio de sesión, sin llegar a iniciar sesión. Sin probar en Bodega.",
    "flaky": "Es de los launchers más inestables bajo Wine. Además, Highball arregla un enlace de su instalación con un paso propio que Bodega no tiene, así que la instalación puede decir que falta el ejecutable.",
    "installer": {
      "url": "https://origin-a.akamaihd.net/EA-Desktop-Client-Download/installer-releases/EAappInstaller.exe",
      "sha256": null,
      "args": [],
      "msi": false
    },
    "exe": "Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe",
    "args": [],
    "backend": "dxmt",
    "sync": "none",
    "env": {},
    "registry": [],
    "notes": [
      "Pueden salir errores de su servicio en segundo plano; se pueden cerrar.",
      "La comunidad de Sikarugir lo usa con D3DMetal: la alternativa es bodega open --backend d3dmetal ea-app."
    ],
    "knownIssues": [
      {
        "symptom": "El instalador arranca y se queda sin ventana y sin usar CPU",
        "fix": "Si no aparece nada en un minuto, bodega stop ea-app y vuelve a intentarlo."
      },
      {
        "symptom": "Ventana oscura y vacía, o la app no está tras instalar bien",
        "fix": "En Program Files/Electronic Arts/EA Desktop, EA Desktop debe ser un enlace a la carpeta de la versión. Highball lo crea solo; en Bodega hay que hacerlo a mano."
      }
    ],
    "source": {
      "repo": "gauthierpiarrette/highball-db",
      "commit": "f0bf6a2",
      "path": "recipes/launchers/ea-app.json",
      "license": "CC0-1.0",
      "verified": "2026-10-05, x64-crossover26.3-r15, macOS 27.0, M4"
    }
  },
  {
    "id": "ubisoft-connect",
    "title": "Ubisoft Connect",
    "status": "reported",
    "statusNote": "Highball vio su ventana de inicio de sesión en un motor del árbol de CrossOver 26.3 (r4) con DXMT, sin iniciar sesión. Sin probar en Bodega.",
    "installer": {
      "url": "https://static3.cdn.ubi.com/orbit/launcher_installer/UbisoftConnectInstaller.exe",
      "sha256": null,
      "args": ["/S"],
      "msi": false
    },
    "exe": "Program Files (x86)/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe",
    "args": [],
    "backend": "dxmt",
    "sync": "none",
    "env": {"WINE_SIMULATE_WRITECOPY": "1"},
    "registry": [],
    "notes": [
      "Desactiva el overlay en los ajustes de Connect: se inyecta en los juegos y falla bajo Wine.",
      "Usa DXMT, con el que Highball verificó la ventana, aunque su receta fija D3DMetal."
    ],
    "knownIssues": [
      {
        "symptom": "El launcher corre, pero su ventana sale en blanco o en negro",
        "fix": "Highball lo vio en su motor Wine 10. Prueba otro backend con bodega open --backend."
      }
    ],
    "source": {
      "repo": "gauthierpiarrette/highball-db",
      "commit": "f0bf6a2",
      "path": "recipes/launchers/ubisoft-connect.json",
      "license": "CC0-1.0",
      "verified": "2026-09-05, x64-crossover26.3-r4, macOS 26.6.2, M1 Pro"
    }
  },
  {
    "id": "battle-net",
    "title": "Battle.net",
    "status": "untested",
    "statusNote": "Highball solo lo verificó en su motor Wine 10; en Wine 11 r10 la ventana quedó en negro. Bodega usa Wine 11, así que puede no funcionar.",
    "flaky": "El inicio de sesión puede cerrarse al enviarlo: reintenta y desactiva la aceleración por hardware en sus ajustes.",
    "installer": {
      "url": "https://downloader.battle.net/download/getInstaller?os=win&installer=Battle.net-Setup.exe",
      "sha256": null,
      "args": ["--lang=enUS", "--installpath=C:\\Program Files (x86)\\Battle.net"],
      "msi": false
    },
    "exe": "Program Files (x86)/Battle.net/Battle.net Launcher.exe",
    "args": [],
    "backend": "dxmt",
    "sync": "none",
    "env": {},
    "registry": [],
    "notes": [
      "Su instalador tiene ventana y baja el cliente: déjalo terminar.",
      "Al terminar, el cliente abre su inicio de sesión; Bodega lo cierra para que el primer arranque use sus ajustes."
    ],
    "knownIssues": [
      {
        "symptom": "La ventana de inicio de sesión abre, pero su contenido sale en negro",
        "fix": "Sin solución confirmada en Wine 11."
      },
      {
        "symptom": "Se cierra al enviar el inicio de sesión",
        "fix": "Reintenta y desactiva la aceleración por hardware en sus ajustes."
      }
    ],
    "source": {
      "repo": "gauthierpiarrette/highball-db",
      "commit": "f0bf6a2",
      "path": "recipes/launchers/battle-net.json",
      "license": "CC0-1.0",
      "verified": "2026-09-18, x64-sikarugir10.0_6-r5, macOS 26.6.2, M1 Pro"
    }
  },
  {
    "id": "epic-games",
    "title": "Epic Games Launcher",
    "status": "blocked",
    "statusNote": "Comprueba permisos de Windows que Wine no guarda, y al instalar juegos falla con DP-07. La alternativa es legendary, que Bodega aún no incluye.",
    "installer": {
      "url": "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi",
      "sha256": null,
      "args": [],
      "msi": true
    },
    "exe": "Program Files/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe",
    "args": ["-SkipBuildPatchPrereq"],
    "backend": "dxvk",
    "sync": "none",
    "env": {},
    "registry": [],
    "notes": ["Su interfaz es pesada: el primer arranque tarda minutos."],
    "knownIssues": [
      {
        "symptom": "Instalar cualquier juego falla con You do not have permission to install to... (DP-07)",
        "fix": "Sin solución dentro del launcher."
      }
    ],
    "source": {
      "repo": "gauthierpiarrette/highball-db",
      "commit": "f0bf6a2",
      "path": "recipes/launchers/epic-games.json",
      "license": "CC0-1.0",
      "verified": "2026-08-25, x64-sikarugir10.0_6-r0, macOS 14.6, M1 Pro"
    }
  },
  {
    "id": "gog-galaxy",
    "title": "GOG Galaxy",
    "status": "blocked",
    "statusNote": "Se instala, pero en Wine 11 muestra el inicio de sesión y se cierra a los dos segundos. Los juegos de GOG no tienen DRM: usa sus instaladores offline con bodega create y bodega run.",
    "installer": {
      "url": "https://content-system.gog.com/open_link/download?path=/open/galaxy/client/setup_galaxy_2.1.6.29.exe",
      "sha256": "c2888e0a1425823e47ed04c26e2d3c81cb14564a8e92d9c9628c3ed77a9d87bc",
      "args": ["/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES"],
      "msi": false
    },
    "exe": "Program Files/GOG Galaxy/GalaxyClient.exe",
    "args": ["/runWithoutUpdating", "/deelevated"],
    "backend": "dxmt",
    "sync": "none",
    "env": {},
    "registry": [],
    "notes": [],
    "knownIssues": [
      {
        "symptom": "Muestra el inicio de sesión y se cierra unos dos segundos después",
        "fix": "Sin solución; usa los instaladores offline de gog.com."
      }
    ],
    "source": {
      "repo": "gauthierpiarrette/highball-db",
      "commit": "f0bf6a2",
      "path": "recipes/launchers/gog-galaxy.json",
      "license": "CC0-1.0",
      "verified": "sin datos"
    }
  }
]
''';
