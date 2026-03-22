local addonName, addonTable = ...
local L

if LibStub and LibStub("AceLocale-3.0", true) then
    L = LibStub("AceLocale-3.0"):NewLocale(addonName, "koKR")
end

if not L then
    return
end

local translations = {
    ADDON_LOADED_MESSAGE = "vesperTools가 정상적으로 로드되었습니다!",
    ALL_FRAME_POSITIONS_RESET = "모든 창 위치가 초기화되었습니다.",
    BANK_EMPTY = "아직 은행 데이터가 없습니다.",
    BANK_DEPOSIT_BUTTON = "보관",
    BANK_SEARCH_PLACEHOLDER = "은행 검색",
    BANK_SWITCH_CHARACTER = "은행",
    BANK_SWITCH_WARBAND = "전투부대",
    BANK_TITLE = "은행",
    BAGS_BACKPACK = "가방",
    BAGS_CATEGORY_CONSUMABLE = "소모품",
    BAGS_CATEGORY_CONTAINER = "보관함",
    BAGS_CATEGORY_EQUIPMENT = "장비",
    BAGS_CATEGORY_JUNK = "잡동사니",
    BAGS_CATEGORY_MISC = "기타",
    BAGS_CATEGORY_QUEST = "퀘스트",
    BAGS_CATEGORY_REAGENT = "전문기술 재료",
    BAGS_CATEGORY_RECIPE = "제조법",
    BAGS_CATEGORY_TRADE_GOODS = "거래 물품",
    BAGS_CLEAR_NEW_ITEMS = "정리",
    BAGS_BAG_SLOTS = "가방 슬롯",
    BAGS_COMBINE_BUTTON = "합치기",
    BAGS_EMPTY = "아직 가방 데이터가 없습니다.",
    BAGS_SEARCH_PLACEHOLDER = "가방 검색",
    BAGS_TITLE = "가방",
    BAGS_LIVE = "실시간",
    BAGS_READ_ONLY = "스냅샷",
    CONFIG_ADD_BUTTON = "추가",
    CONFIG_ADD_TOY_BY_NAME = "이름으로 장난감 추가",
    CONFIG_BAGS_COLUMNS = "열 수",
    CONFIG_BAGS_ICON_SIZE = "아이템 아이콘 크기",
    CONFIG_BAGS_SHOW_ITEM_LEVEL = "아이템 레벨 표시",
    CONFIG_BANK_COLUMNS = "열 수",
    CONFIG_BANK_ICON_SIZE = "아이템 아이콘 크기",
    CONFIG_BANK_SHOW_ITEM_LEVEL = "아이템 레벨 표시",
    CONFIG_BEST_KEYS_FONT_SIZE = "최고 쐐기 글꼴 크기",
    CONFIG_BEST_KEYS_OPACITY = "최고 쐐기 투명도",
    CONFIG_FONT_MENU_TITLE = "vesperTools 글꼴",
    CONFIG_NO_OWNED_TOY_MATCH = "해당 이름과 일치하는 보유 장난감이 없습니다.",
    CONFIG_NO_OWNED_TOYS_AVAILABLE = "사용 가능한 보유 장난감이 없습니다",
    CONFIG_NO_TOYS_AVAILABLE = "사용 가능한 장난감이 없습니다",
    CONFIG_PORTALS_FONT_SIZE = "포탈 글꼴 크기",
    CONFIG_PORTALS_OPACITY = "포탈 투명도",
    CONFIG_PRIMARY_HEARTHSTONE = "주 귀환석",
    CONFIG_ROSTER_FONT_SIZE = "명단 글꼴 크기",
    CONFIG_ROSTER_OPACITY = "명단 투명도",
    CONFIG_SECTION_BAGS_WINDOW = "가방 창",
    CONFIG_SECTION_BANK_WINDOW = "은행 창",
    CONFIG_SECTION_BEST_KEYS_FRAME = "최고 쐐기 프레임",
    CONFIG_SECTION_PORTALS_FRAME = "포탈 프레임",
    CONFIG_SECTION_ROSTER_FRAME = "명단 프레임",
    CONFIG_SHARED_FONT_FAMILY = "공용 글꼴",
    CONFIG_TAB_BAGS = "가방",
    CONFIG_TAB_BANK = "은행",
    CONFIG_TAB_BEST_KEYS = "최고 쐐기",
    CONFIG_TAB_PORTALS = "포탈",
    CONFIG_TAB_ROSTER = "명단",
    CONFIG_TITLE = "설정",
    CONFIG_TOP_UTILITY_BUTTON_SIZE = "귀환석/장난감 버튼 크기",
    CONFIG_TOY_FLYOUT_WHITELIST = "장난감 메뉴 허용 목록",
    CONTEXT_MENU_CLOSE = "닫기",
    CONTEXT_MENU_INVITE = "초대",
    CONTEXT_MENU_WHISPER = "귓속말",
    GREAT_VAULT = "위대한 금고",
    HEARTHSTONE = "귀환석",
    MAGE_PORTALS = "마법사 포탈",
    MAGE_TELEPORTS = "마법사 순간이동",
    MINIMAP_TOOLTIP_MOVE = "Shift+좌클릭 드래그: 아이콘 이동",
    MINIMAP_TOOLTIP_NOT_IN_GUILD = "길드에 속해 있지 않습니다",
    MINIMAP_TOOLTIP_NO_GUILD_ONLINE = "온라인 길드원이 없습니다",
    MINIMAP_TOOLTIP_TITLE = "vesperTools",
    MINIMAP_TOOLTIP_TOGGLE = "좌클릭: 명단 토글",
    NO_HEARTHSTONES_AVAILABLE = "사용 가능한 귀환석이 없습니다",
    NO_PORTAL_SPELLS_KNOWN = "배운 포탈 주문이 없습니다",
    NO_TELEPORT_SPELLS_KNOWN = "배운 순간이동 주문이 없습니다",
    NO_WHITELISTED_TOYS = "허용 목록에 장난감이 없습니다",
    PLAYER_NOT_IN_GUILD = "길드에 속해 있지 않습니다!",
    PORTALS_TOGGLE_IN_COMBAT = "전투 중에는 UI를 전환할 수 없습니다.",
    PORTALS_UI_NOT_INITIALIZED = "포탈 UI가 아직 초기화되지 않았습니다.",
    ROSTER_BUTTON_CONFIG = "설정",
    ROSTER_BUTTON_BAGS = "가방",
    ROSTER_BUTTON_BANK = "은행",
    ROSTER_BUTTON_SYNC = "동기화",
    ROSTER_COLUMN_FACTION = "진영",
    ROSTER_COLUMN_ILVL = "iLvl",
    ROSTER_COLUMN_KEY = "KEY",
    ROSTER_COLUMN_NAME = "이름",
    ROSTER_COLUMN_RATING = "점",
    ROSTER_COLUMN_STATUS = "상태",
    ROSTER_COLUMN_ZONE = "지역",
    ROSTER_TITLE_FALLBACK = "길드 명단",
    SLASH_COMMAND_HELP = "vesperTools 창 열기",
    STATUS_AFK = "자리비움",
    STATUS_DND = "방해 금지",
    STATUS_ONLINE = "온라인",
    TOY_FALLBACK = "장난감",
    UNKNOWN_DUNGEON = "알 수 없음",
    UNKNOWN_LABEL = "알 수 없음",
    UTILITY_FALLBACK = "유틸리티",
    UTILITY_TOYS = "유틸리티 장난감",
    UTILITY_TOYS_HINT = "마우스오버: 메뉴 열기",
    UTILITY_TOOLTIP_UNAVAILABLE = "사용 불가",
    UTILITY_TOOLTIP_USE = "좌클릭: 사용",
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
