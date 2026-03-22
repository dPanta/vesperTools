local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "esES")
end

if not L then
    return
end

local translations = {
    ADDON_LOADED_MESSAGE = "vesperTools se ha cargado correctamente.",
    ALL_FRAME_POSITIONS_RESET = "Se han restablecido todas las posiciones de las ventanas.",
    BANK_EMPTY = "Todavia no hay datos del banco.",
    BANK_DEPOSIT_BUTTON = "Depositar",
    BANK_SEARCH_PLACEHOLDER = "Buscar en el banco",
    BANK_SWITCH_CHARACTER = "Banco",
    BANK_SWITCH_WARBAND = "Banda guerrera",
    BANK_TITLE = "Banco",
    BAGS_BACKPACK = "Mochila",
    BAGS_CATEGORY_CONSUMABLE = "Consumibles",
    BAGS_CATEGORY_CONTAINER = "Contenedores",
    BAGS_CATEGORY_EQUIPMENT = "Equipo",
    BAGS_CATEGORY_JUNK = "Basura",
    BAGS_CATEGORY_MISC = "Varios",
    BAGS_CATEGORY_QUEST = "Mision",
    BAGS_CATEGORY_REAGENT = "Reactivos de profesiones",
    BAGS_CATEGORY_RECIPE = "Recetas",
    BAGS_CATEGORY_TRADE_GOODS = "Objetos comerciables",
    BAGS_CLEAR_NEW_ITEMS = "Limpiar",
    BAGS_BAG_SLOTS = "Bolsas",
    BAGS_COMBINE_BUTTON = "Combinar",
    BAGS_EMPTY = "Todavia no hay datos de las bolsas.",
    BAGS_SEARCH_PLACEHOLDER = "Buscar en las bolsas",
    BAGS_TITLE = "Bolsas",
    BAGS_LIVE = "En vivo",
    BAGS_READ_ONLY = "Instantanea",
    CONFIG_ADD_BUTTON = "Anadir",
    CONFIG_ADD_TOY_BY_NAME = "Anadir juguete por nombre",
    CONFIG_BAGS_COLUMNS = "Numero de columnas",
    CONFIG_BAGS_ICON_SIZE = "Tamano del icono del objeto",
    CONFIG_BAGS_SHOW_ITEM_LEVEL = "Mostrar nivel de objeto",
    CONFIG_BANK_COLUMNS = "Numero de columnas",
    CONFIG_BANK_ICON_SIZE = "Tamano del icono del objeto",
    CONFIG_BANK_SHOW_ITEM_LEVEL = "Mostrar nivel de objeto",
    CONFIG_BEST_KEYS_FONT_SIZE = "Tamano de fuente de mejores llaves",
    CONFIG_BEST_KEYS_OPACITY = "Opacidad de mejores llaves",
    CONFIG_FONT_MENU_TITLE = "Fuente de vesperTools",
    CONFIG_NO_OWNED_TOY_MATCH = "Ningun juguete que poseas coincide con ese nombre.",
    CONFIG_NO_OWNED_TOYS_AVAILABLE = "No hay juguetes disponibles en tu coleccion",
    CONFIG_NO_TOYS_AVAILABLE = "No hay juguetes disponibles",
    CONFIG_PORTALS_FONT_SIZE = "Tamano de fuente de portales",
    CONFIG_PORTALS_OPACITY = "Opacidad de portales",
    CONFIG_PRIMARY_HEARTHSTONE = "Piedra de hogar principal",
    CONFIG_ROSTER_FONT_SIZE = "Tamano de fuente del roster",
    CONFIG_ROSTER_OPACITY = "Opacidad del roster",
    CONFIG_SECTION_BAGS_WINDOW = "Ventana de bolsas",
    CONFIG_SECTION_BANK_WINDOW = "Ventana de banco",
    CONFIG_SECTION_BEST_KEYS_FRAME = "Marco de mejores llaves",
    CONFIG_SECTION_PORTALS_FRAME = "Marco de portales",
    CONFIG_SECTION_ROSTER_FRAME = "Marco del roster",
    CONFIG_SHARED_FONT_FAMILY = "Familia de fuente compartida",
    CONFIG_TAB_BAGS = "Bolsas",
    CONFIG_TAB_BANK = "Banco",
    CONFIG_TAB_BEST_KEYS = "Mejores llaves",
    CONFIG_TAB_PORTALS = "Portales",
    CONFIG_TAB_ROSTER = "Roster",
    CONFIG_TITLE = "Configuracion",
    CONFIG_TOP_UTILITY_BUTTON_SIZE = "Tamano de botones de piedra/juguete",
    CONFIG_TOY_FLYOUT_WHITELIST = "Lista blanca del menu de juguetes",
    CONTEXT_MENU_CLOSE = "Cerrar",
    CONTEXT_MENU_INVITE = "Invitar",
    CONTEXT_MENU_WHISPER = "Susurrar",
    GREAT_VAULT = "Gran boveda",
    HEARTHSTONE = "Piedra de hogar",
    MAGE_PORTALS = "Portales de mago",
    MAGE_TELEPORTS = "Teletransportes de mago",
    MINIMAP_TOOLTIP_MOVE = "Mayus+Click izquierdo y arrastrar: mover icono",
    MINIMAP_TOOLTIP_NOT_IN_GUILD = "No estas en una hermandad",
    MINIMAP_TOOLTIP_NO_GUILD_ONLINE = "No hay miembros de la hermandad conectados",
    MINIMAP_TOOLTIP_TITLE = "vesperTools",
    MINIMAP_TOOLTIP_TOGGLE = "Click izquierdo: mostrar/ocultar roster",
    NO_HEARTHSTONES_AVAILABLE = "No hay piedras de hogar disponibles",
    NO_PORTAL_SPELLS_KNOWN = "No conoces ningun hechizo de portal",
    NO_TELEPORT_SPELLS_KNOWN = "No conoces ningun hechizo de teletransporte",
    NO_WHITELISTED_TOYS = "No hay juguetes en la lista blanca",
    PLAYER_NOT_IN_GUILD = "No estas en una hermandad!",
    PORTALS_TOGGLE_IN_COMBAT = "No puedes mostrar la interfaz en combate.",
    PORTALS_UI_NOT_INITIALIZED = "La interfaz de portales aun no se ha inicializado.",
    ROSTER_BUTTON_CONFIG = "Conf",
    ROSTER_BUTTON_BAGS = "Bolsas",
    ROSTER_BUTTON_BANK = "Banco",
    ROSTER_BUTTON_SYNC = "Sync",
    ROSTER_COLUMN_FACTION = "F",
    ROSTER_COLUMN_ILVL = "iLvl",
    ROSTER_COLUMN_KEY = "KEY",
    ROSTER_COLUMN_NAME = "Nombre",
    ROSTER_COLUMN_RATING = "P",
    ROSTER_COLUMN_STATUS = "Estado",
    ROSTER_COLUMN_ZONE = "Zona",
    ROSTER_TITLE_FALLBACK = "Roster de hermandad",
    SLASH_COMMAND_HELP = "Abrir la ventana de vesperTools",
    STATUS_AFK = "AFK",
    STATUS_DND = "DND",
    STATUS_ONLINE = "En linea",
    TOY_FALLBACK = "Juguete",
    UNKNOWN_DUNGEON = "Desconocido",
    UNKNOWN_LABEL = "Desconocido",
    UTILITY_FALLBACK = "Utilidad",
    UTILITY_TOYS = "Juguetes de utilidad",
    UTILITY_TOYS_HINT = "Pasar el raton: abrir menu",
    UTILITY_TOOLTIP_UNAVAILABLE = "No disponible",
    UTILITY_TOOLTIP_USE = "Click izquierdo: usar",
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
