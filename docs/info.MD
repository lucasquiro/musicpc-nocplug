# MusicPC

Plugin de Noctalia para controlar un reproductor MPD desde la barra y un panel
de cola. MusicPC no reproduce ni administra archivos de audio por sí mismo: lee
el estado de MPD y ejecuta acciones mediante el programa de consola `mpc`.

## Funciones

- Muestra el título actual y el control de reproducir/pausar en un widget de barra.
- Abre un panel con la información de la canción, progreso, controles y cola.
- Permite elegir una canción de la cola, avanzar o volver a la anterior y buscar
  una posición de la canción con el deslizador.
- Permite reordenar canciones arrastrando el control de tres líneas de cada fila.
- El menú contextual de una canción permite añadirla a una playlist existente,
  crear una playlist con esa canción o quitarla de la cola.
- Permite activar los modos aleatorio y repetir.
- Muestra las playlists guardadas, carga una playlist y guarda la cola actual
  como una playlist.
- Muestra el tiempo y el artista en la información emergente del widget.

## Requisitos

- Noctalia v5.3.0 con soporte para `plugin_api = 34` o posterior.
- MPD instalado, configurado y accesible desde el usuario que ejecuta Noctalia.
- El comando `mpc` instalado y configurado para conectarse a ese servidor MPD.

El manifiesto declara `mpc` como dependencia. La conexión a MPD y la biblioteca
musical se configuran fuera de MusicPC, en MPD y `mpc`.

## Estructura

- `plugin.toml`: identidad, versión, dependencia y entradas que Noctalia carga.
- `service.luau`: consulta el progreso cada segundo, escucha cambios de cola y
  playlists con `mpc idleloop` y separa los datos compartidos en varias claves.
- `widget.luau`: dibuja el control compacto de la barra y envía acciones a `mpc`.
- `panel.luau`: dibuja los controles detallados, la cola y las playlists.
- `noctalia.d.luau`: definiciones de tipos para el editor y `luau-lsp`; no es una
  parte ejecutable del plugin.
- `mpc.md`: referencia local de comandos disponibles en la versión de `mpc` del
  entorno donde se generó el archivo.
- `lib/player_actions.luau`: actualiza la interfaz al pulsar y ejecuta comandos
  idempotentes; MPD reconcilia el estado tras una ventana breve.
- `lib/playlist_ops.luau`: operaciones MPD de playlists, requerido solo cuando
  se usan esas acciones.
- `lib/metadata_editor.luau`: puente asíncrono con `media_files.py`, requerido
  solo al abrir o guardar el editor.

## Cómo se comunican las partes

Noctalia ejecuta el servicio, el widget y el panel en máquinas virtuales Luau
separadas. Por eso no comparten variables locales. El servicio guarda una tabla
de datos en `noctalia.state` con la clave `player`; widget y panel se suscriben
a esa clave y vuelven a dibujarse cuando cambia.

Las claves publicadas son `player`, `player.progress`, `player.queue` y
`player.playlists`. Cada una se actualiza solo si cambia su contenido. Separar el
progreso evita copiar la cola y las playlists en cada segundo; los consumidores
siguen redibujando su árbol UI cuando necesitan reflejar el progreso.

La clave `player` contiene:

| Campo | Significado |
| --- | --- |
| `state` | Estado de MPD: normalmente `playing`, `paused`, `stopped` u `offline`. |
| `artist`, `title`, `file` | Metadatos y ruta de la canción actual. |
| `position` | Posición actual en la cola, empezando por 1; 0 si no hay canción actual. |
| `random` | Indica si el modo aleatorio está activo. |
| `repeatMode` | Modo de repetición: `off`, `all` (cola) o `one` (canción actual). |

`player.progress` contiene `elapsed`, `total` y `percent`; las listas viven en
`player.queue` y `player.playlists`. `mpc idleloop` refresca cola y playlists al
detectar cambios. Como `runStream` no expone un callback de cierre, el servicio
también comprueba la cola cada 15 segundos y las playlists cada 60 segundos para
recuperarse de una desconexión.

El panel construye como máximo 40 filas de cola, 30 playlists y 25 canciones de
biblioteca por página. Python lee rutas de `mpc listall` hasta el rango necesario
para mostrar la página y verificar páginas próximas; solo las canciones de la
página activa se conservan y renderizan. «Añadir toda la biblioteca y reproducir»
permanece en la pestaña Cola y opera en MPD sin mostrar todas las canciones.
La ventana de cola se centra alrededor de la canción actual. Las filas se
conservan entre actualizaciones de progreso. Los frame ticks solo se activan
durante las transiciones de la mascota o el cierre del panel.

El log de Noctalia del 2026-10-26 registró timeouts del callback `showLibrary`
durante la construcción de la vista anterior, que admitía hasta 200 filas. El
panel se deshabilitó tras varios timeouts; el límite se redujo a 25 para acotar
esa carga.

## Controles

En la barra, el botón con el título abre el panel y el botón de reproducción
alternará entre reproducir y pausar. El widget también expone el botón de canción
anterior. En el panel están disponibles los controles anterior/siguiente,
reproducir/pausar, aleatorio, repetir, selección directa de canciones,
desplazamiento por la canción y gestión de playlists. En la cola, arrastra el
control de tres líneas para cambiar el orden y haz clic derecho en una canción
para añadirla a una playlist, crear una playlist o quitarla de la cola.

## Modificar el plugin

1. Para cambiar los textos, el diseño o las interacciones de la barra, editar
   `widget.luau`.
2. Para cambiar el diseño del panel o añadir controles, editar `panel.luau`.
3. Para cambiar la frecuencia de consulta, los comandos MPD o los datos publicados,
   editar `service.luau`. Mantener el formato de `player` alineado con lo que leen
   el widget y el panel.
4. `lib/` contiene lógica separada, pero `require` comparte la VM y el presupuesto
  de ejecución de su entrada. La carga perezosa evita cargar ese módulo hasta
  necesitarlo y mejora la organización; no crea procesos ni garantiza acelerar
  las operaciones una vez cargadas.
5. Para agregar o quitar entradas del plugin, cambiar `plugin.toml`.
6. Antes de usar una función nueva de Noctalia, comprobar su disponibilidad en
   `noctalia.d.luau` y en la documentación oficial.

Los comandos se ejecutan como argumentos separados, por ejemplo
`noctalia.runAsync({ "mpc", "play" })`. Mantener ese formato: no interpolar
nombres de canciones o playlists en comandos de shell.

## Recarga y pruebas

- Para reiniciar el plugin: `noctalia msg plugins disable lucasquiro/musicpc-nocplug`
  y después `noctalia msg plugins enable lucasquiro/musicpc-nocplug`.
- Para abrir o cerrar el panel de cola: `noctalia msg panel-toggle lucasquiro/musicpc-nocplug:queue`.
- Si el panel muestra MPD desconectado, comprobar que MPD esté activo y que `mpc`
  funcione desde una terminal con el mismo usuario.
- Los cambios en los scripts Luau pueden recargarse automáticamente; después de
  cambiar el manifiesto puede ser necesario desactivar y volver a activar el plugin.

## Referencias

- [Desarrollo de plugins de Noctalia](https://docs.noctalia.dev/noctalia/plugins/development/)
- [Plugins oficiales de Noctalia](https://github.com/noctalia-dev/official-plugins)