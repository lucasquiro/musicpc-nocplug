# MusicPC

EN: User guide, installation instructions, state contract, and project map for MusicPC.
ES: Guía de uso, instalación, contrato de estado y mapa del proyecto MusicPC.

MusicPC es un plugin de Noctalia para controlar un servidor MPD mediante `mpc`. Incluye un reproductor compacto en la barra y un panel con vistas de cola, playlists, biblioteca y edición de metadatos MP3. No reproduce audio por sí mismo.

## Requisitos

- Noctalia v5.3.0 o posterior con soporte para `plugin_api = 34`.
- MPD configurado para el mismo usuario que ejecuta Noctalia, y el comando `mpc`.
- `python3`, `ffmpeg` y `gio` para operaciones de biblioteca, carátulas, edición de etiquetas y papelera.
- El manifiesto declara `mpc`, `python3`, `ffmpeg` y `gio` como dependencias externas. No se requieren paquetes Lua adicionales.

## Instalación y uso

Instala el directorio del plugin mediante el flujo de plugins locales de Noctalia o una fuente compatible y activa `lucasquiro/musicpc-nocplug`. Añade el widget `lucasquiro/musicpc-nocplug:player` a una barra. La conexión a MPD y la biblioteca musical se configuran fuera del plugin, en MPD y `mpc`.

El título del widget abre el panel. Sus pestañas son Cola, Playlists y Biblioteca. La cola permite reproducir, buscar una posición, reordenar pistas, gestionar playlists y quitar canciones. La biblioteca está paginada y permite añadir pistas a la cola. Usa el botón de recarga de Biblioteca después de cambiar archivos en el disco; espera a que MPD actualice su índice. Al hacer clic derecho en una pista se puede editar sus metadatos MP3 o moverla a la papelera del escritorio. El editor usa la misma superficie del panel y al cerrarse o guardar restaura la vista anterior. La edición solo admite archivos MP3.

## Ajustes

MusicPC no declara ajustes propios. Noctalia ofrece los controles estándar de ubicación del panel. Configura el servidor MPD y `music_directory` en MPD. La caché de carátulas se guarda en el directorio de datos del plugin.

El panel dibuja como máximo 40 filas de cola, 30 nombres de playlist y 25 canciones por página de biblioteca. Son límites de renderizado; no alteran la cola ni la biblioteca de MPD.

## Solución de problemas

- **MPD desconectado:** Comprueba que MPD esté activo y que `mpc status` funcione en una terminal con el mismo usuario que Noctalia. Revisa `MPD_HOST`, `MPD_PORT` o la configuración MPD del usuario.
- **Biblioteca vacía:** Comprueba `music_directory` en `mpd.conf`, ejecuta `mpc update` y confirma que `mpc listall` devuelve pistas.
- **No aparece la carátula:** MPD debe ofrecer datos mediante `readpicture` o `albumart` para esa canción. La carátula es opcional y no afecta a la reproducción.
- **Falla la edición de metadatos:** El editor solo acepta MP3 dentro de la biblioteca MPD. Comprueba que estén disponibles `ffmpeg` y `python3` y que el usuario pueda escribir en la biblioteca.
- **No se puede mover a la papelera:** Comprueba que `gio` esté instalado y que el sistema de archivos tenga una implementación de papelera de escritorio.

## Cómo se comunican las partes

Noctalia ejecuta `service.luau`, `widget.luau` y `panel.luau` en máquinas virtuales Luau separadas. No comparten variables locales ni cachés de módulos. Las entradas intercambian datos simples mediante `noctalia.state`. El panel de cola carga el controlador del editor y dibuja ambas vistas en la misma superficie, evitando abrir un segundo panel al editar metadatos.

El servicio publica la tabla `player`:

| Campo | Significado |
| --- | --- |
| `state` | Estado de MPD: normalmente `playing`, `paused`, `stopped` u `offline`. |
| `artist`, `title`, `file` | Metadatos y ruta de biblioteca MPD de la pista actual. |
| `position` | Posición actual en la cola, desde 1; `0` cuando no hay pista seleccionada. |
| `count` | Cantidad de pistas en la cola. |
| `random` | Indica si el modo aleatorio está activo. |
| `repeatMode` | `off`, `all` para repetir la cola o `one` para repetir la pista. |

