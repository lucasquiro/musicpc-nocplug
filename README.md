# MusicPC

MusicPC is a Noctalia plugin for controlling an MPD server with `mpc`. It provides a compact bar player and a queue panel with playlist, library, and MP3 metadata-editor views. It does not play audio itself.

## Plugin

| Field | Value |
| --- | --- |
| ID | `lucasquiro/musicpc-nocplug` |
| Entries | Bar widget: `player`; panel: `queue`; service: `mpd` |

## Requirements

- Install `mpc`, `python3`, `ffmpeg`, and `gio` and make them available on `PATH`.
- Configure MPD for the same user running Noctalia and ensure its music library is accessible.
- Noctalia v5.3.0 or later is required for `plugin_api = 34`.

## Usage

Enable `lucasquiro/musicpc-nocplug` and add its `player` widget to a bar. Click the widget to open its panel, or open the panel directly with:

```sh
noctalia msg panel-toggle lucasquiro/musicpc-nocplug:queue
```

The panel has Queue, Playlists, and Library tabs. The queue supports playback, seeking, reordering, playlist actions, and removing tracks. The paged library can add tracks to the queue. Use the Library refresh button after changing files on disk; it waits for MPD to rescan its database. Right-click a library track to edit its MP3 metadata or move it to the desktop trash. The editor uses the same panel surface and restores the previous view when closed or saved.

## Notes

- MusicPC runs `mpc`, `python3`, `ffmpeg`, and `gio` as local subprocesses. MPD handles playback and its server connection; MusicPC does not play audio itself.
- Artwork and metadata operations read files in MPD's music library. Saving metadata writes MP3 tags and may rename the selected file. The delete action moves files to the desktop trash using `gio`.
- Metadata editing is limited to MP3 files. Trash support depends on the desktop's `gio` trash implementation.
- Configure the MPD server and `music_directory` in MPD, not in MusicPC. The panel renders at most 40 queue rows, 30 playlists, and 25 library tracks per page.

## Troubleshooting

- **MPD disconnected:** Check that MPD is running and that `mpc status` works in a terminal under the same user as Noctalia. Check `MPD_HOST`/`MPD_PORT` or the user's MPD configuration.
- **Library is empty:** Check `music_directory` in `mpd.conf`, then run `mpc update` and confirm `mpc listall` returns tracks.
- **Artwork is missing:** MPD must provide `readpicture` or `albumart` output for the current track. Artwork is optional and does not affect playback.
- **Metadata editing fails:** The editor only accepts MP3 files inside the MPD library. Check that `ffmpeg` and `python3` are available and that the user can write the library directory.
- **File cannot be moved to trash:** Check that `gio` is installed and the file system has a desktop trash implementation.

## Architecture

Noctalia runs `service.luau`, `widget.luau`, and `panel.luau` in separate Luau VMs. Their local variables and module caches are isolated. Entries exchange plain data through `noctalia.state`. The queue panel requires the editor controller and renders both views on its own panel surface, so switching to metadata editing does not create a second panel.

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
├── thumbnail.webp              # 960x540 store card image.
├── thumbnail.webp              # 960x540 store card image.
├── LICENSE                     # MIT license.
├── CHANGELOG.md                # Version history.
├── README.md                   # English guide and project map.
├── docs/publishing.md          # Noctalia community submission checklist.
├── leeme.md                    # Spanish guide and project map.
├── service.luau                # Thin background-service entry; loads the MPD poller.
├── widget.luau                 # Thin bar surface for playback controls.
├── panel.luau                  # Thin panel entry exposing host callback names.
├── noctalia.d.luau             # Luau language-server definitions; includes marked APIs newer than 34.
├── translations/               # English and Spanish strings for plugin controls and UI messages.
│   ├── en.json                 # English translation bundle.
│   └── es.json                 # Spanish translation bundle.
├── assets/                     # Runtime image resources.
│   ├── frames/                 # Animation frames loaded by panel.luau.
│   │   ├── sleep_back/         # Transition to the idle pose.
│   │   └── wake/               # Transition to the active pose.
│   └── source/                 # Local-only original GIFs, ignored by Git.
│       └── .gitignore          # Keeps source GIF files out of Git.
├── lib/                        # Reusable implementation modules, cached per entry VM.
│   ├── editor/controller.luau  # Embedded editor form state, UI, and save/close workflow.
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

## Development

The plugin keeps entry scripts in the root so the manifest paths stay direct. Modules are loaded with relative `.luau` paths. All commands involving filenames, playlist names, and track paths use argv arrays rather than shell interpolation.

Restart the plugin and toggle the queue panel with:

```sh
noctalia msg plugins disable lucasquiro/musicpc-nocplug
noctalia msg plugins enable lucasquiro/musicpc-nocplug
noctalia msg panel-toggle lucasquiro/musicpc-nocplug:queue
```

To test metadata editing, enable the plugin, open the queue panel, choose Library, right-click an MP3 track, and select Edit metadata. Verify the editor remains anchored to the same panel surface. Change a tag or the filename, save, and verify that the previous queue view returns and the library refreshes. To exercise overwrite handling, set the filename to an existing MP3 basename and confirm the replacement prompt; cancel first if you do not intend to replace that file.

The repository is [github.com/lucasquiro/musicpc-nocplug](https://github.com/lucasquiro/musicpc-nocplug). The store thumbnail is `thumbnail.webp` in this plugin's root directory. To submit the plugin to `noctalia-dev/community-plugins`, place its files in the top-level `musicpc-nocplug/` directory; that repository generates its root `catalog.toml` with CI, so do not add that catalog here.
