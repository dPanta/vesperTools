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

## 3.2.0 - 2026-03-30

### Changed
- Rebuilt the Roster window on native Blizzard frames instead of `AceGUI`, while keeping the existing guild roster actions and adding a cleaner modern scrollbar treatment.
- Added Midnight skinning-lure markers to configured Midnight zone maps, with click-to-waypoint behavior that uses Blizzard's built-in navigation arrow.
- Added `Ready` and `Pull` action buttons above Blizzard's party and raid frame headers for group leaders and raid assistants.
- Added shared internal helpers for window lifecycle, combat-safe deferred refreshes, comm routing, timer handling, and reusable modern button styling as groundwork for reducing Ace dependencies.

### Fixed
- Fixed roster window lifecycle so reopening it no longer risks duplicate named-frame issues, and live keystone updates now refresh the open roster correctly.
- Fixed bundled locale loading so non-`enUS` translations work correctly when using the packaged addon libraries on their own.
- Fixed native container overlay input handling so replacement Bags and Bank interactions no longer trigger the protected-action warning seen during live item overlay refreshes.
- Fixed the new Midnight lure map pins so parent/child world-map navigation no longer trips a `Blizzard_MapCanvas` assertion during map changes.
- Fixed the roster scrollbar and close-button polish pass so the scrollbar hides when not needed, uses a softer darker style, and the close icon now adopts the player's class color.

### Notes
- This minor release bundles a larger roster modernization pass with new world-map skinning markers, party/raid utility buttons, and the supporting internal cleanup needed to keep future de-Ace work safer.
