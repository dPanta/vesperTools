# vesperTools

`vesperTools` is a retail WoW addon focused on Mythic+ guild play, travel shortcuts, Great Vault planning, and account-wide inventory access.

## What It Does

- Guild roster tools: shows guild members with class-colored rows, levels, item level sync, known keystones, whisper shortcuts, right-click actions, and double-left-click invite or request-to-join behavior.
- Mythic+ sync and best runs: tracks seasonal dungeon progress, syncs keystones automatically, shares best-run data between addon users, and warns you when you finish a key but are still holding the same or a lower keystone.
- Portals and travel: shows the current season's dungeon portals, lets you click a key to use its teleport, and adds quick access to hearthstones, mage portals, teleports, and a configurable toy flyout.
- Best runs and account keys: includes the seasonal Best Runs panel plus a matching account-keystone panel underneath it that only shows characters with a stored keystone.
- Vault tools: opens the live Great Vault and stores account-wide weekly vault snapshots so you can compare rewards across characters. Mythic+ reward rows also show the dungeon names and key levels that character ran that week.
- Inventory tools: replaces the default bags, bank, and warband bank with unified windows, adds search, stack combining, item level overlays, a configurable currency bar, and lets you browse saved inventory data across your characters.
- Search tools: includes a launcher-style search overlay for addon windows, addon config, Blizzard settings, toys, spells, talents, Click Cast Bindings, bags, and bank results.
- Guild item lookup: can query guild inventories for specific items when other players opt in to sharing their bag data.
- Midnight lure map support: adds Midnight lure world-map pins with click-to-waypoint behavior.

## How To Open It

- Click the sheep launcher icon.
- Use `/vg`.
- Create a macro for `/vg` and bind it if you want faster access.

## Windows

- Launcher: opens the main roster and portals windows.
- Roster: shows guild Mythic+ data, supports row invite actions, and keeps the keystone column as the dungeon-portal click target.
- Portals: shows seasonal teleports, top travel utility buttons, the Best Runs panel, and the account-keystone panel.
- Great Vault: lets you review current-week vault snapshots for your account and open Blizzard's live Great Vault for the current character.
- Bags: custom carried-inventory replacement with cross-character browsing and guild lookup.
- Bank: custom character-bank and warband-bank replacement with snapshots, search, and live item interactions.
- Config: custom settings window for fonts, opacities, travel buttons, and bags/bank display preferences.

## Slash Commands

- `/vg` or `/vesper`: toggle the main addon launcher windows.
- `/vg config` or `/vg options`: open the vesperTools configuration window.
- `/vg bags`: open the custom bags window.
- `/vg bank`: open the custom bank and warband bank window.
- `/vg sync`: manually trigger a guild sync pass.
- `/vg reset`: reset the sheep icon and addon window positions.
- `/vg keys` or `/vg debug`: print stored keystone data to chat.
- `/vg bestkeys`: print the stored best-run database to chat.
- `/vg checkalts`: preview safe duplicate-character cleanup without changing data.
- `/vg cleanalts`: run duplicate-character cleanup again and report the result.

## Notes

- Sync features work best when other guild members also use the addon.
- Account-wide bags, bank, warband bank, vault, and account-keystone views depend on characters being logged in so their data can be saved.
- The account keystone panel only shows characters that currently have a stored keystone snapshot.
- Login automatically reconciles duplicate names on the same realm after character services. The live GUID takes priority; offline characters use the uniquely newest saved identity with a matching class. Ambiguous matches stay untouched. Original bags, bank, and vault records are preserved in `vesperToolsBagsDB.global.characterIdentityArchive` before cleanup; current key/rating snapshots remain intact.
- Guild item lookup only returns results from guildmates who enable bag-data sharing in the addon.
- All shipped locale files now contain the same key set. Some entries may still display English fallback text until they receive a dedicated translation.
