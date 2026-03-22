local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "frFR")
end

if not L then
    return
end

local translations = {
    ADDON_LOADED_MESSAGE = "vesperTools charge avec succes !",
    ALL_FRAME_POSITIONS_RESET = "Toutes les positions des fenetres ont ete reinitialisees.",
    BANK_EMPTY = "Aucune donnee de banque disponible pour le moment.",
    BANK_DEPOSIT_BUTTON = "Deposer",
    BANK_SEARCH_PLACEHOLDER = "Rechercher dans la banque",
    BANK_SWITCH_CHARACTER = "Banque",
    BANK_SWITCH_WARBAND = "Bataillon",
    BANK_TITLE = "Banque",
    BAGS_BACKPACK = "Sac a dos",
    BAGS_CATEGORY_CONSUMABLE = "Consommables",
    BAGS_CATEGORY_CONTAINER = "Conteneurs",
    BAGS_CATEGORY_EQUIPMENT = "Equipement",
    BAGS_CATEGORY_JUNK = "Camelote",
    BAGS_CATEGORY_MISC = "Divers",
    BAGS_CATEGORY_QUEST = "Quete",
    BAGS_CATEGORY_REAGENT = "Composants d'artisanat",
    BAGS_CATEGORY_RECIPE = "Recettes",
    BAGS_CATEGORY_TRADE_GOODS = "Marchandises",
    BAGS_CLEAR_NEW_ITEMS = "Nettoyer",
    BAGS_BAG_SLOTS = "Sacs",
    BAGS_COMBINE_BUTTON = "Combiner",
    BAGS_EMPTY = "Aucune donnee de sac disponible pour le moment.",
    BAGS_SEARCH_PLACEHOLDER = "Rechercher dans les sacs",
    BAGS_TITLE = "Sacs",
    BAGS_LIVE = "Direct",
    BAGS_READ_ONLY = "Instantane",
    CONFIG_ADD_BUTTON = "Ajouter",
    CONFIG_ADD_TOY_BY_NAME = "Ajouter un jouet par nom",
    CONFIG_BAGS_COLUMNS = "Nombre de colonnes",
    CONFIG_BAGS_ICON_SIZE = "Taille des icones d'objet",
    CONFIG_BAGS_SHOW_ITEM_LEVEL = "Afficher le niveau d'objet",
    CONFIG_BANK_COLUMNS = "Nombre de colonnes",
    CONFIG_BANK_ICON_SIZE = "Taille des icones d'objet",
    CONFIG_BANK_SHOW_ITEM_LEVEL = "Afficher le niveau d'objet",
    CONFIG_BEST_KEYS_FONT_SIZE = "Taille de police des meilleures cles",
    CONFIG_BEST_KEYS_OPACITY = "Opacite des meilleures cles",
    CONFIG_FONT_MENU_TITLE = "Police vesperTools",
    CONFIG_NO_OWNED_TOY_MATCH = "Aucun jouet possede ne correspond a ce nom.",
    CONFIG_NO_OWNED_TOYS_AVAILABLE = "Aucun jouet possede disponible",
    CONFIG_NO_TOYS_AVAILABLE = "Aucun jouet disponible",
    CONFIG_PORTALS_FONT_SIZE = "Taille de police des portails",
    CONFIG_PORTALS_OPACITY = "Opacite des portails",
    CONFIG_PRIMARY_HEARTHSTONE = "Pierre de foyer principale",
    CONFIG_ROSTER_FONT_SIZE = "Taille de police de la liste",
    CONFIG_ROSTER_OPACITY = "Opacite de la liste",
    CONFIG_SECTION_BAGS_WINDOW = "Fenetre des sacs",
    CONFIG_SECTION_BANK_WINDOW = "Fenetre de banque",
    CONFIG_SECTION_BEST_KEYS_FRAME = "Cadre des meilleures cles",
    CONFIG_SECTION_PORTALS_FRAME = "Cadre des portails",
    CONFIG_SECTION_ROSTER_FRAME = "Cadre de la liste",
    CONFIG_SHARED_FONT_FAMILY = "Famille de police partagee",
    CONFIG_TAB_BAGS = "Sacs",
    CONFIG_TAB_BANK = "Banque",
    CONFIG_TAB_BEST_KEYS = "Meilleures cles",
    CONFIG_TAB_PORTALS = "Portails",
    CONFIG_TAB_ROSTER = "Liste",
    CONFIG_TITLE = "Configuration",
    CONFIG_TOP_UTILITY_BUTTON_SIZE = "Taille des boutons pierre de foyer/jouet",
    CONFIG_TOY_FLYOUT_WHITELIST = "Liste blanche du menu jouets",
    CONTEXT_MENU_CLOSE = "Fermer",
    CONTEXT_MENU_INVITE = "Inviter",
    CONTEXT_MENU_WHISPER = "Chuchoter",
    GREAT_VAULT = "Grand coffre",
    HEARTHSTONE = "Pierre de foyer",
    MAGE_PORTALS = "Portails de mage",
    MAGE_TELEPORTS = "Teleports de mage",
    MINIMAP_TOOLTIP_MOVE = "Maj+Clic gauche et glisser : deplacer l'icone",
    MINIMAP_TOOLTIP_NOT_IN_GUILD = "Vous n'etes dans aucune guilde",
    MINIMAP_TOOLTIP_NO_GUILD_ONLINE = "Aucun membre de guilde en ligne",
    MINIMAP_TOOLTIP_TITLE = "vesperTools",
    MINIMAP_TOOLTIP_TOGGLE = "Clic gauche : afficher/masquer la liste",
    NO_HEARTHSTONES_AVAILABLE = "Aucune pierre de foyer disponible",
    NO_PORTAL_SPELLS_KNOWN = "Aucun sort de portail connu",
    NO_TELEPORT_SPELLS_KNOWN = "Aucun sort de teleportation connu",
    NO_WHITELISTED_TOYS = "Aucun jouet dans la liste blanche",
    PLAYER_NOT_IN_GUILD = "Vous n'etes dans aucune guilde !",
    PORTALS_TOGGLE_IN_COMBAT = "Impossible d'afficher l'interface en combat.",
    PORTALS_UI_NOT_INITIALIZED = "L'interface des portails n'est pas encore initialisee.",
    ROSTER_BUTTON_CONFIG = "Conf",
    ROSTER_BUTTON_BAGS = "Sacs",
    ROSTER_BUTTON_BANK = "Banque",
    ROSTER_BUTTON_SYNC = "Sync",
    ROSTER_COLUMN_FACTION = "F",
    ROSTER_COLUMN_ILVL = "iLvl",
    ROSTER_COLUMN_KEY = "CLE",
    ROSTER_COLUMN_NAME = "Nom",
    ROSTER_COLUMN_RATING = "N",
    ROSTER_COLUMN_STATUS = "Statut",
    ROSTER_COLUMN_ZONE = "Zone",
    ROSTER_TITLE_FALLBACK = "Liste de guilde",
    SLASH_COMMAND_HELP = "Ouvrir la fenetre vesperTools",
    STATUS_AFK = "AFK",
    STATUS_DND = "NPD",
    STATUS_ONLINE = "En ligne",
    TOY_FALLBACK = "Jouet",
    UNKNOWN_DUNGEON = "Inconnu",
    UNKNOWN_LABEL = "Inconnu",
    UTILITY_FALLBACK = "Utilitaire",
    UTILITY_TOYS = "Jouets utilitaires",
    UTILITY_TOYS_HINT = "Survol : ouvrir le menu",
    UTILITY_TOOLTIP_UNAVAILABLE = "Indisponible",
    UTILITY_TOOLTIP_USE = "Clic gauche : utiliser",
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
