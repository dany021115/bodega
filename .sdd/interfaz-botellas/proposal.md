# Propuesta: interfaz-botellas

## Por qué

Quieres que Bodega se organice como CrossOver. Hoy cada botella tiene una sola aplicación y la configuración está en otra pantalla, y eso esconde cosas reales: Muck está instalado dentro de tu botella `steam` y Bodega no lo ve.

## Qué

**La botella pasa a ser el centro,** con la colocación de CrossOver:

```
┌──────────┬───────────────────────────────┬─────────────────┐
│ Biblioteca│ steam              · Abierta │ ▾ Acciones       │
│ Instalar │                               │   Ejecutar…      │
│          │  [Steam]   [Muck]             │   Abrir C:       │
│ BOTELLAS │                               │ ▾ Configuración  │
│ • steam  │                               │   Gráficos  [▾]  │
│   games  │                               │   msync     (•)  │
│          │                               │ ▾ Paneles        │
│ + Nueva  │                               │ ▾ Detalles       │
│ Backends │                               │   Logs           │
│ Preferen.│                               │                  │
└──────────┴───────────────────────────────┴─────────────────┘
```

**Por hitos, cada uno compilable y probado por ti:**

| Hito | Qué entrega |
|---|---|
| **1. Varias aplicaciones y pantalla principal** | Varias aplicaciones por botella; detección por `.lnk`; juegos de Steam; iconos reales; barra lateral con botellas; pantalla de botella; Biblioteca con todo |
| **2. Ajustes y opciones** | Columna derecha completa: alta resolución, DLSS, AVX, versión de Windows, paneles de control, terminal, abrir C:. `Ejecutar con opciones`. Instalar en una botella existente o con un instalador local |
| **3. Gestión** | Nueva botella, duplicar, renombrar, exportar, importar y Preferencias (carpeta, caché y tema) |

## Fuera de alcance

- **Para el SDD de motor:** GStreamer, SDL2, dependencias tipo VC++/.NET, Epic y GOG, backend distinto por juego dentro de Steam, y actualizar botellas cuando cambia el motor.
- **Sin propósito aquí:** registro, calificaciones, estrellas y publicar botellas.
- **Más adelante, si hace falta:** arrastrar `.exe`, abrirlos desde Finder, lanzadores `.app` en el Dock, cierre suave de una botella y las bibliotecas de Steam en otras carpetas.
- **Ventana translúcida de macOS:** pide un plugin nativo, y la barra lateral puede ir con un color de superficie.

## Impacto

- **`packages/engine`:** `app.json` pasa a `apps.json` sin perder datos; funciones nuevas con sus tests. `bodega open <botella>` sigue abriendo lo mismo.
- **`apps/bodega`:** cambian la barra lateral, las rutas y Biblioteca. Sale la lista `/bottles`, y el detalle de botella se rehace. Se conservan Catálogo, Backends, el panel de instalación y el primer arranque.
- **`.claude/CLAUDE.md`:** deja claro qué se toma de CrossOver.
- **Tus botellas:** `steam` y `games` siguen funcionando sin reinstalar.

## Decisiones

| # | Tema | Decisión | Coste |
|---|---|---|---|
| 1 | Qué se toma de CrossOver | Organización y funciones. Nada de iconos, nibs, datos ni textos propios suyos | Se parecerá sin ser igual |
| 2 | Aspecto | Paleta burdeos y tema propios | Tema claro y oscuro siguen siendo nuestros |
| 3 | Biblioteca | Se queda como primera entrada, con las aplicaciones de todas las botellas | CrossOver no la tiene: es una mejora |
| 4 | Detección | `.lnk` y manifiestos de Steam se leen al listar, sin guardarse | Un acceso directo raro puede colarse: por eso existe `Ocultar` |
| 5 | Estado `Abierta` | Por botella, como el `Estado` de CrossOver | Con dos aplicaciones en una botella abierta, ambas lo muestran |
| 6 | Abrir | Doble clic o Intro en la pantalla de botella; botón `Abrir` en Biblioteca | Un clic suelto no lanza un juego por error |
| 7 | Backends | Entrada al fondo de la barra lateral | Es algo que CrossOver no necesita porque los trae dentro |
| 8 | Iconos | Del `.exe`, sin dependencias y con caché | El logo de marca queda para lo no instalado |
| 9 | Juegos de Steam | Se abren con `steam.exe -applaunch <id>` y usan el backend de Steam | Elegir otro backend por juego queda para el SDD de motor |
| 10 | Copia y exportación | `cp -cR` y `tar`, del sistema | Sin formato propio: un `.tar.gz` normal |

## Riesgos

- **`-applaunch` sin probar:** tiene ventana, así que lo pruebas tú (U3). Si falla, los juegos de Steam se quedan visibles pero abren Steam.
- **HUD de Metal:** `--hud` no mostró contador en Blur. Se prueba con Muck (U7). Si no sale, el interruptor se quita, porque uno que no hace nada engaña.
- **DLSS y alta resolución:** solo se puede comprobar que se escriben los valores. El efecto lo juzgas tú con un juego, y DLSS quizá no se pueda probar.
- **Es grande:** hito 1 toca el motor y 35 archivos de la app. Va por hitos, y no se empieza el siguiente sin tu prueba.
- **Instalación desde la app:** U3 del cambio anterior sigue sin confirmar, y este cambio la toca en el hito 2.
