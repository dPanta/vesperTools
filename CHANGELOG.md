## 3.1.1 - 2026-03-27

### Fixed
- Fixed the minimap launcher and empty `/vesper` toggle so Roster and Portals are now treated as one paired window set instead of flipping independently.
- Fixed the desynced launcher state where clicking the icon with only one of the paired windows open could reopen one frame while closing the other.

### Notes
- This hotfix keeps the default launcher behavior predictable again: one click opens both primary windows, and the next click closes whichever of the pair is currently open.

## 3.1.0 - 2026-03-27

### Changed
- Added a shared addon-level `ESCAPE` window manager so vesperTools now closes its own top-level windows consistently without relying on external addon hooks.
- Registered Bags, Bank, Vault, Roster, Portals, and Configuration with the shared close path so the active window responds to `ESCAPE` the same way its close button does.

### Fixed
- Fixed inconsistent `ESCAPE` behavior where some vesperTools windows were not closeable from the keyboard unless another addon happened to provide the binding.
- Fixed window close handling so keyboard-driven close requests now respect module-specific cleanup paths such as bank replacement shutdown, menu dismissal, and linked window cleanup.

### Notes
- This minor release turns window dismissal into a native shared behavior inside vesperTools instead of leaving it split across one-off frame registrations and outside addon code.

## 3.0.1 - 2026-03-27

### Fixed
- Current-season equippable items from previous-expansion dungeons now stay in the `Gear` category instead of being forced into `Past Expansions` when they use modern upgrade tracks.
- Added a bags data migration so already stored carried-bag snapshots are recategorized for existing characters instead of waiting for each alt to log in again.

### Notes
- This hotfix keeps seasonal dungeon gear grouped with your active equipment inventory even when the item's source dungeon originally belonged to an older expansion.

## 3.0.0 - 2026-03-27

### Changed
- Added persistent per-character Delver's Bounty tracking to the Great Vault data store so weekly delve-map state now follows the selected character across your warband.
- Expanded the Great Vault viewer with a dedicated footer status strip that shows `Map used this week: Yes/No` for the currently displayed character.
- Promoted the recent Great Vault and multi-character vault-work improvements into a `3.0.0` milestone release.

### Fixed
- Increased the Great Vault window's default and minimum height so the new delve-map status footer no longer overlaps the last vault reward row.
- Fixed the delve-map footer status text so color formatting no longer leaks raw digits into the label.
- Centered the delve-map footer value so the status strip reads cleanly instead of hugging the left edge.

### Notes
- `3.0.0` marks the Great Vault viewer as a more complete warband-aware utility, with Delver's Bounty tracking and the supporting UI polish bundled into one milestone release.

## 2.9.1 - 2026-03-27

### Changed
- Updated the roster window sorting so guild members who are currently in your active party or raid are grouped at the top of the list while keeping their existing highlighted row tint.

### Notes
- This hotfix improves roster scanability when forming or managing a group from the guild list.

## 2.9.0 - 2026-03-26

### Changed
- Added an `Online Players Blacklist` control to the Roster configuration so specific currently online guild members can be excluded from the sheep-icon online count and tooltip list.
- Applied a shared soft-rounded corner treatment to addon-owned windows and popup menus for a more polished look across Bags, Bank, Vault, Roster, Portals, and Configuration panels.

### Fixed
- Fixed the roster blacklist picker so opening it no longer fails on clients where `RequestGuildRosterUpdate()` is not exposed as a global function.
- Fixed the rounded-corner window helper so its corner border textures use valid WoW texture sublevels and render with fuller, cleaner curved edges.

### Notes
- This minor release focuses on giving roster counts a simple exclusion control while continuing the shared UI polish pass across the addon windows.

## 2.8.0 - 2026-03-26

### Changed
- Reworked the Bags and Bank category section layout so smaller categories can wrap side by side instead of always consuming a full-width row.
- Added a Bags-window layout edit mode with a cog button, draggable category headers, and saved category spans/order so sections can be rearranged directly in the window.
- Polished Bags layout edit mode with a stronger category outline, slightly more vertical spacing between category rows, and cleaner section backgrounds while organizing layouts.

### Fixed
- Removed the stray horizontal divider lines inside bag category containers that were reading like misplaced separators instead of useful group boundaries.

### Notes
- This minor release focuses on making sparse category sets use space more efficiently while adding direct category organization controls to the Bags window.

## 2.7.0 - 2026-03-25

### Changed
- Added bundled `LibSharedMedia-3.0` support for the shared addon font system so built-in and SharedMedia-registered fonts can be selected from one place.
- Reworked the configuration font selector into a scrollable preview picker that stays usable with long font lists and renders each entry in its own font when possible.

### Fixed
- Fixed Bags and Bank category headers, controls, and reused labels so they update immediately when the configured font changes.
- Fixed SharedMedia initialization and path handling so registered third-party fonts load more reliably and preview correctly on this install.
- Fixed combined usable-item stacks in the replacement Bags and Bank windows so right-click use routes through Blizzard's secure native container handling instead of insecure `UseContainerItem()` calls.
- Fixed the Mythic+ completion automation hook on clients that expose `C_ChallengeMode.GetChallengeCompletionInfo()` instead of the older `GetCompletionInfo()` API.

### Notes
- This minor release focuses on better font customization, safer live inventory interaction, and more reliable post-key automation behavior.

## 2.6.1 - 2026-03-25

