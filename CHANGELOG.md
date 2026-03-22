## 2.3.0 - 2026-03-22

### Changed
- Expanded carried-bag search so typing in the bags window now checks other characters' saved bag snapshots, matching the existing bank-style account-wide search behaviour.
- Added green `Found(x)` indicators in the bag and bank character switcher menus to show how many snapshot items matched on each character.
- Added the same `Found(x)` indicator to the currently selected character on the closed character dropdown so search feedback stays visible without opening the menu.

### Notes
- This release focuses on account-wide inventory search visibility and faster cross-character item discovery.

## 2.2.0 - 2026-03-22

### Changed
- Updated bag and bank category headers to use a dedicated arrow icon for collapsing and expanding sections instead of making the full header row clickable.
- Added an explicit collapsed-state arrow direction so hidden categories now display an upward-pointing arrow.
- Corrected packager metadata so release packages are named `vesperTools`.

### Notes
- This release focuses on inventory UI polish and release packaging consistency.

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
