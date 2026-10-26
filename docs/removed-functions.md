# Removed mpc API Audit

EN: Records the dynamic-access search and evidence for each removed mpc client function.
ES: Registra la búsqueda de accesos dinámicos y la evidencia de cada función mpc eliminada.

The API reduction was based on a repository-wide search of Luau consumers and dynamic access patterns before editing `lib/mpd/client.luau`.

```text
rg -n 'mpc\[' --glob '*.luau' .  -> no matches
rg -n 'M\[' --glob '*.luau' .    -> no matches
```

All `require` calls found before the change used literal relative `.luau` paths; no constructed `require` path was found. The remaining wrapper consumers were `panel.luau` and `lib/playlists/operations.luau`, and their direct calls use only `play`, `move`, `add`, `del`, `seekPercent`, `clear`, `load`, `save`, and `addplaylist`. `M.run` remains as the client's internal reusable executor.

Each line below records one removed public function and why no repository consumer depended on it:

| Removed function | Evidence |
| --- | --- |
| `runFormat` | No reference outside its definition in the old `mpc.luau`. |
| `status` | No call in any plugin entry or module; the poller invokes `noctalia.runAsync` directly. |
| `current` | No call in any plugin entry or module. |
| `queued` | No call in any plugin entry or module. |
| `stats` | No call in any plugin entry or module. |
| `version` | No call in any plugin entry or module. |
| `clearerror` | No call in any plugin entry or module. |
| `pause` | No call in any plugin entry or module; playback actions invoke argv directly. |
| `pauseIfPlaying` | No call in any plugin entry or module. |
| `toggle` | No call in any plugin entry or module; playback actions invoke argv directly. |
| `stop` | No call in any plugin entry or module. |
| `next` | No call in any plugin entry or module; player actions invoke argv directly. |
| `prev` | No call in any plugin entry or module; player actions invoke argv directly. |
| `cdprev` | No call in any plugin entry or module. |
| `seek` | No call in any plugin entry or module; the UI uses `seekPercent`. |
| `seekthrough` | No call in any plugin entry or module. |
| `searchplay` | No call in any plugin entry or module. |
| `random` | No call on the mpc client; the player-action module invokes argv directly. |
| `repeatMode` | No call on the mpc client; the player-action module invokes argv directly. |
| `consume` | No call in any plugin entry or module. |
| `single` | No call on the mpc client; the player-action module invokes argv directly. |
| `crossfade` | No call in any plugin entry or module. |
| `mixrampdb` | No call in any plugin entry or module. |
| `mixrampdelay` | No call in any plugin entry or module. |
| `replaygain` | No call in any plugin entry or module. |
| `volume` | No call in any plugin entry or module. |
| `playlist` | No call in any plugin entry or module; `playlist` is invoked directly by the poller. |
| `insert` | No call in any plugin entry or module. |
| `crop` | No call in any plugin entry or module. |
| `shuffle` | No call in any plugin entry or module. |
| `prio` | No call in any plugin entry or module. |
| `lsplaylists` | No call on the client; the poller invokes the command directly. |
| `rm` | No call in any plugin entry or module. |
| `renplaylist` | No call in any plugin entry or module. |
| `delplaylist` | No call in any plugin entry or module. |
| `clearplaylist` | No call in any plugin entry or module. |
| `moveplaylist` | No call in any plugin entry or module. |
| `listall` | No call on the client; the media helper invokes `mpc listall` directly. |
| `ls` | No call in any plugin entry or module. |
| `lsdirs` | No call in any plugin entry or module. |
| `list` | No call in any plugin entry or module. |
| `search` | No call in any plugin entry or module. |
| `find` | No call in any plugin entry or module. |
| `searchadd` | No call in any plugin entry or module. |
| `findadd` | No call in any plugin entry or module. |
| `update` | No call on the client; the media helper invokes the command directly. |
| `rescan` | No call in any plugin entry or module. |
| `sticker` | No call in any plugin entry or module. |
| `outputs` | No call in any plugin entry or module. |
| `enable` | No call in any plugin entry or module. |
| `disable` | No call in any plugin entry or module. |
| `toggleoutput` | No call in any plugin entry or module. |
| `outputset` | No call in any plugin entry or module. |
| `moveoutput` | No call in any plugin entry or module. |
| `partitions` | No call in any plugin entry or module. |
| `makepart` | No call in any plugin entry or module. |
| `delpart` | No call in any plugin entry or module. |
| `mount` | No call in any plugin entry or module. |
| `unmount` | No call in any plugin entry or module. |
| `listneighbors` | No call in any plugin entry or module. |
| `channels` | No call in any plugin entry or module. |
| `sendmessage` | No call in any plugin entry or module. |

`closePanel` was also removed from the queue panel: there was no UI callback string or internal call naming it. No Noctalia lifecycle callback was removed.

The old client's private `onOff` and `runEstado` helpers and its local `run` alias were removed with the unused mode commands. Evidence: their only consumers were removed client methods; the reduced client calls `M.run` directly and defines no dynamic access path.
