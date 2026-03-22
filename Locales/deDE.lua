local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "deDE")
end

if not L then
    return
end

local translations = {
    ADDON_LOADED_MESSAGE = "vesperTools erfolgreich geladen!",
    ALL_FRAME_POSITIONS_RESET = "Alle Fensterpositionen wurden zurueckgesetzt.",
    BANK_EMPTY = "Noch keine Bankdaten verfuegbar.",
    BANK_DEPOSIT_BUTTON = "Einlagern",
    BANK_SEARCH_PLACEHOLDER = "Bank durchsuchen",
    BANK_SWITCH_CHARACTER = "Bank",
    BANK_SWITCH_WARBAND = "Kriegsmeute",
    BANK_TITLE = "Bank",
    BAGS_BACKPACK = "Rucksack",
    BAGS_CATEGORY_CONSUMABLE = "Verbrauchsgueter",
    BAGS_CATEGORY_CONTAINER = "Behaelter",
    BAGS_CATEGORY_EQUIPMENT = "Ausruestung",
    BAGS_CATEGORY_JUNK = "Plunder",
    BAGS_CATEGORY_MISC = "Verschiedenes",
    BAGS_CATEGORY_QUEST = "Quest",
    BAGS_CATEGORY_REAGENT = "Herstellungsreagenzien",
    BAGS_CATEGORY_RECIPE = "Rezepte",
    BAGS_CATEGORY_TRADE_GOODS = "Handelswaren",
    BAGS_CLEAR_NEW_ITEMS = "Aufraeumen",
    BAGS_BAG_SLOTS = "Taschen",
    BAGS_COMBINE_BUTTON = "Kombinieren",
    BAGS_EMPTY = "Noch keine Taschendaten verfuegbar.",
    BAGS_SEARCH_PLACEHOLDER = "Taschen durchsuchen",
    BAGS_TITLE = "Taschen",
    BAGS_LIVE = "Live",
    BAGS_READ_ONLY = "Schnappschuss",
    CONFIG_ADD_BUTTON = "Hinzufuegen",
    CONFIG_ADD_TOY_BY_NAME = "Spielzeug nach Namen hinzufuegen",
    CONFIG_BAGS_COLUMNS = "Anzahl der Spalten",
    CONFIG_BAGS_ICON_SIZE = "Groesse der Gegenstandssymbole",
    CONFIG_BAGS_SHOW_ITEM_LEVEL = "Gegenstandslevel anzeigen",
    CONFIG_BANK_COLUMNS = "Anzahl der Spalten",
    CONFIG_BANK_ICON_SIZE = "Groesse der Gegenstandssymbole",
    CONFIG_BANK_SHOW_ITEM_LEVEL = "Gegenstandslevel anzeigen",
    CONFIG_BEST_KEYS_FONT_SIZE = "Schriftgroesse fuer beste Schluessel",
    CONFIG_BEST_KEYS_OPACITY = "Deckkraft fuer beste Schluessel",
    CONFIG_FONT_MENU_TITLE = "vesperTools-Schriftart",
    CONFIG_NO_OWNED_TOY_MATCH = "Kein besessenes Spielzeug passt zu diesem Namen.",
    CONFIG_NO_OWNED_TOYS_AVAILABLE = "Keine besessenen Spielzeuge verfuegbar",
    CONFIG_NO_TOYS_AVAILABLE = "Keine Spielzeuge verfuegbar",
    CONFIG_PORTALS_FONT_SIZE = "Schriftgroesse fuer Portale",
    CONFIG_PORTALS_OPACITY = "Deckkraft fuer Portale",
    CONFIG_PRIMARY_HEARTHSTONE = "Primaerer Ruhestein",
    CONFIG_ROSTER_FONT_SIZE = "Schriftgroesse fuer Gildenliste",
    CONFIG_ROSTER_OPACITY = "Deckkraft fuer Gildenliste",
    CONFIG_SECTION_BAGS_WINDOW = "Taschenfenster",
    CONFIG_SECTION_BANK_WINDOW = "Bankfenster",
    CONFIG_SECTION_BEST_KEYS_FRAME = "Rahmen fuer beste Schluessel",
    CONFIG_SECTION_PORTALS_FRAME = "Portalrahmen",
    CONFIG_SECTION_ROSTER_FRAME = "Gildenlistenrahmen",
    CONFIG_SHARED_FONT_FAMILY = "Gemeinsame Schriftfamilie",
    CONFIG_TAB_BAGS = "Taschen",
    CONFIG_TAB_BANK = "Bank",
    CONFIG_TAB_BEST_KEYS = "Beste Schluessel",
    CONFIG_TAB_PORTALS = "Portale",
    CONFIG_TAB_ROSTER = "Gildenliste",
    CONFIG_TITLE = "Konfiguration",
    CONFIG_TOP_UTILITY_BUTTON_SIZE = "Groesse fuer Ruhestein-/Spielzeug-Buttons",
    CONFIG_TOY_FLYOUT_WHITELIST = "Whitelist fuer Spielzeug-Flyout",
    CONTEXT_MENU_CLOSE = "Schliessen",
    CONTEXT_MENU_INVITE = "Einladen",
    CONTEXT_MENU_WHISPER = "Anfluestern",
    GREAT_VAULT = "Grosses Gewoelbe",
    HEARTHSTONE = "Ruhestein",
    MAGE_PORTALS = "Magierportale",
    MAGE_TELEPORTS = "Magierteleports",
    MINIMAP_TOOLTIP_MOVE = "Umschalt+Linksklick & Ziehen: Symbol bewegen",
    MINIMAP_TOOLTIP_NOT_IN_GUILD = "Du bist in keiner Gilde",
    MINIMAP_TOOLTIP_NO_GUILD_ONLINE = "Keine Gildenmitglieder online",
    MINIMAP_TOOLTIP_TITLE = "vesperTools",
    MINIMAP_TOOLTIP_TOGGLE = "Linksklick: Gildenliste umschalten",
    NO_HEARTHSTONES_AVAILABLE = "Keine Ruhesteine verfuegbar",
    NO_PORTAL_SPELLS_KNOWN = "Keine Portalzauber bekannt",
    NO_TELEPORT_SPELLS_KNOWN = "Keine Teleportzauber bekannt",
    NO_WHITELISTED_TOYS = "Keine Spielzeuge auf der Whitelist",
    PLAYER_NOT_IN_GUILD = "Du bist in keiner Gilde!",
    PORTALS_TOGGLE_IN_COMBAT = "Die UI kann im Kampf nicht umgeschaltet werden.",
    PORTALS_UI_NOT_INITIALIZED = "Portal-UI ist noch nicht initialisiert.",
    ROSTER_BUTTON_CONFIG = "Konf",
    ROSTER_BUTTON_BAGS = "Taschen",
    ROSTER_BUTTON_BANK = "Bank",
    ROSTER_BUTTON_SYNC = "Sync",
    ROSTER_COLUMN_FACTION = "F",
    ROSTER_COLUMN_ILVL = "iLvl",
    ROSTER_COLUMN_KEY = "KEY",
    ROSTER_COLUMN_NAME = "Name",
    ROSTER_COLUMN_RATING = "W",
    ROSTER_COLUMN_STATUS = "Status",
    ROSTER_COLUMN_ZONE = "Zone",
    ROSTER_TITLE_FALLBACK = "Gildenliste",
    SLASH_COMMAND_HELP = "vesperTools-Fenster oeffnen",
    STATUS_AFK = "AFK",
    STATUS_DND = "DND",
    STATUS_ONLINE = "Online",
    TOY_FALLBACK = "Spielzeug",
    UNKNOWN_DUNGEON = "Unbekannt",
    UNKNOWN_LABEL = "Unbekannt",
    UTILITY_FALLBACK = "Nutzung",
    UTILITY_TOYS = "Nutzspielzeuge",
    UTILITY_TOYS_HINT = "Mouseover: Flyout oeffnen",
    UTILITY_TOOLTIP_UNAVAILABLE = "Nicht verfuegbar",
    UTILITY_TOOLTIP_USE = "Linksklick: Benutzen",
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
