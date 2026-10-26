# MusicPC

EN: User guide, installation instructions, state contract, and project map for MusicPC.
ES: Guía de uso, instalación, contrato de estado y mapa del proyecto MusicPC.

MusicPC is a Noctalia plugin for controlling an MPD server with `mpc`. It provides a compact bar player, a queue panel with playlist and library views, and a separate editor for MP3 tags. It does not play audio itself.

## Requirements

- Noctalia v5.3.0 or later with support for `plugin_api = 34`.
- MPD configured for the same user that runs Noctalia, plus the `mpc` command.
- `python3`, `ffmpeg`, and `gio` for library file operations, artwork, tag editing, and trash support.
- The manifest lists `mpc`, `python3`, `ffmpeg`, and `gio` as external dependencies. No additional Lua packages are required.

## Install

Install the plugin directory using Noctalia's local plugin workflow or a compatible plugin source, then enable `lucasquiro/musicpc-nocplug`. Add the `lucasquiro/musicpc-nocplug:player` widget to a bar. MPD connection settings and the music library are managed by MPD and `mpc`, outside this plugin.

The widget title opens the queue panel. The panel has Queue, Playlists, and Library tabs. The queue supports play, seek, reordering, playlist actions, and removing tracks. The library is paged and can add a track to the queue. Right-clicking a library track opens actions for editing MP3 metadata or moving the file to the desktop trash. Metadata editing is limited to MP3 files.

## Settings

MusicPC does not declare plugin-specific settings. Noctalia provides the panel's standard placement controls. Configure the MPD server and `music_directory` in your MPD setup. The editor's artwork cache is stored in the per-plugin data directory.

The panel limits rendered content to 40 queue rows, 30 playlist names, and 25 library tracks per page. These are rendering limits; they do not alter the MPD queue or library.

## Troubleshooting

- **MPD disconnected:** Check that MPD is running and that `mpc status` works in a terminal under the same user as Noctalia. Check `MPD_HOST`/`MPD_PORT` or the user's MPD configuration.
- **Library is empty:** Check `music_directory` in `mpd.conf`, then run `mpc update` and confirm `mpc listall` returns tracks.
- **Artwork is missing:** MPD must provide `readpicture` or `albumart` output for the current track. Artwork is optional and does not affect playback.
- **Metadata editing fails:** The editor only accepts MP3 files inside the MPD library. Check that `ffmpeg` and `python3` are available and that the user can write the library directory.
- **File cannot be moved to trash:** Check that `gio` is installed and the file system has a desktop trash implementation.

## How the parts communicate

Noctalia runs `service.luau`, `widget.luau`, `panel.luau`, and `editor.luau` in separate Luau VMs. Their local variables and module caches are isolated. Entries exchange plain data through `noctalia.state`; a module imported by two entries is loaded once in each entry's VM.

The service publishes the `player` state table:

| Field | Meaning |
| --- | --- |
| `state` | MPD state such as `playing`, `paused`, `stopped`, or `offline`. |
| `artist`, `title`, `file` | Current track metadata and its MPD library-relative path. |
| `position` | Current 1-based queue position, or `0` when no track is selected. |
| `count` | Number of tracks in the queue. |
| `random` | Whether random mode is enabled. |
| `repeatMode` | `off`, `all` for queue repeat, or `one` for single-track repeat. |

Related keys are `player.progress` (`elapsed`, `total`, `percent`), `player.queue` (track records), and `player.playlists` (saved playlist names). The widget and panel watch these keys. The panel requests updates by incrementing `player.queueRefresh`; optimistic playback actions use `player.optimisticUntil`. Editor coordination uses `musicpc.editTrack`, `musicpc.updatedTrack`, `musicpc.panelOpen`, and `musicpc.closeRequest`.

## Project structure

```text
musicpc-nocplug/
├── plugin.toml                 # Plugin identity, API level, dependencies, and Noctalia entries.
├── LICENSE                     # MIT license.
├── CHANGELOG.md                # Version history.
├── README.md                   # English guide and project map.
├── leeme.md                    # Spanish guide and project map.
├── service.luau                # Thin background-service entry; loads the MPD poller.
├── widget.luau                 # Thin bar surface for playback controls.
├── panel.luau                  # Thin panel entry exposing host callback names.
├── editor.luau                 # Thin metadata-editor entry exposing Noctalia callbacks.
├── noctalia.d.luau             # Luau language-server definitions; includes marked APIs newer than 34.
├── translations/               # Plugin translation bundles (currently empty JSON objects).
│   ├── en.json                 # English translation bundle.
│   └── es.json                 # Spanish translation bundle.
├── assets/                     # Runtime image resources.
│   ├── frames/                 # Animation frames loaded by panel.luau.
│   │   ├── music/              # Music animation frames.
│   │   ├── sleep/              # Idle mascot frames.
│   │   ├── sleep_back/         # Transition back to sleep.
│   │   └── wake/               # Transition to wake.
│   └── source/                 # Local-only original GIFs, ignored by Git.
│       └── .gitignore          # Keeps source GIF files out of Git.
├── lib/                        # Reusable implementation modules, cached per entry VM.
│   ├── editor/controller.luau  # Editor form state, UI, and save/close workflow.
│   ├── media/media_files.py    # MPD library path validation, artwork, tags, and trash helper.
│   ├── metadata/editor_ops.luau # Asynchronous argv adapter to the Python metadata helper.
│   ├── mpd/client.luau         # Minimal argv-based mpc command client.
│   ├── mpd/poller.luau         # Background status, queue, playlist polling, and state publication.
│   ├── panel/controller.luau   # Queue panel state, views, and action handlers.
│   ├── player/actions.luau     # Optimistic playback actions shared by widget and panel.
│   └── playlists/operations.luau # Playlist workflows composed from mpc commands.
└── docs/                       # Maintainer notes and local mpc reference.
    ├── .gitignore              # Excludes local scratch documents.
    ├── architecture.md         # Runtime, state, API, and rendering constraints.
    ├── mpc-commands.md         # English reference for mpc 0.35 commands.
    └── removed-functions.md    # Evidence for removed wrapper functions and dynamic-access audit.
```

## Development and tests

The plugin keeps entry scripts in the root so the manifest paths stay direct. Modules are loaded with relative `.luau` paths. All commands involving filenames, playlist names, and track paths use argv arrays rather than shell interpolation.

Restart the plugin and toggle the queue panel with:

```sh
noctalia msg plugins disable lucasquiro/musicpc-nocplug
noctalia msg plugins enable lucasquiro/musicpc-nocplug
noctalia msg panel-toggle lucasquiro/musicpc-nocplug:queue
```

To test metadata editing, enable the plugin, open the queue panel, choose Library, right-click an MP3 track, and select Edit metadata. Change a tag or the filename, save, and verify that the panel returns to the queue and the library refreshes. To exercise overwrite handling, set the filename to an existing MP3 basename and confirm the replacement prompt; cancel first if you do not intend to replace that file.

For publishing, the plugin package still needs a `thumbnail.webp` and the repository URL. The publishing workflow's standalone source-repository catalog is a separate root-level `catalog.toml`; a community-plugins submission instead follows that repository's contribution instructions and catalog automation.
