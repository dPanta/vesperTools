## 2.0.0 - 2026-03-22

### Added
- Added a dedicated `VesperGuildBagsDB` SavedVariables database for account-wide inventory storage, separate from the addon's main guild/config data.
- Added account-wide carried-bag snapshots for every character on the same WoW account, including per-character totals, category indexes, and searchable item metadata.
- Added a full bags window with predefined categories, live current-character interactions, offline alt snapshots, stack combining, empty-slot summaries, search, and per-category collapse state.
- Added a full bank window with `Bank / Warband` switching, categorized live views, search, stack combining, and a warband deposit action for eligible carried items.
- Added bag and bank replacement toggles to configuration, plus dedicated bank settings in a separate `Bank` configuration tab.
- Added roster shortcuts for `Bags` and `Bank`, plus slash-command access for the new inventory windows.
- Added modernized addon-owned header controls, custom dropdown styling, custom close buttons, and titlebar search clear controls across the new inventory windows.

### Changed
- Reworked inventory persistence to use incremental bag and bank snapshot updates driven by dirty-container tracking instead of rebuilding all inventory data on every bag event.
- Reworked the bags and bank UIs to auto-size around visible content instead of relying on manual window resizing.
- Expanded stored inventory search data to include item description text in addition to item names, enabling live full-text matching inside inventory views.
- Updated bag and bank windows to use compact text action buttons, modern dropdown menus, and account-oriented navigation defaults.
- Defaulted the bank window to open on the `Warband` view, with live bank interactions selecting the most relevant writable source automatically.

### Fixed
- Fixed Blizzard bag replacement keybinding so overridden bag actions open the VesperGuild bags window instead of swallowing the input.
- Fixed bank replacement to use live bag-slot interactions instead of remaining read-only for active bank and warband sessions.
- Fixed bank-open behavior so writable bank sessions automatically open the bags window alongside the bank window.
- Fixed bank-close and out-of-range handling so the bank window closes cleanly and any bags window opened for that bank session closes with it.
- Fixed the bank view selection flow so banker and warband-bank interactions resolve to the correct live replacement context more reliably.

## 1.5.1 - 2026-03-18

### Fixed
- Fixed cooldown text and swipe not appearing on portal and utility buttons by updating spell cooldown queries to use the current Mainline `C_Spell.GetSpellCooldownDuration` API and fixing boolean-to-number conversion for the enabled field across all cooldown paths.

## 1.5.0 - 2026-03-11

### Changed
- Reworked roster right-click menu anchoring to use a dedicated top-level context-menu anchor instead of inheriting the roster row's frame layering.

### Fixed
- Fixed the roster row right-click context menu rendering behind the main roster frame.
- Fixed the roster fallback dropdown menu to render on tooltip strata so its entries remain clickable above the roster window.

## 1.4.2 - 2026-03-08

### Added
- Added a runtime warning when the live Mythic+ season contains a dungeon missing from the static portal metadata catalog.

### Changed
- Promoted the main VesperGuild windows to `DIALOG` strata so roster and portal panels render above overlapping Blizzard cooldown UI.
- Standardized localization by moving English strings into shared defaults and backfilling missing keys in all shipped locale files.
- Updated the keystone abbreviation table and season comments for Midnight Season 1 Mythic+.
- Standardized this changelog for CurseForge-style manual release notes.

### Fixed
- Fixed missing localized strings across core, roster, portals, configuration, automation, and keystone sync flows.
- Fixed roster and portal windows to raise correctly when reopened.
- Fixed silent omission risk for future seasonal dungeons by surfacing missing portal metadata in chat.
