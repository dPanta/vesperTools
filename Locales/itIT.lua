local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "itIT")
end

if not L then
    return
end

local translations = {
    ADDON_LOADED_MESSAGE = "vesperTools caricato con successo!",
    ALL_FRAME_POSITIONS_RESET = "Tutte le posizioni delle finestre sono state reimpostate.",
    BANK_EMPTY = "Nessun dato bancario disponibile al momento.",
    BANK_DEPOSIT_BUTTON = "Deposita",
    BANK_SEARCH_PLACEHOLDER = "Cerca in banca",
    BANK_SWITCH_CHARACTER = "Banca",
    BANK_SWITCH_WARBAND = "Banda da Guerra",
    BANK_TITLE = "Banca",
    BAGS_BACKPACK = "Zaino",
    BAGS_CATEGORY_CONSUMABLE = "Consumabili",
    BAGS_CATEGORY_CONTAINER = "Contenitori",
    BAGS_CATEGORY_EQUIPMENT = "Equipaggiamento",
    BAGS_CATEGORY_JUNK = "Cianfrusaglie",
    BAGS_CATEGORY_MISC = "Varie",
    BAGS_CATEGORY_QUEST = "Missione",
    BAGS_CATEGORY_REAGENT = "Reagenti di creazione",
    BAGS_CATEGORY_RECIPE = "Ricette",
    BAGS_CATEGORY_TRADE_GOODS = "Merci commerciali",
    BAGS_CLEAR_NEW_ITEMS = "Pulisci",
    BAGS_BAG_SLOTS = "Borse",
    BAGS_COMBINE_BUTTON = "Combina",
    BAGS_EMPTY = "Nessun dato delle borse disponibile al momento.",
    BAGS_SEARCH_PLACEHOLDER = "Cerca nelle borse",
    BAGS_TITLE = "Borse",
    BAGS_LIVE = "Live",
    BAGS_READ_ONLY = "Istantanea",
    CONFIG_ADD_BUTTON = "Aggiungi",
    CONFIG_ADD_TOY_BY_NAME = "Aggiungi giocattolo per nome",
    CONFIG_BAGS_COLUMNS = "Numero di colonne",
    CONFIG_BAGS_ICON_SIZE = "Dimensione icona oggetto",
    CONFIG_BAGS_SHOW_ITEM_LEVEL = "Mostra il livello oggetto",
    CONFIG_BANK_COLUMNS = "Numero di colonne",
    CONFIG_BANK_ICON_SIZE = "Dimensione icona oggetto",
    CONFIG_BANK_SHOW_ITEM_LEVEL = "Mostra il livello oggetto",
    CONFIG_BEST_KEYS_FONT_SIZE = "Dimensione testo migliori chiavi",
    CONFIG_BEST_KEYS_OPACITY = "Opacita migliori chiavi",
    CONFIG_FONT_MENU_TITLE = "Font di vesperTools",
    CONFIG_NO_OWNED_TOY_MATCH = "Nessun giocattolo posseduto corrisponde a quel nome.",
    CONFIG_NO_OWNED_TOYS_AVAILABLE = "Nessun giocattolo posseduto disponibile",
    CONFIG_NO_TOYS_AVAILABLE = "Nessun giocattolo disponibile",
    CONFIG_PORTALS_FONT_SIZE = "Dimensione testo portali",
    CONFIG_PORTALS_OPACITY = "Opacita portali",
    CONFIG_PRIMARY_HEARTHSTONE = "Pietra del Ritorno primaria",
    CONFIG_ROSTER_FONT_SIZE = "Dimensione testo elenco",
    CONFIG_ROSTER_OPACITY = "Opacita elenco",
    CONFIG_SECTION_BAGS_WINDOW = "Finestra borse",
    CONFIG_SECTION_BANK_WINDOW = "Finestra banca",
    CONFIG_SECTION_BEST_KEYS_FRAME = "Riquadro migliori chiavi",
    CONFIG_SECTION_PORTALS_FRAME = "Riquadro portali",
    CONFIG_SECTION_ROSTER_FRAME = "Riquadro elenco",
    CONFIG_SHARED_FONT_FAMILY = "Famiglia di font condivisa",
    CONFIG_TAB_BAGS = "Borse",
    CONFIG_TAB_BANK = "Banca",
    CONFIG_TAB_BEST_KEYS = "Migliori chiavi",
    CONFIG_TAB_PORTALS = "Portali",
    CONFIG_TAB_ROSTER = "Elenco",
    CONFIG_TITLE = "Configurazione",
    CONFIG_TOP_UTILITY_BUTTON_SIZE = "Dimensione pulsanti Pietra/Giocattolo",
    CONFIG_TOY_FLYOUT_WHITELIST = "Whitelist menu giocattoli",
    CONTEXT_MENU_CLOSE = "Chiudi",
    CONTEXT_MENU_INVITE = "Invita",
    CONTEXT_MENU_WHISPER = "Sussurra",
    GREAT_VAULT = "Gran Banca",
    HEARTHSTONE = "Pietra del Ritorno",
    MAGE_PORTALS = "Portali del mago",
    MAGE_TELEPORTS = "Teletrasporti del mago",
    MINIMAP_TOOLTIP_MOVE = "Maiusc+Click sinistro e trascina: sposta icona",
    MINIMAP_TOOLTIP_NOT_IN_GUILD = "Non sei in una gilda",
    MINIMAP_TOOLTIP_NO_GUILD_ONLINE = "Nessun membro della gilda online",
    MINIMAP_TOOLTIP_TITLE = "vesperTools",
    MINIMAP_TOOLTIP_TOGGLE = "Click sinistro: mostra/nascondi elenco",
    NO_HEARTHSTONES_AVAILABLE = "Nessuna Pietra del Ritorno disponibile",
    NO_PORTAL_SPELLS_KNOWN = "Nessun incantesimo portale conosciuto",
    NO_TELEPORT_SPELLS_KNOWN = "Nessun incantesimo di teletrasporto conosciuto",
    NO_WHITELISTED_TOYS = "Nessun giocattolo nella whitelist",
    PLAYER_NOT_IN_GUILD = "Non sei in una gilda!",
    PORTALS_TOGGLE_IN_COMBAT = "Impossibile mostrare l'interfaccia in combattimento.",
    PORTALS_UI_NOT_INITIALIZED = "L'interfaccia dei portali non e ancora inizializzata.",
    ROSTER_BUTTON_CONFIG = "Conf",
    ROSTER_BUTTON_BAGS = "Borse",
    ROSTER_BUTTON_BANK = "Banca",
    ROSTER_BUTTON_SYNC = "Sync",
    ROSTER_COLUMN_FACTION = "F",
    ROSTER_COLUMN_ILVL = "iLvl",
    ROSTER_COLUMN_KEY = "KEY",
    ROSTER_COLUMN_NAME = "Nome",
    ROSTER_COLUMN_RATING = "V",
    ROSTER_COLUMN_STATUS = "Stato",
    ROSTER_COLUMN_ZONE = "Zona",
    ROSTER_TITLE_FALLBACK = "Elenco gilda",
    SLASH_COMMAND_HELP = "Apri la finestra di vesperTools",
    STATUS_AFK = "AFK",
    STATUS_DND = "DND",
    STATUS_ONLINE = "Online",
    TOY_FALLBACK = "Giocattolo",
    UNKNOWN_DUNGEON = "Sconosciuto",
    UNKNOWN_LABEL = "Sconosciuto",
    UTILITY_FALLBACK = "Utilita",
    UTILITY_TOYS = "Giocattoli utilita",
    UTILITY_TOYS_HINT = "Passa il mouse: apri menu",
    UTILITY_TOOLTIP_UNAVAILABLE = "Non disponibile",
    UTILITY_TOOLTIP_USE = "Click sinistro: usa",
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
