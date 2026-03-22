## 2.1.0 - 2026-03-22

### Changed
- Expanded and synchronised the shipped locale files across `enGB`, `deDE`, `esES`, `esMX`, `frFR`, `itIT`, `koKR`, `ptBR`, `ruRU`, `zhCN`, and `zhTW`.
- Translated the main user-facing UI, configuration, tooltip, and roster strings for every shipped non-`enUS` locale.
- Standardised the locale file structure so each locale now carries explicit translated overrides while still falling back cleanly to `enUS` for anything not yet overridden.

### Notes
- This release is focused on localisation coverage and locale maintenance. Addon functionality is unchanged.

## 1.0.0 - 2026-03-22

Initial `vesperTools` release.

This addon is the continuation of the previous `VesperGuild` project. The addon name, metadata, bindings, and user-facing labels have been renamed to `vesperTools`, while legacy `VesperGuild` SavedVariables are still recognized so existing settings and stored data migrate forward cleanly.

### Migration Notes
- `VesperGuild` is now `vesperTools`.
- Existing `VesperGuildDB` and `VesperGuildBagsDB` data is imported into the new addon automatically.
- Users should enable and launch `vesperTools` instead of the previous addon name after updating.
