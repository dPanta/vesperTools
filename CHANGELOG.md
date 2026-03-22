## 2.4.2 - 2026-03-23

### Changed
- Reworked live item interaction in the Bags and Bank windows to use Blizzard's native container item button behavior instead of a custom protected use path.
- Fixed `ADDON_ACTION_FORBIDDEN` errors caused by `vesperTools` trying to call `UseContainerItem()` directly from custom item click handlers.
- Restored Blizzard-style live item interactions such as normal use, pickup/drag handling, modified clicks, and vendor sell cursor behavior for live bag and bank slots.

### Notes
- This hotfix focuses on making custom inventory item interaction behave like the default Retail container UI again.

## 2.4.1 - 2026-03-22

### Changed
- Fixed the primary hearthstone configuration so `RANDOM DISCO` stays available as a valid selectable option for the top utility button flow.
- Blacklisted Dalaran Hearthstone from the primary hearthstone selection pool so it no longer appears in the primary picker or in the filtered `RANDOM DISCO` primary rotation.

### Notes
- This hotfix tightens the hearthstone selection rules without changing the rest of the `2.4.0` guild lookup feature set.

## 2.4.0 - 2026-03-22

### Changed
- Added a new chest-icon `Guild Lookup` mode to the bags window search bar, with saturated and desaturated shipped media assets plus an active glow state.
- Added Retail guild-only bag query sync so players can request matching carried-bag items from online guild members running `vesperTools`, while ignoring non-guild senders.
- Changed guild lookup mode to wait for `Enter` before searching, instead of updating dynamically while typing.
- Added a shared 30 second guild lookup cooldown and capped response payloads to keep addon-message traffic safe for broad text queries.
- Added a results frame above the bags window that lists matching items per player, split into separate `item / player / count` rows when a query matches multiple items.
- Added minimum-length validation so guild lookups require at least 4 non-space characters before a request can be sent.
- Added a new toggle at the top of the Bags configuration pane to opt in to guild lookup responses, with incoming requests disabled by default until each player explicitly enables them.

### Notes
- This release focuses on live guild inventory coordination for Retail/Midnight carried-bag searches without opening the feature up to unbounded spam.

## 2.3.0 - 2026-03-22

### Changed
- Expanded carried-bag search so typing in the bags window now checks other characters' saved bag snapshots, matching the existing bank-style account-wide search behaviour.
- Added green `Found(x)` indicators in the bag and bank character switcher menus to show how many snapshot items matched on each character.
- Added the same `Found(x)` indicator to the currently selected character on the closed character dropdown so search feedback stays visible without opening the menu.
- Made the primary hearthstone selection character-specific instead of profile-shared.
- Added a `RANDOM DISCO` hearthstone mode for the primary utility button.

### Notes
- This release adds hearthstone utility polish alongside the new account-wide inventory search visibility improvements.

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
