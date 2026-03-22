local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "ruRU")
end

if not L then
    return
end

local translations = {
    ADDON_LOADED_MESSAGE = "vesperTools успешно загружен!",
    ALL_FRAME_POSITIONS_RESET = "Все позиции окон были сброшены.",
    BANK_EMPTY = "Данные банка пока недоступны.",
    BANK_DEPOSIT_BUTTON = "Положить",
    BANK_SEARCH_PLACEHOLDER = "Поиск в банке",
    BANK_SWITCH_CHARACTER = "Банк",
    BANK_SWITCH_WARBAND = "Боевой отряд",
    BANK_TITLE = "Банк",
    BAGS_BACKPACK = "Рюкзак",
    BAGS_CATEGORY_CONSUMABLE = "Расходуемые",
    BAGS_CATEGORY_CONTAINER = "Контейнеры",
    BAGS_CATEGORY_EQUIPMENT = "Снаряжение",
    BAGS_CATEGORY_JUNK = "Хлам",
    BAGS_CATEGORY_MISC = "Разное",
    BAGS_CATEGORY_QUEST = "Задания",
    BAGS_CATEGORY_REAGENT = "Материалы для профессий",
    BAGS_CATEGORY_RECIPE = "Рецепты",
    BAGS_CATEGORY_TRADE_GOODS = "Хозяйственные товары",
    BAGS_CLEAR_NEW_ITEMS = "Очистить",
    BAGS_BAG_SLOTS = "Сумки",
    BAGS_COMBINE_BUTTON = "Объединить",
    BAGS_EMPTY = "Данные сумок пока недоступны.",
    BAGS_SEARCH_PLACEHOLDER = "Поиск в сумках",
    BAGS_TITLE = "Сумки",
    BAGS_LIVE = "Текущие",
    BAGS_READ_ONLY = "Снимок",
    CONFIG_ADD_BUTTON = "Добавить",
    CONFIG_ADD_TOY_BY_NAME = "Добавить игрушку по имени",
    CONFIG_BAGS_COLUMNS = "Количество столбцов",
    CONFIG_BAGS_ICON_SIZE = "Размер иконки предмета",
    CONFIG_BAGS_SHOW_ITEM_LEVEL = "Показывать уровень предмета",
    CONFIG_BANK_COLUMNS = "Количество столбцов",
    CONFIG_BANK_ICON_SIZE = "Размер иконки предмета",
    CONFIG_BANK_SHOW_ITEM_LEVEL = "Показывать уровень предмета",
    CONFIG_BEST_KEYS_FONT_SIZE = "Размер шрифта лучших ключей",
    CONFIG_BEST_KEYS_OPACITY = "Прозрачность лучших ключей",
    CONFIG_FONT_MENU_TITLE = "Шрифт vesperTools",
    CONFIG_NO_OWNED_TOY_MATCH = "Нет игрушек с таким именем в вашей коллекции.",
    CONFIG_NO_OWNED_TOYS_AVAILABLE = "Нет доступных игрушек в коллекции",
    CONFIG_NO_TOYS_AVAILABLE = "Нет доступных игрушек",
    CONFIG_PORTALS_FONT_SIZE = "Размер шрифта порталов",
    CONFIG_PORTALS_OPACITY = "Прозрачность порталов",
    CONFIG_PRIMARY_HEARTHSTONE = "Основной камень возвращения",
    CONFIG_ROSTER_FONT_SIZE = "Размер шрифта ростера",
    CONFIG_ROSTER_OPACITY = "Прозрачность ростера",
    CONFIG_SECTION_BAGS_WINDOW = "Окно сумок",
    CONFIG_SECTION_BANK_WINDOW = "Окно банка",
    CONFIG_SECTION_BEST_KEYS_FRAME = "Рамка лучших ключей",
    CONFIG_SECTION_PORTALS_FRAME = "Рамка порталов",
    CONFIG_SECTION_ROSTER_FRAME = "Рамка ростера",
    CONFIG_SHARED_FONT_FAMILY = "Общее семейство шрифта",
    CONFIG_TAB_BAGS = "Сумки",
    CONFIG_TAB_BANK = "Банк",
    CONFIG_TAB_BEST_KEYS = "Лучшие ключи",
    CONFIG_TAB_PORTALS = "Порталы",
    CONFIG_TAB_ROSTER = "Ростер",
    CONFIG_TITLE = "Настройки",
    CONFIG_TOP_UTILITY_BUTTON_SIZE = "Размер кнопок камня/игрушек",
    CONFIG_TOY_FLYOUT_WHITELIST = "Белый список меню игрушек",
    CONTEXT_MENU_CLOSE = "Закрыть",
    CONTEXT_MENU_INVITE = "Пригласить",
    CONTEXT_MENU_WHISPER = "Шепнуть",
    GREAT_VAULT = "Великое хранилище",
    HEARTHSTONE = "Камень возвращения",
    MAGE_PORTALS = "Порталы мага",
    MAGE_TELEPORTS = "Телепорты мага",
    MINIMAP_TOOLTIP_MOVE = "Shift+ЛКМ и перетаскивание: переместить значок",
    MINIMAP_TOOLTIP_NOT_IN_GUILD = "Вы не состоите в гильдии",
    MINIMAP_TOOLTIP_NO_GUILD_ONLINE = "Нет участников гильдии в сети",
    MINIMAP_TOOLTIP_TITLE = "vesperTools",
    MINIMAP_TOOLTIP_TOGGLE = "ЛКМ: переключить ростер",
    NO_HEARTHSTONES_AVAILABLE = "Нет доступных камней возвращения",
    NO_PORTAL_SPELLS_KNOWN = "Нет известных заклинаний портала",
    NO_TELEPORT_SPELLS_KNOWN = "Нет известных заклинаний телепорта",
    NO_WHITELISTED_TOYS = "Нет игрушек в белом списке",
    PLAYER_NOT_IN_GUILD = "Вы не состоите в гильдии!",
    PORTALS_TOGGLE_IN_COMBAT = "Нельзя переключать интерфейс в бою.",
    PORTALS_UI_NOT_INITIALIZED = "Интерфейс порталов еще не инициализирован.",
    ROSTER_BUTTON_CONFIG = "Конф",
    ROSTER_BUTTON_BAGS = "Сумки",
    ROSTER_BUTTON_BANK = "Банк",
    ROSTER_BUTTON_SYNC = "Синк",
    ROSTER_COLUMN_FACTION = "Ф",
    ROSTER_COLUMN_ILVL = "iLvl",
    ROSTER_COLUMN_KEY = "KEY",
    ROSTER_COLUMN_NAME = "Имя",
    ROSTER_COLUMN_RATING = "Р",
    ROSTER_COLUMN_STATUS = "Статус",
    ROSTER_COLUMN_ZONE = "Зона",
    ROSTER_TITLE_FALLBACK = "Ростер гильдии",
    SLASH_COMMAND_HELP = "Открыть окно vesperTools",
    STATUS_AFK = "AFК",
    STATUS_DND = "DND",
    STATUS_ONLINE = "В сети",
    TOY_FALLBACK = "Игрушка",
    UNKNOWN_DUNGEON = "Неизвестно",
    UNKNOWN_LABEL = "Неизвестно",
    UTILITY_FALLBACK = "Утилита",
    UTILITY_TOYS = "Полезные игрушки",
    UTILITY_TOYS_HINT = "Наведение: открыть меню",
    UTILITY_TOOLTIP_UNAVAILABLE = "Недоступно",
    UTILITY_TOOLTIP_USE = "ЛКМ: использовать",
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