### Changed
- Bundled `LibSharedMedia-3.0` directly with the addon and expanded the shared font selector to include SharedMedia-registered fonts alongside the built-in choices.
- Reworked the configuration font dropdown into a scrollable preview list so large font libraries stay usable and each entry can render in its own font.

### Fixed
- Fixed Bags and Bank category headers, controls, and other reused text widgets so they update immediately when the configured font changes.
- Fixed SharedMedia startup wiring that could throw a `RegisterCallback` usage error while initializing the addon.
- Fixed SharedMedia font path handling so third-party fonts registered with `Interface\Addons\...` paths resolve more reliably on this install and show previews more consistently.
- Fixed combined usable-item stacks in the replacement Bags and Bank windows so right-click use no longer falls back to insecure `UseContainerItem()` calls that can trigger `ADDON_ACTION_FORBIDDEN`.

### Notes
- This hotfix focuses on stabilizing font customization and secure interaction for combined usable bag items.

## 2.6.0 - 2026-03-25

### Changed
- Added a configurable currency bar to the bottom of the replacement Bags window for the current character, with gold always shown plus either tracked backpack currencies or a custom selected list.
- Added Bags configuration controls for toggling the currency bar and selecting which currencies appear from a cleaner current-expansion-focused picker.
- Updated the bag currency bar layout so each currency pill resizes to fit its displayed amount instead of using a fixed wide button.
- Documented the new bag currency bar in both overview documents.

### Fixed
- Fixed a bad currency event registration that could raise an unknown `CURRENCY_LIST_UPDATE` error while enabling the Bags module.
- Fixed the Bags currency picker across different client currency API shapes so the selection list opens and populates again when Retail-style rows expose `currencyID`.
- Fixed currency-bar entries and picker rows to resolve more reliable currency icons while avoiding the old broad fallback list of outdated or profession-heavy currencies by default.

### Notes
- This minor release focuses on making the replacement Bags window more informative while keeping the currency UI compact and the picker stable across client API variants.

## 2.5.1 - 2026-03-25

### Changed
- Documented the new account-wide Weekly Vault rewards viewer with character switcher in both addon overview documents.

### Fixed
- Restored live bag-container use/open clicks after the shared container item interaction refactor, so usable container items can be opened from the replacement Bags and Bank windows again.
- Fixed combined stacks of identical usable containers so the merged button can still open one real container by resolving a representative live bag slot behind the combined entry.
- Stopped the hidden Blizzard secure container overlay from consuming mouse input on container-category buttons, so container clicks reach the intended custom use path.

### Notes
- This hotfix focuses on stabilizing replacement inventory interactions for usable containers while rounding out the documentation for the new multi-character Weekly Vault viewer.

## 2.5.0 - 2026-03-24

### Changed
- Added a custom Great Vault snapshot window with a character switcher so current-week rewards can be viewed across logged characters, while still keeping Blizzard's live Great Vault available for the current character.
- Reworked the Great Vault display to use themed preview and locked chest visuals, a layout sized to show all 9 slots without scrolling, and row summaries that show the slot source directly such as `Mythic +4`, `Delve T8`, or raid difficulty.
- Changed Great Vault preview rows to use source-aware Midnight Season 1 mappings for tracks and item levels instead of inferring them from example item links, and added raid difficulty capture to vault snapshots so raid slots can render the correct source.
- Consolidated all non-current-expansion carried-bag items into a single `Past Expansions` category instead of splitting them by individual expansion.
- Added a locale supplement that backfills missing `enUS` keys at runtime and covers the newly added user-facing strings across the shipped locales.

### Fixed
- Stopped Great Vault preview slots from showing random real items or example-item hyperlinks as if they were actual rewards.
- Fixed Great Vault preview tracks so low-level dungeon or delve rows no longer claim endgame tracks like `Myth`, and restricted raid requirement text to raid slots so it no longer bleeds into other lanes.
- Fixed Great Vault rendering issues around delayed item info and corrected raid requirement text so raw `%d` placeholders no longer leak into the UI.

### Notes
- This minor release focuses on multi-character Great Vault support, bag categorization cleanup, and locale coverage maintenance.

## 2.4.5 - 2026-03-24

### Changed
- Added expansion-based carried-bag categories so non-current-expansion items can be grouped under their expansion names and only appear when matching items exist.
- Reworked bag and bank item buttons to share a common container-item interaction/controller layer instead of maintaining two drifting implementations.
- Changed the replacement bank window to default to the current character view unless a specific live bank interaction requests a different opening view.
- Added a measured minimum width for bag category headers so section titles stay readable even when the bag window shrinks to a very small item grid.

### Notes
- This hotfix focuses on inventory-window consistency and layout polish, while continuing the ongoing stabilization work around replacement bank interactions.

## 2.4.4 - 2026-03-23

### Changed
- Comments galore! Im always behind in commenting stuff.

### Notes
- This hotfix is a maintenance/documentation pass only and is not intended to change runtime behavior.

## 2.4.3 - 2026-03-23

### Fixed
- Prevented merchant-driven Blizzard bag toggle hooks from closing the replacement bags window when it was already open before talking to a vendor.
- Cleared stale carried-bag new-item markers once on real character login so replacement bags do not treat your full inventory as freshly looted every session.
- Stopped the native secure container overlays used for live bag and bank interactions from rendering their own item visuals, avoiding duplicate or sticky blue new-item glows on top of vesperTools' custom item buttons.

### Notes
- This hotfix focuses on stabilizing replacement bag behavior around vendor interactions and new-item presentation without changing the live item interaction model introduced in `2.4.2`.

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
