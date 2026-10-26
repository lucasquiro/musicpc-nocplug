# MusicPC Architecture

EN: Maintainer architecture reference for the MusicPC entries and modules.
ES: Referencia de arquitectura para mantenimiento de las entradas y módulos de MusicPC.

This document describes the `0.2.0` code layout and the compatibility boundary. The manifest keeps the canonical ID `lucasquiro/musicpc-nocplug` and `plugin_api = 34`, matching the supported Noctalia v5.3.0 baseline.

## Runtime boundaries

Noctalia starts `service.luau`, `widget.luau`, `panel.luau`, and `editor.luau` in separate Luau VMs. They cannot share local variables or module instances. A `require` cache belongs to one entry VM, so a module imported by both the widget and panel executes once in each VM. Entries communicate through plain values in `noctalia.state`.

The root entry scripts remain at the plugin root. Each manifest `entry` points to one of those `.luau` files. Module imports are relative paths beginning with `./` or `../` and ending in `.luau`. Editor operations are lazy: the editor controller loads the metadata adapter only when it opens the selected track; playlist operations are loaded by the queue panel when needed.

## State contract

The MPD poller publishes these public player values:

| Key | Shape and owner |
| --- | --- |
| `player` | `state`, `artist`, `title`, `file`, `position`, `count`, `random`, `repeatMode`. Published by the poller; watched by the widget and panel. |
| `player.progress` | `elapsed`, `total`, `percent`. Published separately to avoid copying queue data every second. |
| `player.queue` | Array of `{ artist, title, file }` records. Refreshed after MPD playlist events and periodically. |
| `player.playlists` | Array of saved playlist names. Refreshed after stored-playlist events and periodically. |
| `player.queueRefresh` | Numeric request token incremented by panel/editor actions. The poller watches for changes and refreshes queue and playlists. |
| `player.optimisticUntil` | Millisecond deadline during which the poller avoids replacing optimistic playback state with stale MPD output. |
| `musicpc.editTrack` | Library-relative path selected for the editor. |
| `musicpc.updatedTrack` | `{ old, new }` record used by the panel to invalidate its library page after a rename. |
| `musicpc.panelOpen` | Boolean set by the queue panel and read by the bar widget. |
| `musicpc.closeRequest` | Numeric request token used by the widget to ask the panel to close. |

The player `state` is normally `playing`, `paused`, `stopped`, or `offline`. `position` starts at 1; it is 0 when no track is selected. `count` is the queue length. `repeatMode` is `off`, `all` (repeat the queue), or `one` (repeat the current track).

## Process execution

The service and UI use `noctalia.runAsync` with argument arrays. MPD commands never interpolate track names, playlist names, or file paths into a shell string. The panel invokes the Python helper as an argv list equivalent to:

```lua
{ "python3", pluginDir .. "/lib/media/media_files.py", action, ... }
```

The helper validates library-relative paths before reading/writing tags or moving files to trash. It uses `ffprobe`/`ffmpeg` and `gio` with argument arrays. Its artwork and paged-library actions are optional; missing artwork does not affect playback.

## Rendering limits

The panel renders at most 40 queue rows, 30 playlist names, and 25 library tracks per page. It centers a queue window around the current track for long queues. The Python helper scans only far enough to produce the requested library page and discover nearby pagination. These bounds limit UI tree construction; they do not change MPD data.

The panel uses a fixed `400 x 480` manifest surface and keeps its list viewport bounded. Do not use `height = "content"` or `max_height`: both require plugin API 42. Image paths such as `assets/frames/music/f_000.png` resolve from the plugin root.

## API compatibility

The manifest remains at API 34. The plugin's core used APIs are cumulative levels 5 (panel drag/drop), 9 (closure callbacks in UI), 12 (`nowMs`), 18 (panel frame ticks), 22 (`require` modules), 24 (argv `runAsync`), 28 (panel context menus), 32 (container/image tooltips), and 33 (`ui.scroll.revealKey`). Level 34 is preserved as requested; no API 35+ runtime feature is used.

`noctalia.d.luau` contains reference declarations through API 43. Its API 35+ declarations are marked so they are not mistaken for capabilities usable under this manifest: idle notifications (35), layers (36), calendar events (37), bar drag/drop additions (38), OSD (39), pixel streams (40), color picker (41), and content-sized panels (42). The file is editor support only and does not grant runtime capabilities.

## Publishing status

The package has a manifest, English and Spanish guides, translations, an MIT license, and version `0.2.0`. A `thumbnail.webp` and the Git repository URL are still pending. A standalone Git source repository needs its documented root `catalog.toml`; a contribution to `noctalia-dev/community-plugins` instead follows that repository's submission rules and catalog automation. The original GIF files live in `assets/source/` and are ignored; the PNG animation frames are runtime assets and must stay in the package.
