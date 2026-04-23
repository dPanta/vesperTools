## 4.5.0 - 2026-04-23

### Changed
- Added live bank deposit routing to the bags window so left-clicking or dragging items while a writable bank is open now deposits them into the active character or warband bank view.
- Synced the vesperTools bank view back to Blizzard's native bank tabs so direct deposits and manual bank interactions stay pointed at the same live destination.
- Extended the bags overlay interaction rules so those bank-deposit clicks can pass through the custom item overlay instead of being swallowed before the deposit logic runs.

### Fixed
- Fixed bank deposit targeting so items that can only go into one bank type no longer attempt to route into an invalid character or warband destination.
- Fixed the fallback deposit path so stackable items still merge into partial stacks and otherwise choose a compatible empty bank bag slot when the direct bank API deposit path is unavailable.

### Notes
- This minor release is focused on making bank cleanup faster from the bags window, especially while switching between live character-bank and warband-bank views.

## 4.4.0 - 2026-04-20

### Changed
- Moved the roster window close button to the left side of the titlebar while `Apple Fan` is enabled, keeping the normal right-side layout when the style toggle is off.
- Realigned the alt-character keys frame so it is horizontally centered beneath the Best Runs frame instead of inheriting the left edge alignment.
- Turned the `Apple Fan` confetti burst into a much more excessive spread, with many more pieces, wider travel, and longer visible motion.

### Fixed
- Fixed the roster window titlebar layout so its square top strip no longer peeks through the rounded upper corners as tiny dark triangles while `Apple Fan` mode is active.
- Fixed the `Apple Fan` confetti burst so pieces spawn from an inner edge band and spread more naturally instead of appearing as cramped straight lines from outside the configuration window.

### Notes
- This minor release is a follow-up polish pass on the `4.3.0` Apple Fan presentation, focused on layout cleanup and pushing the visual joke further.

## 4.3.0 - 2026-04-20

### Changed
- Added a global `Apple Fan` style toggle to the configuration window so all vesperTools windows can switch between rounded and classic square corners from one place.
- Added a custom rainbow bitten-apple icon beside the `Apple Fan` toggle and styled the configuration window border with the player's class color to match the rest of the rounded-window treatment.
- Added an intentionally over-the-top confetti burst around the configuration window when `Apple Fan` is enabled.

### Fixed
- Reworked the shared rounded-window backdrop helper so toggling between rounded and square corners preserves the intended dark fills and class-colored borders instead of losing or whitening frame styling.
- Cleaned up the rounded corner rendering so larger-radius corners stay crisper and avoid the dark pixel gaps, jagged cutouts, and uneven border thickness seen during the earlier corner-art iterations.
- Fixed the new `Apple Fan` confetti overlay so it uses valid texture sublevels and spreads from the window edge band instead of clipping from outside the panel.

### Notes
- This minor release is focused on visual polish and playful configuration flair, centered on the new global rounded-corner style toggle and its Apple-themed presentation.

## 4.2.2 - 2026-04-17

### Fixed
- Fixed the account-keystone snapshot refresh so characters without a fully initialized Mythic+ keystone yet no longer trip a startup Lua error when Blizzard's keystone APIs return no value.

### Notes
- This hotfix hardens the new account-keystone tracking added in `4.2.0`, especially for freshly progressed level-80 characters who have not fully entered the Mythic+ flow yet.

## 4.2.1 - 2026-04-16

### Fixed
- Colored character names in the account keystone panel by class so the new alt-key list is easier to scan at a glance.
- Added a bags-cache fallback when resolving stored account keystones, so alt keys still appear when the active keystone cache is missing the direct current-name match.

### Notes
- This hotfix tightens up the new alt-key panel added in `4.2.0` without changing its layout or behavior beyond more reliable character resolution.

## 4.2.0 - 2026-04-16

### Changed
- Added an account keystone list below the Best Runs panel in the portals window so you can quickly see which alts currently hold a stored key.
- Added per-character keystone snapshot storage and refresh hooks so the account keystone list stays current from login, bag updates, and Mythic+ completion.
- Filled missing locale keys across all shipped locales so the newer vault and account-keystone UI strings are available everywhere, preserving existing translations and falling back to English where needed.

### Fixed
- Great Vault reward-row tooltips now show the current week's Mythic+ runs that count toward each reward slot, including dungeon names and key levels.
- Vault snapshots now store the current week's Mythic+ dungeon history so those tooltip details are available while reviewing other characters.

### Notes
- This release is focused on making weekly account planning easier by surfacing both stored keystones and vault-progress context in the addon's existing planning windows.

## 4.1.0 - 2026-04-12

### Changed
- Added a roster double-left-click group action so clicking a guild member row twice now invites them, or requests to join their group when Blizzard exposes that join path.
- Split roster row interactions so the row itself handles menu and invite actions while the keystone column remains the dedicated portal-cast target.

