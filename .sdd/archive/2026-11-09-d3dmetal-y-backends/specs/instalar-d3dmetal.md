# Spec · Instalar D3DMetal eligiendo versión

## I1 · Versiones
- Lista fija en el motor: GPTK 3.0 (probada con Bodega) y 4.0 (beta, sin probar), cada una
  con su enlace oficial de Apple (3.0: el dmg directo; 4.0: la búsqueda de descargas).
- La tarjeta muestra la versión instalada, leída del `Info.plist` de
  `D3DMetal.framework` (`CFBundleShortVersionString`), o "No instalado".
- Solo en Mac (`capabilities.d3dmetal`). En Linux la tarjeta no existe, igual que hoy.

## I2 · Conseguir el dmg
- Busca en `~/Downloads` el `Game_Porting_Toolkit_<versión>*.dmg` más nuevo.
- Si no está: abre el enlace de Apple en el navegador y mira Descargas cada 3 s mientras
  espera ("Esperando la descarga…", con Cancelar). Los `.crdownload`/`.download` no cuentan.
- Siempre está "Ya lo tengo: elegir dmg…".
- Bodega nunca descarga el dmg por su cuenta (regla B2).

## I3 · Instalar desde el dmg
- Monta el dmg sin mostrarlo en Finder. Si dentro hay `redist/lib`, importa de ahí.
- Si dentro hay `Evaluation environment*.dmg`, lo abre con macOS (`open`): la ventana de
  Apple pide aceptar la licencia y **la acepta el usuario**. Bodega espera, hasta 5 min,
  un volumen con `redist/lib/external/D3DMetal.framework`.
- Importa con `importD3DMetal(<volumen>/redist)`: mismas comprobaciones y symlinks de hoy.
- Desmonta los dos volúmenes, también si algo falla.
- Reemplaza la versión que hubiera. Al acabar dice la versión instalada y lanza Comprobar.

## Escenarios
- **Dado** un dmg hecho con la estructura `redist/lib/{external,wine}`, **cuando** se
  instala, **entonces** D3DMetal queda importado (symlinks) y no queda nada montado. (test, Mac)
- **Dado** `~/Downloads` con `Game_Porting_Toolkit_3.0.dmg` y uno viejo, **entonces** se
  elige el más nuevo; un `.crdownload` no cuenta. (test)
- **Dado** el dmg real de Apple, **cuando** el usuario le da Instalar a 3.0, **entonces**
  sale la licencia de Apple, la acepta, y Comprobar da OK. (U)
- **Dado** que el usuario rechaza la licencia, **entonces** a los 5 min (o al Cancelar) sale
  "No se aceptó la licencia" y no queda nada montado. (U)