Las claves relacionadas son `player.progress` (`elapsed`, `total`, `percent`), `player.queue` (registros de pistas) y `player.playlists` (nombres de playlists guardadas). El widget y el panel observan esas claves. El panel solicita actualizaciones incrementando `player.queueRefresh`; las acciones optimistas usan `player.optimisticUntil`. El editor se coordina mediante `musicpc.editTrack`, `musicpc.updatedTrack`, `musicpc.panelOpen` y `musicpc.closeRequest`.

## Estructura del proyecto

```text
musicpc-nocplug/
├── plugin.toml                 # Identidad, nivel API, dependencias y entradas de Noctalia.
├── thumbnail.webp              # Imagen WebP de 960x540 para la tienda.
├── LICENSE                     # Licencia MIT.
├── CHANGELOG.md                # Historial de versiones.
├── README.md                   # Guía en inglés y mapa del proyecto.
├── leeme.md                    # Esta guía en español y mapa del proyecto.
├── service.luau                # Entrada del servicio; carga el sondeador MPD.
├── widget.luau                 # Entrada del widget de controles de barra.
├── panel.luau                  # Entrada del panel con callbacks globales del host.
├── noctalia.d.luau             # Definiciones para Luau LSP; marca APIs posteriores al nivel 34.
├── translations/               # Textos en inglés y español para controles y mensajes del plugin.
│   ├── en.json                 # Traducciones en inglés.
│   └── es.json                 # Traducciones en español.
├── assets/                     # Recursos de imagen usados durante la ejecución.
│   ├── frames/                 # Fotogramas que carga panel.luau.
│   │   ├── sleep_back/         # Transición hacia la pose de reposo.
│   │   └── wake/               # Transición hacia la pose activa.
│   └── source/                 # GIF originales locales, excluidos por Git.
│       └── .gitignore          # Excluye los GIF fuente de Git.
├── lib/                        # Módulos reutilizables, cacheados por VM de entrada.
│   ├── editor/controller.luau  # Estado, UI y flujo de guardado/cierre del editor integrado.
│   ├── media/media_files.py    # Validación de rutas, carátulas, etiquetas y papelera.
│   ├── metadata/editor_ops.luau # Adaptador argv asíncrono al helper Python.
│   ├── mpd/client.luau         # Cliente mínimo de comandos mpc con argv.
│   ├── mpd/poller.luau         # Sondeo MPD y publicación del estado compartido.
│   ├── panel/controller.luau   # Estado, vistas y acciones del panel de cola.
│   ├── player/actions.luau     # Acciones optimistas usadas por widget y panel.
│   └── playlists/operations.luau # Flujos de playlists compuestos con comandos mpc.
└── docs/                       # Notas de mantenimiento y referencia local de mpc.
    ├── .gitignore              # Excluye archivos de trabajo temporales.
    ├── architecture.md         # Runtime, estado, APIs y límites de render.
    ├── publishing.md           # Lista de comprobación para publicar en Noctalia.
    ├── mpc-commands.md         # Referencia en inglés para mpc 0.35.
    └── removed-functions.md    # Evidencia de funciones retiradas y búsqueda de accesos dinámicos.
```

## Desarrollo y pruebas

Las entradas permanecen en la raíz para que las rutas del manifiesto sean directas. Los módulos se cargan con rutas `.luau` relativas. Los comandos con nombres de archivos, playlists o rutas de pista usan arrays argv en vez de interpolación de shell.

Reinicia el plugin y alterna el panel de cola con:

```sh
noctalia msg plugins disable lucasquiro/musicpc-nocplug
noctalia msg plugins enable lucasquiro/musicpc-nocplug
noctalia msg panel-toggle lucasquiro/musicpc-nocplug:queue
```

Para probar el editor de metadatos, activa el plugin, abre el panel, entra a Biblioteca, haz clic derecho en una pista MP3 y elige Editar metadatos. Comprueba que el editor conserve la misma superficie del panel. Cambia una etiqueta o el nombre de archivo, guarda y comprueba que vuelva a la vista anterior y se actualice la biblioteca. Para probar la confirmación de reemplazo, escribe como nombre un basename MP3 existente; cancela primero si no deseas reemplazarlo.

La miniatura para la tienda de Noctalia es `thumbnail.webp` en la raíz del plugin. El repositorio está en [github.com/lucasquiro/musicpc-nocplug](https://github.com/lucasquiro/musicpc-nocplug). Para proponerlo en `noctalia-dev/community-plugins`, coloca los archivos del plugin en el directorio de primer nivel `musicpc-nocplug/`; ese repositorio genera su `catalog.toml` mediante CI, así que no debe añadirse a este repositorio individual.