### Fixed
- Fixed the roster keystone column so left-clicking the key once again casts the mapped seasonal dungeon portal after the new double-click invite flow was added.
- Updated the roster tooltip hints to reflect the new double-left-click invite action and the separate left-click key portal behavior.

### Notes
- This minor release focuses on polishing roster interactions after the larger `4.0.0` launcher-search update.

## 4.0.0 - 2026-04-12

### Changed
- Added a centered launcher search overlay with a separate search bar and results panel styled to match the existing vesperTools window borders.
- Added dynamic full-text search across vesperTools actions and config tabs, Blizzard settings categories and setting rows, toys, spells, talent loadouts, carried bags, character bank, and warband bank.
- Added a fixed-height scrollable results list capped at 30 entries, with prioritization that favors the current character's carried bags first, then the current character's bank, then other stored inventories.

### Fixed
- Fixed the launcher search flow so results only appear after at least three typed characters, hide completely when the query is empty or unmatched, and no longer auto-focus the search box when the launcher opens.
- Fixed result activation for bag and bank hits so selecting an item opens the correct vesperTools window, switches to the right character or bank view, expands the right category, and seeds the internal item search/highlight.
- Fixed Blizzard settings indexing so retail settings rows are harvested from the live `SettingsPanel` layout instead of only indexing top-level categories.
- Fixed Click Cast Bindings discoverability by exposing it as an explicit searchable launcher action, since it is opened through Blizzard's standalone click-binding UI toggle rather than the normal settings category tree.

### Notes
- This major release turns the launcher into a Spotlight-style search surface for Midnight retail, with broader Blizzard integration and direct navigation into addon windows, bags, bank views, and supported Blizzard configuration surfaces.

## 3.2.7 - 2026-04-09

### Changed
- Added a carried-bag `Season` category so seasonal items are grouped separately from the normal reagent and misc buckets.

### Fixed
- Added current seasonal spark reagents such as `Spark of ...` and `Fractured Spark of ...` to the carried-bag `Season` category instead of leaving them in `Crafting Reagents`.
- Added a bags data migration so existing saved bag snapshots are recategorized into `Season` immediately after update instead of waiting for each character to rescan those items.

### Notes
- This hotfix finishes the new bag-season grouping by making the category visible, catching the common spark crafting reagents automatically, and backfilling already-saved bag data on reload.

## 3.2.6 - 2026-04-08

### Fixed
- Added `Lightcalled Hearthstone` to the portals hearthstone catalog so owned copies now appear in the per-character hearthstone selection list.

### Notes
- This hotfix restores another missing hearthstone variant in the portals selection flow without changing any existing hearthstone behavior.

## 3.2.5 - 2026-04-08

### Fixed
- Added `Preyseeker's Hearthstone` to the portals hearthstone catalog so owned copies now appear in the per-character hearthstone selection list.

### Notes
- This hotfix restores the missing hearthstone variant in the portals selection flow without changing any existing hearthstone behavior.

## 3.2.4 - 2026-04-07

### Changed
- Replaced the roster's faction column with a sortable character level column so the guild list surfaces player level directly.

### Fixed
- Updated the roster right-click action so guild members who are already in a joinable group show `Request to Join Group` instead of always showing a plain invite.

### Notes
- This hotfix keeps the roster focused on more immediately useful character info while making the group-forming flow behave more like Blizzard's own context menus.

## 3.2.3 - 2026-04-03

### Fixed
- Extended the carried-bag `Gear` exemption for past-expansion items so Timewalking-scaled equippable gear stays grouped with current equipment when it requires the current expansion's max level, even without a modern upgrade-track tooltip line.
- Added a bags data migration so previously saved carried snapshots are recategorized immediately instead of waiting for each character to rescan those items.

### Notes
- This keeps current-level Timewalking and other current-scaled legacy equipment out of `Past Expansions` while preserving the existing seasonal dungeon upgrade-track exemption.

## 3.2.2 - 2026-04-01

### Fixed
- Fixed Midnight lure world-map pin startup so the custom map-pin provider is only attached after the Blizzard world map is actually shown, reducing the `Blizzard_MapCanvas.lua:280` assertion seen during early map initialization and parent-map navigation.
- Fixed Midnight lure map-pin rendering so the custom pins no longer style Blizzard map-canvas frames with the shared modern button helper, reducing taint leaking into Area POI tooltip widget layout and `Blizzard_UIWidgetTemplateTextWithState`.

### Notes
- This hotfix is focused on stabilizing the world-map Midnight lure integration after the `3.2.0` map-marker feature release.

## 3.2.1 - 2026-03-31

### Fixed
- Fixed the Midnight lure world-map pins so clicking the knife markers now correctly places Blizzard's built-in user waypoint and enables the navigation arrow.
- Fixed the Midnight lure pin integration so opening the world map or navigating between parent and child maps no longer trips the `Blizzard_MapCanvas` assertion caused by pre-attached pin mouse scripts.

### Notes
- This hotfix is focused on stabilizing the new Midnight lure map markers after the larger `3.2.0` feature release.
