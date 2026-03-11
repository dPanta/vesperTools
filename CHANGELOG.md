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
