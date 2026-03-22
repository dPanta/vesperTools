local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "zhCN")
end

if not L then
    return
end

local translations = {
    ADDON_LOADED_MESSAGE = "vesperTools加载成功！",
    ALL_FRAME_POSITIONS_RESET = "所有窗口位置已重置。",
    BANK_EMPTY = "目前还没有银行数据。",
    BANK_DEPOSIT_BUTTON = "存入",
    BANK_SEARCH_PLACEHOLDER = "搜索银行",
    BANK_SWITCH_CHARACTER = "银行",
    BANK_SWITCH_WARBAND = "战团",
    BANK_TITLE = "银行",
    BAGS_BACKPACK = "背包",
    BAGS_CATEGORY_CONSUMABLE = "消耗品",
    BAGS_CATEGORY_CONTAINER = "容器",
    BAGS_CATEGORY_EQUIPMENT = "装备",
    BAGS_CATEGORY_JUNK = "垃圾",
    BAGS_CATEGORY_MISC = "杂项",
    BAGS_CATEGORY_QUEST = "任务",
    BAGS_CATEGORY_REAGENT = "专业材料",
    BAGS_CATEGORY_RECIPE = "配方",
    BAGS_CATEGORY_TRADE_GOODS = "商品",
    BAGS_CLEAR_NEW_ITEMS = "清理",
    BAGS_BAG_SLOTS = "背包栏位",
    BAGS_COMBINE_BUTTON = "合并",
    BAGS_EMPTY = "目前还没有背包数据。",
    BAGS_SEARCH_PLACEHOLDER = "搜索背包",
    BAGS_TITLE = "背包",
    BAGS_LIVE = "实时",
    BAGS_READ_ONLY = "快照",
    CONFIG_ADD_BUTTON = "添加",
    CONFIG_ADD_TOY_BY_NAME = "按名称添加玩具",
    CONFIG_BAGS_COLUMNS = "列数",
    CONFIG_BAGS_ICON_SIZE = "物品图标大小",
    CONFIG_BAGS_SHOW_ITEM_LEVEL = "显示物品等级",
    CONFIG_BANK_COLUMNS = "列数",
    CONFIG_BANK_ICON_SIZE = "物品图标大小",
    CONFIG_BANK_SHOW_ITEM_LEVEL = "显示物品等级",
    CONFIG_BEST_KEYS_FONT_SIZE = "最佳钥石字体大小",
    CONFIG_BEST_KEYS_OPACITY = "最佳钥石透明度",
    CONFIG_FONT_MENU_TITLE = "vesperTools 字体",
    CONFIG_NO_OWNED_TOY_MATCH = "没有拥有的玩具与该名称匹配。",
    CONFIG_NO_OWNED_TOYS_AVAILABLE = "没有可用的已拥有玩具",
    CONFIG_NO_TOYS_AVAILABLE = "没有可用的玩具",
    CONFIG_PORTALS_FONT_SIZE = "传送门字体大小",
    CONFIG_PORTALS_OPACITY = "传送门透明度",
    CONFIG_PRIMARY_HEARTHSTONE = "主炉石",
    CONFIG_ROSTER_FONT_SIZE = "名单字体大小",
    CONFIG_ROSTER_OPACITY = "名单透明度",
    CONFIG_SECTION_BAGS_WINDOW = "背包窗口",
    CONFIG_SECTION_BANK_WINDOW = "银行窗口",
    CONFIG_SECTION_BEST_KEYS_FRAME = "最佳钥石框体",
    CONFIG_SECTION_PORTALS_FRAME = "传送门框体",
    CONFIG_SECTION_ROSTER_FRAME = "名单框体",
    CONFIG_SHARED_FONT_FAMILY = "共享字体",
    CONFIG_TAB_BAGS = "背包",
    CONFIG_TAB_BANK = "银行",
    CONFIG_TAB_BEST_KEYS = "最佳钥石",
    CONFIG_TAB_PORTALS = "传送门",
    CONFIG_TAB_ROSTER = "名单",
    CONFIG_TITLE = "配置",
    CONFIG_TOP_UTILITY_BUTTON_SIZE = "炉石/玩具按钮大小",
    CONFIG_TOY_FLYOUT_WHITELIST = "玩具菜单白名单",
    CONTEXT_MENU_CLOSE = "关闭",
    CONTEXT_MENU_INVITE = "邀请",
    CONTEXT_MENU_WHISPER = "密语",
    GREAT_VAULT = "宏伟宝库",
    HEARTHSTONE = "炉石",
    MAGE_PORTALS = "法师传送门",
    MAGE_TELEPORTS = "法师传送",
    MINIMAP_TOOLTIP_MOVE = "Shift+左键拖动：移动图标",
    MINIMAP_TOOLTIP_NOT_IN_GUILD = "你不在公会中",
    MINIMAP_TOOLTIP_NO_GUILD_ONLINE = "没有在线公会成员",
    MINIMAP_TOOLTIP_TITLE = "vesperTools",
    MINIMAP_TOOLTIP_TOGGLE = "左键：切换名单",
    NO_HEARTHSTONES_AVAILABLE = "没有可用的炉石",
    NO_PORTAL_SPELLS_KNOWN = "未学会任何传送门法术",
    NO_TELEPORT_SPELLS_KNOWN = "未学会任何传送法术",
    NO_WHITELISTED_TOYS = "白名单中没有玩具",
    PLAYER_NOT_IN_GUILD = "你不在公会中！",
    PORTALS_TOGGLE_IN_COMBAT = "战斗中无法切换界面。",
    PORTALS_UI_NOT_INITIALIZED = "传送门界面尚未初始化。",
    ROSTER_BUTTON_CONFIG = "配置",
    ROSTER_BUTTON_BAGS = "背包",
    ROSTER_BUTTON_BANK = "银行",
    ROSTER_BUTTON_SYNC = "同步",
    ROSTER_COLUMN_FACTION = "阵营",
    ROSTER_COLUMN_ILVL = "iLvl",
    ROSTER_COLUMN_KEY = "钥石",
    ROSTER_COLUMN_NAME = "名称",
    ROSTER_COLUMN_RATING = "分",
    ROSTER_COLUMN_STATUS = "状态",
    ROSTER_COLUMN_ZONE = "区域",
    ROSTER_TITLE_FALLBACK = "公会名单",
    SLASH_COMMAND_HELP = "打开 vesperTools 窗口",
    STATUS_AFK = "离开",
    STATUS_DND = "勿扰",
    STATUS_ONLINE = "在线",
    TOY_FALLBACK = "玩具",
    UNKNOWN_DUNGEON = "未知",
    UNKNOWN_LABEL = "未知",
    UTILITY_FALLBACK = "工具",
    UTILITY_TOYS = "工具玩具",
    UTILITY_TOYS_HINT = "鼠标悬停：打开菜单",
    UTILITY_TOOLTIP_UNAVAILABLE = "不可用",
    UTILITY_TOOLTIP_USE = "左键：使用",
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
