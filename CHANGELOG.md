# Changelog

EN: Version history for MusicPC; maintained alongside plugin.toml releases.
ES: Historial de versiones de MusicPC; se mantiene junto con las versiones de plugin.toml.

## 0.2.3 - 2026-10-26

- Fixed Library refresh to wait for MPD to update its database before reloading the current page.

## 0.2.2 - 2026-10-26

- Moved the store thumbnail to the plugin root and aligned publishing documentation with the community plugin layout.
- Updated catalog tags to values accepted by Noctalia Community Plugins.

## 0.2.1 - 2026-10-26

- Embedded metadata editing in the queue panel so opening and closing the editor preserves the panel surface and placement.
- Fixed metadata editor save and close actions by exposing their named UI callbacks from the queue-panel entry.
- Added English and Spanish translations for widget, panel, and metadata-editor controls, labels, menus, statuses, and notifications.

## 0.2.0 - 2026-10-26

- Reorganized MPD, playlist, player-action, metadata, editor, panel-controller, and media-helper code into purpose-specific modules.
- Kept Noctalia entry scripts at the plugin root and preserved `plugin_api = 34` and the canonical plugin ID.
- Reduced the mpc client to commands used by MusicPC and removed the unused `closePanel` callback.
- Added bilingual function/file documentation and English and Spanish user guides.
- Moved source animation GIFs to an ignored archive folder; runtime PNG frames remain bundled.
- Added MIT license and catalog-oriented manifest metadata.
