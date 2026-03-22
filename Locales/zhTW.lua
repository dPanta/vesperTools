local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "zhTW")
end

if not L then
    return
end

local translations = {
    ADDON_LOADED_MESSAGE = "vesperTools 載入成功！",
    ALL_FRAME_POSITIONS_RESET = "所有視窗位置已重設。",
    BANK_EMPTY = "目前還沒有銀行資料。",
    BANK_DEPOSIT_BUTTON = "存入",
    BANK_SEARCH_PLACEHOLDER = "搜尋銀行",
    BANK_SWITCH_CHARACTER = "銀行",
    BANK_SWITCH_WARBAND = "戰隊",
    BANK_TITLE = "銀行",
    BAGS_BACKPACK = "背包",
    BAGS_CATEGORY_CONSUMABLE = "消耗品",
    BAGS_CATEGORY_CONTAINER = "容器",
    BAGS_CATEGORY_EQUIPMENT = "裝備",
    BAGS_CATEGORY_JUNK = "垃圾",
    BAGS_CATEGORY_MISC = "其他",
    BAGS_CATEGORY_QUEST = "任務",
    BAGS_CATEGORY_REAGENT = "專業材料",
    BAGS_CATEGORY_RECIPE = "配方",
    BAGS_CATEGORY_TRADE_GOODS = "商品",
    BAGS_CLEAR_NEW_ITEMS = "清理",
    BAGS_BAG_SLOTS = "背包欄位",
    BAGS_COMBINE_BUTTON = "合併",
    BAGS_EMPTY = "目前還沒有背包資料。",
    BAGS_SEARCH_PLACEHOLDER = "搜尋背包",
    BAGS_TITLE = "背包",
    BAGS_LIVE = "即時",
    BAGS_READ_ONLY = "快照",
    CONFIG_ADD_BUTTON = "新增",
    CONFIG_ADD_TOY_BY_NAME = "依名稱新增玩具",
    CONFIG_BAGS_COLUMNS = "欄數",
    CONFIG_BAGS_ICON_SIZE = "物品圖示大小",
    CONFIG_BAGS_SHOW_ITEM_LEVEL = "顯示物品等級",
    CONFIG_BANK_COLUMNS = "欄數",
    CONFIG_BANK_ICON_SIZE = "物品圖示大小",
    CONFIG_BANK_SHOW_ITEM_LEVEL = "顯示物品等級",
    CONFIG_BEST_KEYS_FONT_SIZE = "最佳鑰石字體大小",
    CONFIG_BEST_KEYS_OPACITY = "最佳鑰石透明度",
    CONFIG_FONT_MENU_TITLE = "vesperTools 字體",
    CONFIG_NO_OWNED_TOY_MATCH = "沒有已擁有的玩具符合該名稱。",
    CONFIG_NO_OWNED_TOYS_AVAILABLE = "沒有可用的已擁有玩具",
    CONFIG_NO_TOYS_AVAILABLE = "沒有可用的玩具",
    CONFIG_PORTALS_FONT_SIZE = "傳送門字體大小",
    CONFIG_PORTALS_OPACITY = "傳送門透明度",
    CONFIG_PRIMARY_HEARTHSTONE = "主要爐石",
    CONFIG_ROSTER_FONT_SIZE = "名單字體大小",
    CONFIG_ROSTER_OPACITY = "名單透明度",
    CONFIG_SECTION_BAGS_WINDOW = "背包視窗",
    CONFIG_SECTION_BANK_WINDOW = "銀行視窗",
    CONFIG_SECTION_BEST_KEYS_FRAME = "最佳鑰石框架",
    CONFIG_SECTION_PORTALS_FRAME = "傳送門框架",
    CONFIG_SECTION_ROSTER_FRAME = "名單框架",
    CONFIG_SHARED_FONT_FAMILY = "共用字體",
    CONFIG_TAB_BAGS = "背包",
    CONFIG_TAB_BANK = "銀行",
    CONFIG_TAB_BEST_KEYS = "最佳鑰石",
    CONFIG_TAB_PORTALS = "傳送門",
    CONFIG_TAB_ROSTER = "名單",
    CONFIG_TITLE = "設定",
    CONFIG_TOP_UTILITY_BUTTON_SIZE = "爐石/玩具按鈕大小",
    CONFIG_TOY_FLYOUT_WHITELIST = "玩具選單白名單",
    CONTEXT_MENU_CLOSE = "關閉",
    CONTEXT_MENU_INVITE = "邀請",
    CONTEXT_MENU_WHISPER = "密語",
    GREAT_VAULT = "宏偉寶庫",
    HEARTHSTONE = "爐石",
    MAGE_PORTALS = "法師傳送門",
    MAGE_TELEPORTS = "法師傳送",
    MINIMAP_TOOLTIP_MOVE = "Shift+左鍵拖曳：移動圖示",
    MINIMAP_TOOLTIP_NOT_IN_GUILD = "你不在公會中",
    MINIMAP_TOOLTIP_NO_GUILD_ONLINE = "沒有線上的公會成員",
    MINIMAP_TOOLTIP_TITLE = "vesperTools",
    MINIMAP_TOOLTIP_TOGGLE = "左鍵：切換名單",
    NO_HEARTHSTONES_AVAILABLE = "沒有可用的爐石",
    NO_PORTAL_SPELLS_KNOWN = "沒有學會任何傳送門法術",
    NO_TELEPORT_SPELLS_KNOWN = "沒有學會任何傳送法術",
    NO_WHITELISTED_TOYS = "白名單中沒有玩具",
    PLAYER_NOT_IN_GUILD = "你不在公會中！",
    PORTALS_TOGGLE_IN_COMBAT = "戰鬥中無法切換介面。",
    PORTALS_UI_NOT_INITIALIZED = "傳送門介面尚未初始化。",
    ROSTER_BUTTON_CONFIG = "設定",
    ROSTER_BUTTON_BAGS = "背包",
    ROSTER_BUTTON_BANK = "銀行",
    ROSTER_BUTTON_SYNC = "同步",
    ROSTER_COLUMN_FACTION = "陣營",
    ROSTER_COLUMN_ILVL = "iLvl",
    ROSTER_COLUMN_KEY = "鑰石",
    ROSTER_COLUMN_NAME = "名稱",
    ROSTER_COLUMN_RATING = "分",
    ROSTER_COLUMN_STATUS = "狀態",
    ROSTER_COLUMN_ZONE = "區域",
    ROSTER_TITLE_FALLBACK = "公會名單",
    SLASH_COMMAND_HELP = "開啟 vesperTools 視窗",
    STATUS_AFK = "暫離",
    STATUS_DND = "勿擾",
    STATUS_ONLINE = "線上",
    TOY_FALLBACK = "玩具",
    UNKNOWN_DUNGEON = "未知",
    UNKNOWN_LABEL = "未知",
    UTILITY_FALLBACK = "工具",
    UTILITY_TOYS = "工具玩具",
    UTILITY_TOYS_HINT = "滑鼠移過：開啟選單",
    UTILITY_TOOLTIP_UNAVAILABLE = "無法使用",
    UTILITY_TOOLTIP_USE = "左鍵：使用",
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
