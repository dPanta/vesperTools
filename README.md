# VesperGuildRoster
Simple addon to manage your guild m+ runs.

# Features
- Roster window with online guildies
  - Name, faction, Current Zone, Status (afk, online), m+ rating and current m+ keystone
  - If you click on someones key, teleport spell begins to cast
  - Pulls data from bigwigs/other addons that use LibKeystone
- Portals window frame with all current seasonal teleports
  - Automatically fills up with current season
  - Grays out if given teleport not learned yet
  - Cooldown spiral
  - Ready for Midnight Season 1 (hopefully)
  - Button bellow portals for opening Great Vault Rewards window
  - M+ progress overview with best for each seasonal key + time (green for in-time keys, red for over-time keys)
  - iLvl sync for people with the addon. Will sync ilvl accros addon users and display it in roster frame
  - If you time a key and the key in your bag is lower or same as the key you just timed, a huge message pops up to ask if you wanted to change the key or not :)
  - Hearthstone button, Arcantina button and Toys flyout menu
    - Configurable:
      - Hearthstone variant.
      - Toy selection whitelist.
- Bag / Bank / Warband bank replacement
  - Option to replace default blizzard bags
  - Predefined categories
  - Item stacks combining
  - Internal DB for all your character inventories on the same account
    - Switch between character inventories in bag window dropdown menu directly
  - Offline bank/warband bank access (read only ofc)

# How to use
- Icon with a sheep appears after installation
  - Can be moved via shift+left click and drag
- Or use chatcommand /vg or /vesper
  - subcommands:
    - /vg reset
      - Resets position of both frames and the icon
    - /vg keys
      - Dumps all currently saved keys to chat
    - /vg debug
      - Prints out additional info while using the addon

# Credits
## LibKeystone / BigWigs
[https://github.com/BigWigsMods/LibKeystone]
I am using this to pull data from guildies. Epic stuff.

## DungeonTeleportButtons
[https://github.com/tadahh/DungeonTeleportButtons]
Learned a lot from the library structure.

## EnhanceQoL
[https://github.com/R41z0r/EnhanceQoL]
Inspiration for the teleport buttons and how to style/sort them, how to pull data from wowAPI.

## Download
[https://www.curseforge.com/wow/addons/vesperguildroster]
