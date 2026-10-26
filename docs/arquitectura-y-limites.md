# Arquitectura y límites

Documento de mantenimiento para MusicPC. La compatibilidad declarada es Noctalia v5.3.0 y `plugin_api = 34`.

## Compatibilidad Noctalia

El manifiesto fija `plugin_api = 34`, que es la última versión estable disponible en Noctalia v5.3.0 según la tabla oficial de versiones API. La API es acumulativa: el número declara el nivel mínimo requerido, no la versión instalada del shell.

Capacidades utilizadas y su nivel mínimo documentado:

| API | Capacidad | Uso en MusicPC |
| --- | --- | --- |
| 5 | `ui.dragSource` / `ui.dropZone` en paneles | Reordenar cola |
| 9 | Callbacks Luau como closures en UI | Callbacks de filas |
| 12 | `noctalia.nowMs()` | Ventana de reconciliación optimista |
| 18 | Ticks de cuadro de panel | Animaciones puntuales |
| 22 | `require` relativo de módulos `.luau` | Código de `lib/` |
| 24 | `runAsync` con argv | Ejecutar `mpc` y Python sin shell |
| 28 | `panel.openContextMenu` | Acciones contextuales |
| 34 | `hover_highlight` de widget | Capacidad disponible, no esencial para la lógica |

No se usan APIs 35 o superiores. En particular, la altura dinámica `height = "content"` y `max_height` requieren API 42; los paneles de MusicPC deben conservar `height` numérico fijo.

Referencias oficiales:

- [Manifest y settings](https://docs.noctalia.dev/noctalia/plugins/development/manifest/)
- [Entry scripts y módulos](https://docs.noctalia.dev/noctalia/plugins/development/entries/)
- [Declarative UI](https://docs.noctalia.dev/noctalia/plugins/development/declarative-ui/)
- [Runtime API](https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/)
- [Plugin API Versions](https://docs.noctalia.dev/noctalia/plugins/development/plugin-api/)

## Modelo de ejecución

Cada entrada (`service`, `widget`, `panel`, `editor`) corre en su propia VM Luau. No hay memoria local compartida entre entradas. `noctalia.state` copia valores simples y tablas de datos; no admite compartir funciones. Los módulos cargados con `require` se cachean dentro de su entrada y VM, así que sirven para separar responsabilidades, no para compartir objetos entre entradas.

Las llamadas de plugin tienen un presupuesto de ejecución. La documentación describe presupuestos por llamada, pero no publica un límite numérico universal; no se debe codificar contra una cifra no documentada. Un árbol declarativo grande, parseos extensos o callbacks que hacen trabajo repetido elevan el riesgo de excederlo.

El log de Noctalia del 2026-10-26 a las 03:34:48 registra que `showLibrary` y varios callbacks de estado excedieron el presupuesto; el panel se deshabilitó después de varios timeouts. La implementación anterior construía hasta 200 botones de Biblioteca, cada uno con closures para acciones. Reducir la lista a 25 limita la construcción y el render repetidos. El log también contiene una advertencia antigua de `ui.scroll` con más de 256 hijos; ese 256 es una observación de los logs, no un contrato público estable.

## Límites de render actuales

El panel aplica topes conservadores:

| Vista | Elementos máximos construidos |
| --- | ---: |
| Cola | 40 pistas, cerca de 120 controles fila antes del encabezado |
| Playlists | 30 entradas |
| Biblioteca | 25 entradas de la página activa |

Una fila de cola contiene varios controles por la funcionalidad de arrastrar y soltar; por eso su tope es distinto al número de hijos directos del `ui.scroll`. No se implementa virtualización real: se genera una ventana fija alrededor de la pista actual. Biblioteca muestra una página y el helper Python lee solo hasta poder descubrir tres páginas próximas y comprobar si hay otra; como `mpc listall` entrega rutas secuencialmente, llegar a páginas profundas requiere recorrer el prefijo anterior, pero no se almacena ni se renderiza. «Añadir toda la biblioteca y reproducir» actúa en MPD sin construir una vista de todas las pistas.

El panel de cola tiene altura fija de 480 px en `plugin.toml`. El área desplazable de las listas ocupa 220 px; conserva `ui.scroll` para navegar los elementos renderizados. Estos valores son decisiones de diseño para el panel actual, no límites de Noctalia.

Las barras del espectro se retiraron por generar actualizaciones visibles y coste de render sin valor suficiente en esta interfaz. No queda callback, estado, ajuste ni nodo de UI para el espectro.

## Estado y procesos

El servicio publica datos en claves separadas:

- `player`: estado, artista, título, archivo, posición, cantidad, aleatorio y repetir.
- `player.progress`: tiempo transcurrido, duración y porcentaje.
- `player.queue`: lista acotada por el render, no por el servicio.
- `player.playlists`: nombres de playlists.

La cola se solicita al detectar eventos de `mpc idleloop` y también tiene una comprobación de recuperación. Las playlists se refrescan bajo petición/evento y con menor frecuencia que el progreso. `runStream` está documentado como un proceso de larga duración con líneas de salida, pero no expone un callback de cierre; por ello el servicio conserva sondeos periódicos de recuperación.

Los comandos deben pasarse como argv, por ejemplo `{ "mpc", "play" }`. La forma argv de `runAsync` requiere API 24 y ejecuta el proceso sin parsing de shell. No concatenar nombres de pista, playlist, ni rutas en comandos shell.

## UI optimista

Los botones reproducir/pausar, anterior/siguiente, aleatorio y repetir actualizan primero `noctalia.state` y envían a continuación comandos MPD idempotentes. El servicio evita reconciliar el estado dentro de una ventana de 450 ms. Este intervalo reduce el parpadeo; no asegura que MPD haya completado la operación en ese tiempo. El sondeo/evento posterior del servidor sigue siendo la fuente de verdad.

## Editor de metadatos

El editor utiliza `python3` con argv y FFmpeg con argv, no arma comandos shell con datos del usuario. `media_files.py` valida que la pista esté dentro de la biblioteca y sea MP3, y que el nombre destino sea un basename con extensión MP3. Si el nombre nuevo ya existe, no lo reemplaza sin confirmación; tras la confirmación usa reemplazo atómico. El trabajo de FFmpeg corre en un proceso externo asíncrono respecto al panel.

## Diagnóstico

1. Leer el log actual de Noctalia en `~/.cache/noctalia/noctalia.log` y buscar la entrada `lucasquiro/musicpc-nocplug` junto a `ERR` o `WRN`.
2. Reproducir el error abriendo el panel y seleccionando Biblioteca; registrar la línea exacta, el callback y la línea de script que el log señale.
3. Si vuelve a desactivarse, probar temporalmente con un tope menor de Biblioteca y comprobar si el fallo desaparece. No inferir el motivo solo por la desactivación.
4. Después de modificar el manifiesto, desactivar y reactivar el plugin; los cambios Luau suelen poder recargarse.

La causa de la desactivación al abrir Biblioteca queda identificada por ese timeout de `showLibrary`; el límite de biblioteca se redujo de 200 a 25 y los espectadores de estado solo reconstruyen la lista cuando sus datos cambian. Los warnings de altura de panel a las 02:36 son anteriores a la última carga correcta (03:34) y no explican el fallo de Biblioteca.
