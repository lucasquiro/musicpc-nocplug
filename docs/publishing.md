# Publishing MusicPC

EN: Checklist and repository layout for publishing MusicPC through Noctalia.
ES: Lista de comprobación y estructura del repositorio para publicar MusicPC en Noctalia.

## Current package

This standalone repository is the plugin package. Its publication files belong at the root:

```text
musicpc-nocplug/
├── plugin.toml
├── README.md
├── thumbnail.webp
├── LICENSE
├── service.luau
├── widget.luau
├── panel.luau
├── translations/
├── assets/
├── lib/
└── docs/
```

The thumbnail belongs next to `plugin.toml`, not inside `assets/`. The included image is a 960x540 WebP screenshot of the plugin interface, matching the community thumbnail requirements.

## Community catalog submission

To submit MusicPC to `noctalia-dev/community-plugins`, put the package in a top-level directory named `musicpc-nocplug`, matching the suffix of the manifest ID `lucasquiro/musicpc-nocplug`. That community repository generates its root `catalog.toml` through CI. Do not add that generated catalog to this standalone repository or put the standalone repo's files directly at the root of a community-repository pull request.

The community README requirements are reflected in `README.md`: it lists exact plugin and entry IDs, gives the panel-toggle command, names each declared dependency, and explains subprocess and filesystem behavior. There are no plugin settings, so a Settings section is not required.

For the community submission package, do not copy local development support files such as `.vscode/` or the vendored `noctalia.d.luau` API snapshot. The official community instructions ask developers to fetch that API definition locally rather than commit it as a second source of truth.

The community instructions also require `translations/en.json` as the committed translation source and handle other locales separately. This standalone repository currently includes `translations/es.json` for its Spanish users; review the current translation policy before including that file in a community pull request.

## Pre-submission checks

- Keep the manifest ID, community directory suffix, README IDs, and panel command in sync.
- Use catalog tags accepted by the community repository.
- Keep `thumbnail.webp` in the plugin root and confirm it is a 960x540 WebP.
- Bump the manifest version and update `CHANGELOG.md` for each published change.
- Keep the package below the community repository's 200-file limit.
- Describe commands spawned and files read or written in the pull request.

The current package uses version `0.2.3` and API level 34. Its file count remains below the 200-file limit. Its manifest declares `mpc`, `python3`, `ffmpeg`, and `gio`; metadata saving writes MP3 tags and may rename a file, while deletion moves a file to the desktop trash.

## Repository

The canonical standalone repository is <https://github.com/lucasquiro/musicpc-nocplug>. Creating this repository alone does not add the plugin to the Noctalia store; a community repository pull request is required for that listing.