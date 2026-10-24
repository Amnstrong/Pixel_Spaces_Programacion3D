# Dashboard de telemetría (solo para desarrollo)

## Uso normal: conectado al juego (se actualiza solo)
1. Ejecuta el juego desde el editor de Godot (F5).
2. En el menú: **Ranking → Dashboard**. Se abre en el navegador desde la carpeta de datos del juego.
3. Juega: al terminar cada partida (gane, pierda o abandone) el juego reescribe `dashboard_data.js`
   y la página lo vuelve a leer cada 3 segundos. Arriba verás "En vivo" y un aviso con cada partida nueva.

Cómo funciona: en modo debug (`OS.is_debug_build()`), el autoload `Database` copia este `dashboard.html` a
`user://dashboard/` y escribe ahí `dashboard_data.js` con todas las partidas, eventos y recorridos.
En una exportación release no se crea nada y el botón Dashboard no aparece.

## Recorridos
El juego guarda la posición del jugador cada 0.2 s (tabla `paths`). En el detalle de cada nivel puedes
reproducir cualquier partida sobre el mapa: rastro, objeto que lleva, tareas, golpes y errores en el momento
en que ocurrieron. Por defecto es un resumen de 8 s; también hay tiempo real y x3, una barra para moverte y
la lista de lo que pasó (clic en un evento para saltar a ese momento). "Mostrar todos los recorridos del nivel"
superpone las rutas de todas las partidas. Haz clic en una fila de la tabla Partidas para reproducirla.

## Sin el juego
También puedes abrir `dashboard.html` con doble clic y arrastrar `ranking.db` y los `game_*.log`, o pulsar
**Ver datos de ejemplo** (108 partidas con recorridos jugadas por 5 bots de distinta habilidad).
En ese modo los datos no se actualizan solos.

Carpeta de datos en Windows: `%APPDATA%\Godot\app_userdata\Pixel Spaces Manager\`
(`ranking.db`, `logs/`, `dashboard/`). Esta carpeta `tools/` no se incluye al exportar el juego.
