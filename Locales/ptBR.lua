local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "ptBR")
end

if not L then
    return
end

local translations = {
    ADDON_LOADED_MESSAGE = "vesperTools carregado com sucesso!",
    ALL_FRAME_POSITIONS_RESET = "Todas as posicoes das janelas foram redefinidas.",
    BANK_EMPTY = "Ainda nao ha dados do banco disponiveis.",
    BANK_DEPOSIT_BUTTON = "Depositar",
    BANK_SEARCH_PLACEHOLDER = "Pesquisar no banco",
    BANK_SWITCH_CHARACTER = "Banco",
    BANK_SWITCH_WARBAND = "Bando de Guerra",
    BANK_TITLE = "Banco",
    BAGS_BACKPACK = "Mochila",
    BAGS_CATEGORY_CONSUMABLE = "Consumiveis",
    BAGS_CATEGORY_CONTAINER = "Recipientes",
    BAGS_CATEGORY_EQUIPMENT = "Equipamento",
    BAGS_CATEGORY_JUNK = "Sucata",
    BAGS_CATEGORY_MISC = "Diversos",
    BAGS_CATEGORY_QUEST = "Missao",
    BAGS_CATEGORY_REAGENT = "Reagentes de profissao",
    BAGS_CATEGORY_RECIPE = "Receitas",
    BAGS_CATEGORY_TRADE_GOODS = "Mercadorias",
    BAGS_CLEAR_NEW_ITEMS = "Limpar",
    BAGS_BAG_SLOTS = "Bolsas",
    BAGS_COMBINE_BUTTON = "Combinar",
    BAGS_EMPTY = "Ainda nao ha dados das bolsas disponiveis.",
    BAGS_SEARCH_PLACEHOLDER = "Pesquisar nas bolsas",
    BAGS_TITLE = "Bolsas",
    BAGS_LIVE = "Ao vivo",
    BAGS_READ_ONLY = "Instantaneo",
    CONFIG_ADD_BUTTON = "Adicionar",
    CONFIG_ADD_TOY_BY_NAME = "Adicionar brinquedo por nome",
    CONFIG_BAGS_COLUMNS = "Numero de colunas",
    CONFIG_BAGS_ICON_SIZE = "Tamanho do icone do item",
    CONFIG_BAGS_SHOW_ITEM_LEVEL = "Mostrar nivel do item",
    CONFIG_BANK_COLUMNS = "Numero de colunas",
    CONFIG_BANK_ICON_SIZE = "Tamanho do icone do item",
    CONFIG_BANK_SHOW_ITEM_LEVEL = "Mostrar nivel do item",
    CONFIG_BEST_KEYS_FONT_SIZE = "Tamanho da fonte das melhores chaves",
    CONFIG_BEST_KEYS_OPACITY = "Opacidade das melhores chaves",
    CONFIG_FONT_MENU_TITLE = "Fonte do vesperTools",
    CONFIG_NO_OWNED_TOY_MATCH = "Nenhum brinquedo possuido corresponde a esse nome.",
    CONFIG_NO_OWNED_TOYS_AVAILABLE = "Nenhum brinquedo possuido disponivel",
    CONFIG_NO_TOYS_AVAILABLE = "Nenhum brinquedo disponivel",
    CONFIG_PORTALS_FONT_SIZE = "Tamanho da fonte dos portais",
    CONFIG_PORTALS_OPACITY = "Opacidade dos portais",
    CONFIG_PRIMARY_HEARTHSTONE = "Pedra de Regresso principal",
    CONFIG_ROSTER_FONT_SIZE = "Tamanho da fonte da lista",
    CONFIG_ROSTER_OPACITY = "Opacidade da lista",
    CONFIG_SECTION_BAGS_WINDOW = "Janela de bolsas",
    CONFIG_SECTION_BANK_WINDOW = "Janela do banco",
    CONFIG_SECTION_BEST_KEYS_FRAME = "Quadro das melhores chaves",
    CONFIG_SECTION_PORTALS_FRAME = "Quadro dos portais",
    CONFIG_SECTION_ROSTER_FRAME = "Quadro da lista",
    CONFIG_SHARED_FONT_FAMILY = "Familia de fonte compartilhada",
    CONFIG_TAB_BAGS = "Bolsas",
    CONFIG_TAB_BANK = "Banco",
    CONFIG_TAB_BEST_KEYS = "Melhores chaves",
    CONFIG_TAB_PORTALS = "Portais",
    CONFIG_TAB_ROSTER = "Lista",
    CONFIG_TITLE = "Configuracao",
    CONFIG_TOP_UTILITY_BUTTON_SIZE = "Tamanho dos botoes Pedra/Brinquedo",
    CONFIG_TOY_FLYOUT_WHITELIST = "Lista permitida do menu de brinquedos",
    CONTEXT_MENU_CLOSE = "Fechar",
    CONTEXT_MENU_INVITE = "Convidar",
    CONTEXT_MENU_WHISPER = "Sussurrar",
    GREAT_VAULT = "Grande Cofre",
    HEARTHSTONE = "Pedra de Regresso",
    MAGE_PORTALS = "Portais de mago",
    MAGE_TELEPORTS = "Teletransportes de mago",
    MINIMAP_TOOLTIP_MOVE = "Shift+Clique esquerdo e arrastar: mover icone",
    MINIMAP_TOOLTIP_NOT_IN_GUILD = "Voce nao esta em uma guilda",
    MINIMAP_TOOLTIP_NO_GUILD_ONLINE = "Nenhum membro da guilda online",
    MINIMAP_TOOLTIP_TITLE = "vesperTools",
    MINIMAP_TOOLTIP_TOGGLE = "Clique esquerdo: alternar lista",
    NO_HEARTHSTONES_AVAILABLE = "Nenhuma Pedra de Regresso disponivel",
    NO_PORTAL_SPELLS_KNOWN = "Nenhuma magia de portal conhecida",
    NO_TELEPORT_SPELLS_KNOWN = "Nenhuma magia de teleporte conhecida",
    NO_WHITELISTED_TOYS = "Nenhum brinquedo na lista permitida",
    PLAYER_NOT_IN_GUILD = "Voce nao esta em uma guilda!",
    PORTALS_TOGGLE_IN_COMBAT = "Nao e possivel alternar a interface em combate.",
    PORTALS_UI_NOT_INITIALIZED = "A interface dos portais ainda nao foi inicializada.",
    ROSTER_BUTTON_CONFIG = "Conf",
    ROSTER_BUTTON_BAGS = "Bolsas",
    ROSTER_BUTTON_BANK = "Banco",
    ROSTER_BUTTON_SYNC = "Sync",
    ROSTER_COLUMN_FACTION = "F",
    ROSTER_COLUMN_ILVL = "iLvl",
    ROSTER_COLUMN_KEY = "KEY",
    ROSTER_COLUMN_NAME = "Nome",
    ROSTER_COLUMN_RATING = "P",
    ROSTER_COLUMN_STATUS = "Status",
    ROSTER_COLUMN_ZONE = "Zona",
    ROSTER_TITLE_FALLBACK = "Lista da guilda",
    SLASH_COMMAND_HELP = "Abrir janela do vesperTools",
    STATUS_AFK = "AFK",
    STATUS_DND = "DND",
    STATUS_ONLINE = "Online",
    TOY_FALLBACK = "Brinquedo",
    UNKNOWN_DUNGEON = "Desconhecido",
    UNKNOWN_LABEL = "Desconhecido",
    UTILITY_FALLBACK = "Utilitario",
    UTILITY_TOYS = "Brinquedos utilitarios",
    UTILITY_TOYS_HINT = "Passe o mouse: abrir menu",
    UTILITY_TOOLTIP_UNAVAILABLE = "Indisponivel",
    UTILITY_TOOLTIP_USE = "Clique esquerdo: usar",
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
