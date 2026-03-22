local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enGB")
end

if not L then
    return
end

local translations = {
    ADDON_LOADED_MESSAGE = "vesperTools loaded successfully!",
    ALL_FRAME_POSITIONS_RESET = "All frame positions have been reset.",
    BANK_EMPTY = "No bank data available yet.",
    BANK_DEPOSIT_BUTTON = "Deposit",
    BANK_SEARCH_PLACEHOLDER = "Search bank",
    BANK_SWITCH_CHARACTER = "Bank",
    BANK_SWITCH_WARBAND = "Warband",
    BANK_TITLE = "Bank",
    BAGS_BACKPACK = "Backpack",
    BAGS_CATEGORY_CONSUMABLE = "Consumables",
    BAGS_CATEGORY_CONTAINER = "Containers",
    BAGS_CATEGORY_EQUIPMENT = "Equipment",
    BAGS_CATEGORY_JUNK = "Junk",
    BAGS_CATEGORY_MISC = "Miscellaneous",
    BAGS_CATEGORY_QUEST = "Quest",
    BAGS_CATEGORY_REAGENT = "Crafting Reagents",
    BAGS_CATEGORY_RECIPE = "Recipes",
    BAGS_CATEGORY_TRADE_GOODS = "Trade Goods",
    BAGS_CLEAR_NEW_ITEMS = "Cleanup",
    BAGS_BAG_SLOTS = "Bags",
    BAGS_COMBINE_BUTTON = "Combine",
    BAGS_EMPTY = "No bag data available yet.",
    BAGS_SEARCH_PLACEHOLDER = "Search bags",
    BAGS_TITLE = "Bags",
    BAGS_LIVE = "Live",
    BAGS_READ_ONLY = "Snapshot",
    CONFIG_ADD_BUTTON = "Add",
    CONFIG_ADD_TOY_BY_NAME = "Add Toy By Name",
    CONFIG_BAGS_COLUMNS = "Number of Columns",
    CONFIG_BAGS_ICON_SIZE = "Item Icon Size",
    CONFIG_BAGS_SHOW_ITEM_LEVEL = "Show Item Level",
    CONFIG_BANK_COLUMNS = "Number of Columns",
    CONFIG_BANK_ICON_SIZE = "Item Icon Size",
    CONFIG_BANK_SHOW_ITEM_LEVEL = "Show Item Level",
    CONFIG_BEST_KEYS_FONT_SIZE = "Best Keys Font Size",
    CONFIG_BEST_KEYS_OPACITY = "Best Keys Opacity",
    CONFIG_FONT_MENU_TITLE = "vesperTools Font",
    CONFIG_NO_OWNED_TOY_MATCH = "No owned toy matches that name.",
    CONFIG_NO_OWNED_TOYS_AVAILABLE = "No owned toys available",
    CONFIG_NO_TOYS_AVAILABLE = "No Toys Available",
    CONFIG_PORTALS_FONT_SIZE = "Portals Font Size",
    CONFIG_PORTALS_OPACITY = "Portals Opacity",
    CONFIG_PRIMARY_HEARTHSTONE = "Primary Hearthstone",
    CONFIG_ROSTER_FONT_SIZE = "Roster Font Size",
    CONFIG_ROSTER_OPACITY = "Roster Opacity",
    CONFIG_SECTION_BAGS_WINDOW = "Bags Window",
    CONFIG_SECTION_BANK_WINDOW = "Bank Window",
    CONFIG_SECTION_BEST_KEYS_FRAME = "Best Keys Frame",
    CONFIG_SECTION_PORTALS_FRAME = "Portals Frame",
    CONFIG_SECTION_ROSTER_FRAME = "Roster Frame",
    CONFIG_SHARED_FONT_FAMILY = "Shared Font Family",
    CONFIG_TAB_BAGS = "Bags",
    CONFIG_TAB_BANK = "Bank",
    CONFIG_TAB_BEST_KEYS = "Best Keys",
    CONFIG_TAB_PORTALS = "Portals",
    CONFIG_TAB_ROSTER = "Roster",
    CONFIG_TITLE = "Configuration",
    CONFIG_TOP_UTILITY_BUTTON_SIZE = "Hearthstone/Toy Button Size",
    CONFIG_TOY_FLYOUT_WHITELIST = "Toy Flyout Whitelist",
    CONTEXT_MENU_CLOSE = "Close",
    CONTEXT_MENU_INVITE = "Invite",
    CONTEXT_MENU_WHISPER = "Whisper",
    GREAT_VAULT = "Great Vault",
    HEARTHSTONE = "Hearthstone",
    MAGE_PORTALS = "Mage Portals",
    MAGE_TELEPORTS = "Mage Teleports",
    MINIMAP_TOOLTIP_MOVE = "Shift+Left-Click & Drag: Move Icon",
    MINIMAP_TOOLTIP_NOT_IN_GUILD = "You are not in a guild",
    MINIMAP_TOOLTIP_NO_GUILD_ONLINE = "No guild members online",
    MINIMAP_TOOLTIP_TITLE = "vesperTools",
    MINIMAP_TOOLTIP_TOGGLE = "Left-Click: Toggle Roster",
    NO_HEARTHSTONES_AVAILABLE = "No Hearthstones Available",
    NO_PORTAL_SPELLS_KNOWN = "No Portal Spells Known",
    NO_TELEPORT_SPELLS_KNOWN = "No Teleport Spells Known",
    NO_WHITELISTED_TOYS = "No Whitelisted Toys",
    PLAYER_NOT_IN_GUILD = "You are not in a guild!",
    PORTALS_TOGGLE_IN_COMBAT = "Can't toggle UI during combat.",
    PORTALS_UI_NOT_INITIALIZED = "Portal UI not initialized yet.",
    ROSTER_BUTTON_CONFIG = "Conf",
    ROSTER_BUTTON_BAGS = "Bags",
    ROSTER_BUTTON_BANK = "Bank",
    ROSTER_BUTTON_SYNC = "Sync",
    ROSTER_COLUMN_FACTION = "F",
    ROSTER_COLUMN_ILVL = "iLvl",
    ROSTER_COLUMN_KEY = "KEY",
    ROSTER_COLUMN_NAME = "Name",
    ROSTER_COLUMN_RATING = "R",
    ROSTER_COLUMN_STATUS = "Status",
    ROSTER_COLUMN_ZONE = "Zone",
    ROSTER_TITLE_FALLBACK = "Guild Roster",
    SLASH_COMMAND_HELP = "Open vesperTools window",
    STATUS_AFK = "AFK",
    STATUS_DND = "DND",
    STATUS_ONLINE = "Online",
    TOY_FALLBACK = "Toy",
    UNKNOWN_DUNGEON = "Unknown",
    UNKNOWN_LABEL = "Unknown",
    UTILITY_FALLBACK = "Utility",
    UTILITY_TOYS = "Utility Toys",
    UTILITY_TOYS_HINT = "Mouseover: Open flyout",
    UTILITY_TOOLTIP_UNAVAILABLE = "Unavailable",
    UTILITY_TOOLTIP_USE = "Left-click: Use",
}

for key, value in pairs(translations) do
    L[key] = value
end

local defaults = addonTable and addonTable.LocaleDefaults or nil
if defaults then
    for key, value in pairs(defaults) do
        if L[key] == nil then
            L[key] = value
        end
    end
end
