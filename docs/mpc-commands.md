# mpc Command Reference

EN: Documents mpc commands used by MusicPC and groups commands not exposed by its client.
ES: Documenta los comandos mpc usados por MusicPC y agrupa los que no expone su cliente.

This local reference describes the `mpc` 0.35 command-line client. MusicPC invokes commands as argument arrays; do not use shell interpolation for track paths, playlist names, or other values.

## MusicPC commands

| Command | Purpose in MusicPC |
| --- | --- |
| `mpc status` | Read playback state and progress. |
| `mpc -f FORMAT status` | Read status with artist, title, and file fields. |
| `mpc -f FORMAT playlist` | Read the current queue. |
| `mpc lsplaylists` | List saved playlists. |
| `mpc play [POSITION]` | Play or select a queue position. |
| `mpc add URI` | Add a track, directory, or `/` (whole library) to the queue. |
| `mpc del POSITION` | Remove a queue entry. |
| `mpc move FROM TO` | Reorder a queue entry. |
| `mpc seek PERCENT%` | Seek by percentage of the current track. |
| `mpc clear` | Empty the current queue before loading a saved playlist. |
| `mpc load NAME` | Load a saved playlist. |
| `mpc save NAME` | Save the current queue as a playlist. |
| `mpc addplaylist NAME URI` | Add a library track to a saved playlist. |
| `mpc random on\|off` | Set random mode. |
| `mpc single on\|off` | Set single-track mode. |
| `mpc repeat on\|off` | Set queue repeat mode. |
| `mpc next` / `mpc prev` | Advance or return one track. |
| `mpc idleloop EVENTS...` | Wait continuously for player, playlist, stored-playlist, or option changes. |
| `mpc readpicture URI` / `mpc albumart URI` | Return embedded artwork when MPD provides it. |
| `mpc listall` | Stream library paths for paged browsing. |
| `mpc update` | Ask MPD to rescan library metadata after file edits. |

## Other mpc 0.35 commands

The installed client may also provide these command groups; MusicPC does not currently expose them through its client module:

- Playback/status: `current`, `queued`, `stats`, `version`, `clearerror`, `pause`, `pause-if-playing`, `toggle`, `stop`, `cdprev`, `seekthrough`.
- Queue: `insert`, `crop`, `shuffle`, `prio`, `playlist`.
- Playlists: `rm`, `renplaylist`, `delplaylist`, `clearplaylist`, `moveplaylist`.
- Library search: `ls`, `lsdirs`, `list`, `search`, `find`, `searchadd`, `findadd`, `searchplay`, `rescan`.
- Modes and volume: `consume`, `crossfade`, `mixrampdb`, `mixrampdelay`, `replaygain`, `volume`.
- Outputs and partitions: `outputs`, `enable`, `disable`, `toggleoutput`, `outputset`, `moveoutput`, `partitions`, `makepart`, `delpart`.
- Mounts, messaging, and stickers: `mount`, `unmount`, `listneighbors`, `channels`, `sendmessage`, `sticker`.

Check `mpc help` or `man 1 mpc` for options and behavior specific to the installed version. MPD connection options can be configured in the user's MPD environment; MusicPC does not own or modify that configuration.
