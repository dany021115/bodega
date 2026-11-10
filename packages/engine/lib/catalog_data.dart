/// The catalog (C1), from gauthierpiarrette/highball-db at f0bf6a2 (CC0-1.0).
/// Text in the app, not a file, because `dart compile exe` carries no assets.
/// Nothing here comes from CrossOver's data.
const catalogJson = r'''
[
  {
    "id": "steam",
    "title": "Steam",
    "status": "tested",
    "statusNote": "Tested in Bodega on 2026-11-04 (M2 Pro, macOS 27.0.1): installs, opens, signs in, downloads and launches games. Muck (D3D11) ran with DXMT. Games with Easy Anti-Cheat, like POLYGON, don't start.",
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
      "The first start downloads the 64-bit client (about 235 MB) and unpacks it: under Rosetta it takes 15-25 min and may look frozen. If it closes, open it again: it resumes.",
      "Keep Settings > Interface > GPU accelerated rendering in web views turned on: without it, the window is black in Wine 11.",
      "This bottle runs without msync because the Steam window hangs with it. Highball reports games run about 40% faster with msync.",
      "If a game fails with the Steam overlay, turn it off in Steam settings, In Game section."
    ],
    "knownIssues": [
      {
        "symptom": "NO CONNECTION right after signing in",
        "fix": "Quit the native Mac Steam."
      },
      {
        "symptom": "A game with Easy Anti-Cheat doesn't start: error 206, Failed to load the anti-cheat module",
        "fix": "No fix in Bodega: it's up to the game's developers and Epic. Checked with POLYGON, which doesn't start in CrossOver either."
      },
      {
        "symptom": "A freshly installed client closes about three minutes after its first update, before signing in",
        "fix": "Open it again; it only happens on that first run."
      },
      {
        "symptom": "Error nested exception on signal stack during the first update",
        "fix": "Open it again; it resumes where it left off."
      },
      {
        "symptom": "The download stalls around 215/235 MB",
        "fix": "bodega stop steam and open it again; it resumes."
      },
      {
        "symptom": "Steam Client Service doesn't start (GLE 126)",
        "fix": "Doesn't matter for most games; only some anti-cheats or drivers need it."
      },
      {
        "symptom": "The Steam window is black in Wine 11, with both DXMT and DXVK",
        "fix": "GPU acceleration in web views must be turned on. Highball does it by briefly going through its Wine 10 engine, which Bodega doesn't have: no tested fix here."
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
    "statusNote": "Highball verified it on an engine from the CrossOver 26.3 tree (r15): installer, service and sign-in window with DXVK. Not tested in Bodega, and our DXVK is a different version.",
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
      "The installer brings what it needs from Social Club.",
      "If it freezes on the logo, try bodega open --backend d3dmetal rockstar. Highball also suggests vcrun2019, which Bodega doesn't install yet."
    ],
    "knownIssues": [
      {
        "symptom": "The sign-in window is empty",
        "fix": "bodega stop rockstar and open it again."
      },
      {
        "symptom": "The installer stays forever on Preparing to Install...",
        "fix": "No known fix."
      },
      {
        "symptom": "Error #1.000.7 or #1.500.7 when signing in",
        "fix": "Set the Mac clock to automatic time zone and try again."
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
    "statusNote": "Highball verified it on an engine from the CrossOver 26.3 tree (r15): install, service and sign-in window, without actually signing in. Not tested in Bodega.",
    "flaky": "One of the most unstable launchers under Wine. Also, Highball fixes a link in its install with its own step that Bodega doesn't have, so the install may report the executable is missing.",
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
      "Errors from its background service may show up; you can close them.",
      "The Sikarugir community uses it with D3DMetal: the alternative is bodega open --backend d3dmetal ea-app."
    ],
    "knownIssues": [
      {
        "symptom": "The installer starts and sits with no window and no CPU use",
        "fix": "If nothing shows up within a minute, bodega stop ea-app and try again."
      },
      {
        "symptom": "Dark, empty window, or the app is missing after a good install",
        "fix": "In Program Files/Electronic Arts/EA Desktop, EA Desktop must be a link to the version folder. Highball creates it automatically; in Bodega you have to do it by hand."
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
    "statusNote": "Highball saw its sign-in window on an engine from the CrossOver 26.3 tree (r4) with DXMT, without signing in. Not tested in Bodega.",
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
      "Turn off the overlay in Connect settings: it injects into games and fails under Wine.",
      "Uses DXMT, which Highball verified the window with, though its recipe pins D3DMetal."
    ],
    "knownIssues": [
      {
        "symptom": "The launcher runs, but its window is white or black",
        "fix": "Highball saw it on its Wine 10 engine. Try another backend with bodega open --backend."
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
    "statusNote": "Highball only verified it on its Wine 10 engine; on Wine 11 r10 the window stayed black. Bodega uses Wine 11, so it may not work.",
    "flaky": "Sign-in may close when submitted: retry and turn off hardware acceleration in its settings.",
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
      "Its installer has a window and downloads the client: let it finish.",
      "When done, the client opens its sign-in; Bodega closes it so the first start uses its settings."
    ],
    "knownIssues": [
      {
        "symptom": "The sign-in window opens, but its content is black",
        "fix": "No confirmed fix in Wine 11."
      },
      {
        "symptom": "Closes when the sign-in is submitted",
        "fix": "Retry and turn off hardware acceleration in its settings."
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
    "statusNote": "It checks Windows permissions that Wine doesn't store, and installing games fails with DP-07. The alternative is legendary, which Bodega doesn't include yet.",
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
    "notes": ["Its interface is heavy: the first start takes minutes."],
    "knownIssues": [
      {
        "symptom": "Installing any game fails with You do not have permission to install to... (DP-07)",
        "fix": "No fix inside the launcher."
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
    "statusNote": "It installs, but on Wine 11 it shows the sign-in and closes after two seconds. GOG games have no DRM: use their offline installers with bodega create and bodega run.",
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
        "symptom": "Shows the sign-in and closes about two seconds later",
        "fix": "No fix; use the offline installers from gog.com."
      }
    ],
    "source": {
      "repo": "gauthierpiarrette/highball-db",
      "commit": "f0bf6a2",
      "path": "recipes/launchers/gog-galaxy.json",
      "license": "CC0-1.0",
      "verified": "no data"
    }
  }
]
''';
