# Pixel Spaces Manager — Room Decorator & Delivery

Juego 2D top-down en Godot 4.7 con los assets *Pixel Spaces* (versión gratuita) de Netherzapdos.

## Controles
- Mover: WASD / flechas / stick izquierdo (8 direcciones)
- Interactuar: E / Espacio / botón A (las computadoras se encienden manteniendo pulsado)
- Pausa: ESC / P / Start

## Niveles (25)
Los escenarios rotan: Habitación (1, 4, 7...), Oficina (2, 5, 8...) y Calle (3, 6, 9...).
Los niveles 1-3 son el tutorial; los 4-25 se generaron con `tools/build_levels.gd` y la dificultad sube así:

| Escenario | Nivel 4-6 | Nivel 23-25 |
|---|---|---|
| Habitación | 5-6 objetos, mapa 24x14 | 10 objetos, mapa 34x17, 3 familiares estorbando |
| Oficina | 3-4 PCs (mantener 1.3 s) | 6 PCs (mantener 1.9 s), 4 compañeros caminando |
| Calle | 4 entregas, 2 carriles | 6 entregas, 4 carriles con camellón, autos más rápidos, 8 peatones |

- Desde el nivel 10, dejar un objeto en el mueble equivocado resta 2 s (3 s desde el 19).
- El tiempo límite se calcula con la distancia real de cada recorrido (pathfinding A*) multiplicada
  por un margen que se reduce de x2.3 a x1.35 conforme avanzan los niveles.
- Estrellas: 3 si sobra ≥40% del tiempo, 2 si sobra ≥20%, 1 si solo terminas.
- Cada nivel completado desbloquea el siguiente. Para probar todos, pon `UNLOCK_ALL = true` en `GameManager.gd`.

Puntaje: 100 por tarea + 10 por cada segundo sobrante. Récords, estrellas y progreso se guardan en `user://save.cfg`.

## Usuarios
- Cada usuario tiene su propio avance (niveles desbloqueados, récords y estrellas), guardado en `user://save.cfg`
  dentro de `[profiles]`. **Usuario nuevo = empieza desde el nivel 1; usuario existente = carga su avance.**
- Menú → **Cambiar**: lista de usuarios con su avance o campo para escribir uno nuevo (avisa si ya existe).
- Si un usuario no está en `save.cfg` pero tiene victorias en `ranking.db`, su avance se reconstruye desde SQLite.
- Los nombres no distinguen mayúsculas ("ana" = "Ana"). Un `save.cfg` de versiones anteriores se convierte solo.

## Ranking (SQLite) y logs
- **Ranking:** usa el addon [godot-sqlite](https://github.com/2shady4u/godot-sqlite) v4.9 (incluido en `addons/godot-sqlite`, licencia MIT).
  El autoload `Database` crea `ranking.db` con las tablas `players` y `scores`. Cada victoria se guarda con
  jugador, nivel, puntaje, estrellas y tiempo. El menú muestra el ranking general (suma del mejor puntaje
  de cada nivel por jugador) y el de cada nivel; el panel de victoria muestra tu puesto.
- **Logs:** el autoload `GameLog` escribe `logs/game_AAAA-MM-DD.log` (un archivo por día, se guardan 14) con
  inicio de sesión, cambios de escena, tareas, golpes, objetos mal colocados, pausas, victorias, derrotas y errores de la base de datos.
- **Ubicación en Windows:** `%APPDATA%\Godot\app_userdata\Pixel Spaces Manager\` (botón "Abrir carpeta de datos" en el ranking).
- Para inspeccionar la base de datos puedes usar [DB Browser for SQLite](https://sqlitebrowser.org/).

## Telemetría y dashboard de desarrollo
- Además del ranking, `ranking.db` guarda **todas** las partidas en `attempts` (victoria, derrota o abandono)
  y sus eventos en `events` (golpes, errores, tareas, pausas, con segundo y posición en el mapa).
- También guarda el **recorrido** del jugador (posición cada 0.2 s) en la tabla `paths`.
- **Dashboard de desarrollo** (`tools/dashboard/`): en modo debug el juego lo instala en su carpeta de datos y
  lo mantiene actualizado tras cada partida. Se abre desde **Ranking → Dashboard** (botón visible solo en debug)
  y permite reproducir el recorrido de cualquier partida sobre el mapa. Ver `tools/dashboard/LEEME.md`.

## Herramientas (carpeta tools/)
- `BuildLevels.tscn`: regenera los niveles 4-25 (ejecútala con F6). Cada nivel usa una semilla fija, así que siempre sale igual.
- `BotTest.tscn`: un bot juega los 25 niveles con física real y reporta si gana y cuánto tiempo le sobra.
  Con las variables SKILL, WRONG, RETRIES y ABANDON simula jugadores de distinta habilidad (ver `run_bots.sh`).

## Estructura
- `assets/` sprites del pack, tileset propio 16x16, fuentes pixel (OFL), audio chiptune generado, tema de UI.
- `scenes/ui/` LoadingScreen, MainMenu, HUD, PauseMenu
- `scenes/player/` Player
- `scenes/objects/` PickupItem, DropZone, Computer, PackageDepot, Car, Pedestrian
- `scenes/levels/` Level1-3 (TileMapLayer + Entities con Y-Sort)
- `scripts/autoload/` GameManager (tiempo, tareas, puntaje, flujo) y AudioManager

## Licencias
- Pixel Spaces (Netherzapdos): solo uso NO comercial. Ver `assets/sprites/LICENSE_PixelSpaces.txt`.
- Fuentes Press Start 2P y Silkscreen: SIL Open Font License.
