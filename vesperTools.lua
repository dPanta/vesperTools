local addonName, addonTable = ...
local localeDefaults = addonTable.LocaleDefaults or {}

-- Core addon entry point.
-- Responsibilities:
-- 1) Initialize shared SavedVariables and profile defaults.
-- 2) Expose common helpers used across modules.
-- 3) Own the floating icon and top-level slash commands.

-- Provide a permissive locale table until AceLocale is ready.
local L = addonTable.L or {}
setmetatable(L, { __index = function(t, k) return k end })

-- Abort early with a readable fallback if bundled dependencies are missing.
if not LibStub or not LibStub("AceAddon-3.0", true) then
    print("|cffFF0000" .. addonName .. ":|r " .. (localeDefaults.ACE3_LIBRARIES_MISSING or "Ace3 libraries not found. Please install Ace3 in the Libs/ folder."))
    
    -- Fallback simple slash command to prove the addon is actually loaded
    SLASH_VESPERTOOLS1 = "/vg"
    SLASH_VESPERTOOLS2 = "/vesper"
    SlashCmdList["VESPERTOOLS"] = function(msg)
        print("|cffFF0000" .. addonName .. ":|r " .. (localeDefaults.NO_LIB_MODE_MESSAGE or "Running in No-Lib mode. Please install Ace3."))
    end
    return
end

-- Create the singleton addon object shared by every module file.
vesperTools = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local AceLocale = LibStub("AceLocale-3.0", true)
if AceLocale then
    L = AceLocale:GetLocale(addonName)
end
addonTable.L = L
vesperTools.L = L

-- Current and legacy DB names are kept side-by-side for transparent migration.
local CURRENT_MAIN_DB_NAME = "vesperToolsDB"
local CURRENT_BAGS_DB_NAME = "vesperToolsBagsDB"
local LEGACY_MAIN_DB_NAME = "VesperGuildDB"
local LEGACY_BAGS_DB_NAME = "VesperGuildBagsDB"

-- Request a guild roster refresh through the available client API variant.
local function RequestGuildRosterUpdate()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

function vesperTools:RequestGuildRosterUpdate()
    RequestGuildRosterUpdate()
end

-- Shared default font used when profile-specific value is missing or invalid.
local DEFAULT_FONT_KEY = "Expressway"
local DEFAULT_FONT_PATH = "Interface\\AddOns\\vesperTools\\Media\\expressway.ttf"
local DEFAULT_PRIMARY_HEARTHSTONE_ID = 6948
local RANDOM_DISCO_HEARTHSTONE_ID = -1
local RANDOM_DISCO_ICON_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\RandomDisco-64"
local PREFERRED_SECONDARY_HEARTHSTONE_ID = 253629 -- Personal Key to the Arcantina
local DEFAULT_TOP_UTILITY_BUTTON_SIZE = 52
local MIN_TOP_UTILITY_BUTTON_SIZE = 32
local MAX_TOP_UTILITY_BUTTON_SIZE = 72
local ADDON_WINDOW_STRATA = "FULLSCREEN_DIALOG"
local DEFAULT_BAGS_WINDOW_WIDTH = 900
local DEFAULT_BAGS_WINDOW_HEIGHT = 560
local DEFAULT_BAGS_COLUMNS = 10
local DEFAULT_BAGS_ITEM_ICON_SIZE = 38
local DEFAULT_BAGS_STACK_COUNT_FONT_SIZE = 11
local DEFAULT_BAGS_ITEM_LEVEL_FONT_SIZE = 9
local DEFAULT_BAGS_QUALITY_GLOW_INTENSITY = 0.65
local DEFAULT_BANK_WINDOW_WIDTH = 900
local DEFAULT_BANK_WINDOW_HEIGHT = 560
local DEFAULT_BANK_COLUMNS = 10
local DEFAULT_BANK_ITEM_ICON_SIZE = 38
local DEFAULT_BANK_STACK_COUNT_FONT_SIZE = 11
local DEFAULT_BANK_ITEM_LEVEL_FONT_SIZE = 9
local DEFAULT_BANK_QUALITY_GLOW_INTENSITY = 0.65
local MAX_UTILITY_TOY_WHITELIST = 15
local MAX_BAGS_CURRENCY_BAR_ENTRIES = 12
local MODERN_CLOSE_BUTTON_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\CloseModern-128"
local ESCAPE_BINDING_BUTTON_NAME = "vesperToolsEscapeBindingButton"
local GOLD_BAR_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_Coin_01"
local ROUNDED_WINDOW_CORNER_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\RoundedCornerFill-8"
local ROUNDED_WINDOW_BORDER_CORNER_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\RoundedCornerBorder-8"
local ROUNDED_WINDOW_CORNER_SIZE = 6

-- Curated font options exposed in configuration UI.
local FONT_OPTIONS = {
    { label = "Expressway", path = "Interface\\AddOns\\vesperTools\\Media\\expressway.ttf" },
    { label = "Noto Sans SemiBold", path = "Interface\\AddOns\\vesperTools\\Media\\NotoSans-SemiBold.ttf" },
    { label = "Ubuntu Nerd Regular", path = "Interface\\AddOns\\vesperTools\\Media\\UbuntuNerdFont-Regular.ttf" },
    { label = "Ubuntu Nerd Bold", path = "Interface\\AddOns\\vesperTools\\Media\\UbuntuNerdFont-Bold.ttf" },
    { label = "Ubuntu Nerd Condensed", path = "Interface\\AddOns\\vesperTools\\Media\\UbuntuNerdFont-Condensed.ttf" },
    { label = "Ubuntu Nerd Propo Regular", path = "Interface\\AddOns\\vesperTools\\Media\\UbuntuNerdFontPropo-Regular.ttf" },
}

local function normalizeMediaPath(path)
    if type(path) ~= "string" or path == "" then
        return path
    end

    local normalized = string.gsub(path, "/", "\\")
    if string.sub(string.lower(normalized), 1, 18) == "interface\\addons\\" then
        return "Interface\\AddOns\\" .. string.sub(normalized, 19)
    end

    return normalized
end

local FONT_OPTION_BY_LABEL = {}
local FONT_OPTION_BY_PATH = {}
local LibSharedMedia = LibStub("LibSharedMedia-3.0", true)

for i = 1, #FONT_OPTIONS do
    local option = FONT_OPTIONS[i]
    option.path = normalizeMediaPath(option.path)
    FONT_OPTION_BY_LABEL[option.label] = option
    FONT_OPTION_BY_PATH[option.path] = option
end

-- Ordered list of hearthstone variants exposed in config and utility buttons.
local HEARTHSTONE_CATALOG = {
    6948,   -- Hearthstone
    64488,  -- The Innkeeper's Daughter
    93672,  -- Dark Portal
    110560, -- Garrison Hearthstone
    140192, -- Dalaran Hearthstone
    162973, -- Greatfather Winter's Hearthstone
    163045, -- Headless Horseman's Hearthstone
    165669, -- Lunar Elder's Hearthstone
    165670, -- Peddlefeet's Lovely Hearthstone
    165802, -- Noble Gardener's Hearthstone
    166746, -- Fire Eater's Hearthstone
    166747, -- Brewfest Reveler's Hearthstone
    168907, -- Holographic Digitalization Hearthstone
    172179, -- Eternal Traveler's Hearthstone
    180290, -- Night Fae Hearthstone
    182773, -- Necrolord Hearthstone
    183716, -- Venthyr Sinstone
    184353, -- Kyrian Hearthstone
    188952, -- Dominated Hearthstone
    190196, -- Enlightened Hearthstone
    193588, -- Timewalker's Hearthstone
    200630, -- Ohn'ir Windsage's Hearthstone
    208704, -- Deepdweller's Earthen Hearthstone
    209035, -- Hearthstone of the Flame
    212337, -- Stone of the Hearth
    228940, -- Notorious Thread's Hearthstone
    236687, -- Explosive Hearthstone
    245970, -- P.O.S.T. Master's Express Hearthstone
    246565, -- Cosmic Hearthstone
    253629, -- Personal Key to the Arcantina
}

-- Primary dropdown excludes these so first button focuses on non-default utility choices.
local PRIMARY_HEARTHSTONE_BLACKLIST = {
    [110560] = true, -- Garrison Hearthstone
    [140192] = true, -- Dalaran Hearthstone
    [253629] = true, -- Personal Key to the Arcantina
}

local function normalizeIcon(iconValue)
    if type(iconValue) == "number" then
        if iconValue > 0 then
            return iconValue
        end
        return nil
    end

    if type(iconValue) == "string" then
        if iconValue == "" then
            return nil
        end

        local numeric = tonumber(iconValue)
        if numeric and numeric > 0 then
            return numeric
        end

        -- Only accept explicit texture paths as string icons.
        -- Plain localized names from APIs must not be treated as textures.
        if string.find(iconValue, "\\", 1, true) or string.find(iconValue, "/", 1, true) then
            return iconValue
        end

        return nil
    end

    return nil
end

local function normalizeCurrencyIcon(iconValue)
    local normalized = normalizeIcon(iconValue)
    if normalized then
        return normalized
    end

    if type(iconValue) == "string" and iconValue ~= "" then
        local iconPath = iconValue
        if not (string.find(iconPath, "\\", 1, true) or string.find(iconPath, "/", 1, true)) then
            iconPath = "Interface\\Icons\\" .. iconPath
        end
        return iconPath
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function normalizeExpansionID(expansionID)
    local numericID = tonumber(expansionID)
    if not numericID then
        return nil
    end

    numericID = math.floor(numericID + 0.5)
    if numericID < 0 then
        return nil
    end

    return numericID
end

local function getCurrentExpansionID()
    local currentExpansionID = normalizeExpansionID(_G and _G.LE_EXPANSION_LEVEL_CURRENT)
    if currentExpansionID ~= nil then
        return currentExpansionID
    end

    if type(GetServerExpansionLevel) == "function" then
        currentExpansionID = normalizeExpansionID(GetServerExpansionLevel())
        if currentExpansionID ~= nil then
            return currentExpansionID
        end
    end

    if type(GetExpansionLevel) == "function" then
        currentExpansionID = normalizeExpansionID(GetExpansionLevel())
        if currentExpansionID ~= nil then
            return currentExpansionID
        end
    end

    return nil
end

local function getCurrentExpansionName()
    local currentExpansionID = getCurrentExpansionID()
    if currentExpansionID == nil then
        return nil
    end

    local expansionName = _G["EXPANSION_NAME" .. currentExpansionID]
    if type(expansionName) == "string" and expansionName ~= "" then
        return expansionName
    end

    return nil
end

local function normalizeCurrencyLabel(text)
    if type(text) ~= "string" then
        return nil
    end

    local normalized = strtrim(text)
    if normalized == "" then
        return nil
    end

    normalized = normalized:gsub("[%s%p]+", " ")
    normalized = strtrim(normalized)
    if normalized == "" then
        return nil
    end

    return string.lower(normalized)
end

local function addNormalizedName(nameMap, text)
    local normalized = normalizeCurrencyLabel(text)
    if normalized then
        nameMap[normalized] = true
    end
end

local function getExpansionNameSet()
    local names = {}
    local highestExpansionID = normalizeExpansionID(_G and _G.LE_EXPANSION_LEVEL_CURRENT) or 15

    for expansionID = 0, highestExpansionID do
        addNormalizedName(names, _G and _G["EXPANSION_NAME" .. expansionID])
    end

    return names
end

local function getProfessionNameSet()
    local names = {}
    addNormalizedName(names, _G and _G.PROFESSIONS_BUTTON)
    addNormalizedName(names, _G and _G.TRADE_SKILLS)
    addNormalizedName(names, _G and _G.PROFESSIONS_JOURNAL_TITLE)
    addNormalizedName(names, _G and _G.SECONDARY_PROFESSION_TEXT)

    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local professionIndices = { GetProfessions() }
        for i = 1, #professionIndices do
            local professionIndex = professionIndices[i]
            if professionIndex then
                local professionName = GetProfessionInfo(professionIndex)
                addNormalizedName(names, professionName)
            end
        end
    end

    return names
end

local function labelContainsAnyToken(label, tokenMap)
    local normalizedLabel = normalizeCurrencyLabel(label)
    if not normalizedLabel or type(tokenMap) ~= "table" then
        return false
    end

    if tokenMap[normalizedLabel] then
        return true
    end

    for token in pairs(tokenMap) do
        if token ~= "" and string.find(normalizedLabel, token, 1, true) then
            return true
        end
    end

    return false
end

local function sanitizePrimaryHearthstoneSelection(value)
    local numeric = tonumber(value)
    if numeric == RANDOM_DISCO_HEARTHSTONE_ID then
        return RANDOM_DISCO_HEARTHSTONE_ID
    end

    numeric = math.floor((numeric or DEFAULT_PRIMARY_HEARTHSTONE_ID) + 0.5)
    if numeric <= 0 then
        return DEFAULT_PRIMARY_HEARTHSTONE_ID
    end

    return numeric
end

local function sanitizeCurrencyIDList(idList)
    if type(idList) ~= "table" then
        return {}
    end

    local sanitized = {}
    local seen = {}

    for i = 1, #idList do
        local currencyID = math.floor((tonumber(idList[i]) or 0) + 0.5)
        if currencyID > 0 and not seen[currencyID] then
            sanitized[#sanitized + 1] = currencyID
            seen[currencyID] = true

            if #sanitized >= MAX_BAGS_CURRENCY_BAR_ENTRIES then
                break
            end
        end
    end

    return sanitized
end

local function getCurrencyListSize()
    if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyListSize) == "function" then
        local ok, count = pcall(C_CurrencyInfo.GetCurrencyListSize)
        if ok then
            return math.max(0, math.floor((tonumber(count) or 0) + 0.5))
        end
    end

    if type(GetCurrencyListSize) == "function" then
        local ok, count = pcall(GetCurrencyListSize)
        if ok then
            return math.max(0, math.floor((tonumber(count) or 0) + 0.5))
        end
    end

    return 0
end

local function extractCurrencyIDFromLink(link)
    if type(link) ~= "string" or link == "" then
        return nil
    end

    local currencyID = link:match("H?currency:(%d+):")
    currencyID = tonumber(currencyID)
    if currencyID and currencyID > 0 then
        return math.floor(currencyID + 0.5)
    end

    return nil
end

local function getCurrencyListLink(index)
    if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyListLink) == "function" then
        local ok, link = pcall(C_CurrencyInfo.GetCurrencyListLink, index)
        if ok and type(link) == "string" and link ~= "" then
            return link
        end
    end

    return nil
end

local function getCurrencyListInfo(index)
    if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyListInfo) == "function" then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, index)
        if ok and type(info) == "table" then
            return {
                currencyID = tonumber(info.currencyID or info.currencyTypesID or info.currencyType) or nil,
                name = info.name,
                quantity = tonumber(info.quantity or info.count) or 0,
                iconFileID = normalizeCurrencyIcon(info.iconFileID or info.icon),
                isHeader = info.isHeader and true or false,
                isHeaderExpanded = info.isHeaderExpanded and true or false,
                isTypeUnused = info.isTypeUnused and true or false,
                isShowInBackpack = info.isShowInBackpack and true or false,
                discovered = info.discovered ~= false,
                maxQuantity = tonumber(info.maxQuantity) or 0,
                totalEarned = tonumber(info.totalEarned) or nil,
                maxWeeklyQuantity = tonumber(info.maxWeeklyQuantity) or 0,
                quantityEarnedThisWeek = tonumber(info.quantityEarnedThisWeek) or 0,
                description = info.description,
                useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty and true or false,
                canEarnPerWeek = info.canEarnPerWeek and true or false,
            }
        end
    end

    if type(GetCurrencyListInfo) == "function" then
        local results = { pcall(GetCurrencyListInfo, index) }
        local ok = table.remove(results, 1)
        local name = results[1]
        local isHeader = results[2]
        local isExpanded = results[3]
        local isUnused = results[4]
        local isWatched = results[5]
        local count = results[6]
        local icon = results[7]
        local maxQuantity = results[8]
        local discovered = results[9]
        local canEarnPerWeek = results[12]
        local earnedThisWeek = results[13]
        local currencyID = extractCurrencyIDFromLink(getCurrencyListLink(index))
        local currencyInfo = nil
        if currencyID and C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
            local infoOK, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
            if infoOK and type(info) == "table" then
                currencyInfo = info
            end
        end

        if ok and type(name) == "string" and name ~= "" then
            return {
                currencyID = currencyID,
                name = currencyInfo and currencyInfo.name or name,
                quantity = tonumber((currencyInfo and currencyInfo.quantity) or count or 0) or 0,
                iconFileID = normalizeCurrencyIcon((currencyInfo and currencyInfo.iconFileID) or icon),
                isHeader = isHeader and true or false,
                isHeaderExpanded = isExpanded and true or false,
                isTypeUnused = isUnused and true or false,
                isShowInBackpack = ((currencyInfo and currencyInfo.isShowInBackpack) or isWatched) and true or false,
                discovered = (currencyInfo and currencyInfo.discovered) ~= false and discovered ~= false,
                maxQuantity = tonumber((currencyInfo and currencyInfo.maxQuantity) or maxQuantity) or 0,
                totalEarned = tonumber(currencyInfo and currencyInfo.totalEarned) or nil,
                maxWeeklyQuantity = tonumber((currencyInfo and currencyInfo.maxWeeklyQuantity) or (canEarnPerWeek and maxQuantity) or 0) or 0,
                quantityEarnedThisWeek = tonumber((currencyInfo and currencyInfo.quantityEarnedThisWeek) or earnedThisWeek) or 0,
                description = currencyInfo and currencyInfo.description or nil,
                useTotalEarnedForMaxQty = currencyInfo and currencyInfo.useTotalEarnedForMaxQty and true or false,
                canEarnPerWeek = (currencyInfo and currencyInfo.canEarnPerWeek) or canEarnPerWeek and true or false,
            }
        end
    end

    return nil
end

local function getCurrencyInfoByID(currencyID)
    local numericCurrencyID = math.floor((tonumber(currencyID) or 0) + 0.5)
    if numericCurrencyID <= 0 then
        return nil
    end

    if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, numericCurrencyID)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return {
                currencyID = tonumber(info.currencyID) or numericCurrencyID,
                name = info.name,
                quantity = tonumber(info.quantity or info.count) or 0,
                iconFileID = normalizeCurrencyIcon(info.iconFileID or info.icon),
                isShowInBackpack = info.isShowInBackpack and true or false,
                discovered = info.discovered ~= false,
                maxQuantity = tonumber(info.maxQuantity) or 0,
                totalEarned = tonumber(info.totalEarned) or nil,
                maxWeeklyQuantity = tonumber(info.maxWeeklyQuantity) or 0,
                quantityEarnedThisWeek = tonumber(info.quantityEarnedThisWeek) or 0,
                description = info.description,
                useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty and true or false,
                canEarnPerWeek = info.canEarnPerWeek and true or false,
            }
        end
    end

    if type(GetCurrencyInfo) == "function" then
        local results = { pcall(GetCurrencyInfo, numericCurrencyID) }
        local ok = table.remove(results, 1)
        local name = results[1]
        local quantity = results[2]
        local icon = results[3]
        local earnedThisWeek = results[4]
        local maxWeeklyQuantity = results[5]
        local maxQuantity = results[6]
        local isDiscovered = results[7]

        if ok and type(name) == "string" and name ~= "" then
            return {
                currencyID = numericCurrencyID,
                name = name,
                quantity = tonumber(quantity) or 0,
                iconFileID = normalizeCurrencyIcon(icon),
                isShowInBackpack = false,
                discovered = isDiscovered ~= false,
                maxQuantity = tonumber(maxQuantity) or 0,
                totalEarned = nil,
                maxWeeklyQuantity = tonumber(maxWeeklyQuantity) or 0,
                quantityEarnedThisWeek = tonumber(earnedThisWeek) or 0,
                description = nil,
                useTotalEarnedForMaxQty = false,
                canEarnPerWeek = (tonumber(maxWeeklyQuantity) or 0) > 0,
            }
        end
    end

    return nil
end

local function getNumWatchedTokens()
    if type(GetNumWatchedTokens) == "function" then
        local ok, count = pcall(GetNumWatchedTokens)
        if ok then
            return math.max(0, math.floor((tonumber(count) or 0) + 0.5))
        end
    end

    return 0
end

local function getBackpackCurrencyInfo(index)
    local numericIndex = math.floor((tonumber(index) or 0) + 0.5)
    if numericIndex <= 0 then
        return nil
    end

    if C_CurrencyInfo and type(C_CurrencyInfo.GetBackpackCurrencyInfo) == "function" then
        local ok, info = pcall(C_CurrencyInfo.GetBackpackCurrencyInfo, numericIndex)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return {
                currencyID = tonumber(info.currencyID or info.currencyTypesID or info.currencyType) or nil,
                name = info.name,
                quantity = tonumber(info.quantity or info.count) or 0,
                iconFileID = normalizeCurrencyIcon(info.iconFileID or info.icon),
                isShowInBackpack = true,
                discovered = true,
                maxQuantity = 0,
                totalEarned = nil,
                maxWeeklyQuantity = 0,
                quantityEarnedThisWeek = 0,
                description = nil,
                useTotalEarnedForMaxQty = false,
                canEarnPerWeek = false,
            }
        end
    end

    if type(GetBackpackCurrencyInfo) == "function" then
        local ok, name, quantity, icon, currencyID = pcall(GetBackpackCurrencyInfo, numericIndex)
        if ok and type(name) == "string" and name ~= "" then
            local info = getCurrencyInfoByID(currencyID)
            if info then
                info.isShowInBackpack = true
                return info
            end

            return {
                currencyID = tonumber(currencyID) or nil,
                name = name,
                quantity = tonumber(quantity) or 0,
                iconFileID = normalizeCurrencyIcon(icon),
                isShowInBackpack = true,
                discovered = true,
                maxQuantity = 0,
                totalEarned = nil,
                maxWeeklyQuantity = 0,
                quantityEarnedThisWeek = 0,
                description = nil,
                useTotalEarnedForMaxQty = false,
                canEarnPerWeek = false,
            }
        end
    end

    return nil
end

-- Resolve display name and icon with layered fallbacks (toy API -> item APIs -> question mark).
local function getItemNameAndIcon(itemID)
    local name
    local icon

    if C_ToyBox and C_ToyBox.GetToyInfo then
        -- Retail API signatures vary by client patch:
        -- 1) name, icon, ...
        -- 2) itemID, name, icon, ...
        -- Accept both safely.
        local t1, t2, t3, t4, t5 = C_ToyBox.GetToyInfo(itemID)

        if type(t1) == "string" and t1 ~= "" then
            name = t1
        elseif type(t2) == "string" and t2 ~= "" then
            name = t2
        elseif type(t3) == "string" and t3 ~= "" then
            name = t3
        end

        icon = normalizeIcon(t3) or normalizeIcon(t2) or normalizeIcon(t4) or normalizeIcon(t5) or icon
    end

    if (not name or name == "") and C_Item and C_Item.GetItemNameByID then
        local itemName = C_Item.GetItemNameByID(itemID)
        if type(itemName) == "string" and itemName ~= "" then
            name = itemName
        end
    end

    if not name or name == "" then
        local itemName = GetItemInfo(itemID)
        if type(itemName) == "string" and itemName ~= "" then
            name = itemName
        end
    end

    if not icon and C_Item and C_Item.GetItemIconByID then
        icon = normalizeIcon(C_Item.GetItemIconByID(itemID)) or icon
    end

    if not icon and C_Item and C_Item.GetItemInfoInstant then
        local i1, i2, i3, i4, i5, i6, i7, i8, i9, i10 = C_Item.GetItemInfoInstant(itemID)
        icon = normalizeIcon(i3)
            or normalizeIcon(i5)
            or normalizeIcon(i10)
            or icon
    end

    if not icon then
        local i1, i2, i3, i4, i5, i6, i7, i8, i9, i10 = GetItemInfoInstant(itemID)
        icon = normalizeIcon(i3)
            or normalizeIcon(i5)
            or normalizeIcon(i10)
            or icon
    end

    if not icon and C_Item and C_Item.GetItemInfo then
        local itemInfo = C_Item.GetItemInfo(itemID)
        if type(itemInfo) == "table" then
            icon = normalizeIcon(itemInfo.iconFileID) or icon
        end
    end

    -- Mirror portal-button style: item spell icon is often the most stable visual for toys/items.
    if not icon and C_Item and C_Item.GetItemSpell and C_Spell and C_Spell.GetSpellInfo then
        local _, itemSpellID = C_Item.GetItemSpell(itemID)
        if itemSpellID then
            local spellInfo = C_Spell.GetSpellInfo(itemSpellID)
            icon = normalizeIcon(spellInfo and (spellInfo.iconID or spellInfo.originalIconID)) or icon
        end
    end

    if not icon and GetItemIcon then
        icon = normalizeIcon(GetItemIcon(itemID)) or icon
    end

    if not name or name == "" then
        name = string.format(L["ITEM_FALLBACK_FMT"], tostring(itemID))
    end
    if not icon then
        icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    end

    return name, icon
end

local function getFontOptionByLabel(label)
    if type(label) ~= "string" or label == "" then
        return nil
    end

    return FONT_OPTION_BY_LABEL[label]
end

local function getFontOptionByPath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    return FONT_OPTION_BY_PATH[normalizeMediaPath(path)]
end

local function getSharedMedia()
    if not LibSharedMedia and LibStub then
        LibSharedMedia = LibStub("LibSharedMedia-3.0", true)
    end

    return LibSharedMedia
end

local function getSharedMediaFontType(sharedMedia)
    if sharedMedia and type(sharedMedia.MediaType) == "table" and type(sharedMedia.MediaType.FONT) == "string" then
        return sharedMedia.MediaType.FONT
    end

    return "font"
end

local function getSharedMediaFontLocaleMask(sharedMedia)
    if not sharedMedia then
        return nil
    end

    local mask = 0
    mask = mask + (tonumber(sharedMedia.LOCALE_BIT_western) or 0)
    mask = mask + (tonumber(sharedMedia.LOCALE_BIT_koKR) or 0)
    mask = mask + (tonumber(sharedMedia.LOCALE_BIT_ruRU) or 0)
    mask = mask + (tonumber(sharedMedia.LOCALE_BIT_zhCN) or 0)
    mask = mask + (tonumber(sharedMedia.LOCALE_BIT_zhTW) or 0)

    return mask > 0 and mask or nil
end

local function getSharedMediaFontPath(sharedMedia, key)
    if not sharedMedia or type(sharedMedia.Fetch) ~= "function" or type(key) ~= "string" or key == "" then
        return nil
    end

    local ok, path = pcall(sharedMedia.Fetch, sharedMedia, getSharedMediaFontType(sharedMedia), key, true)
    if ok and type(path) == "string" and path ~= "" then
        return normalizeMediaPath(path)
    end

    return nil
end

local function getSharedMediaFontKeyByPath(sharedMedia, path)
    if not sharedMedia or type(path) ~= "string" or path == "" or type(sharedMedia.HashTable) ~= "function" then
        return nil
    end

    local fontTable = sharedMedia:HashTable(getSharedMediaFontType(sharedMedia))
    if type(fontTable) ~= "table" then
        return nil
    end

    local normalizedPath = normalizeMediaPath(path)
    for key, registeredPath in pairs(fontTable) do
        if normalizeMediaPath(registeredPath) == normalizedPath then
            return key
        end
    end

    return nil
end

function vesperTools:GetSharedMedia()
    return getSharedMedia()
end

function vesperTools:NormalizeMediaPath(path)
    return normalizeMediaPath(path)
end

function vesperTools:RegisterBundledSharedMediaFonts()
    local sharedMedia = self:GetSharedMedia()
    if not sharedMedia then
        return false
    end

    if self._bundledSharedMediaFontsRegistered then
        return true
    end

    local fontType = getSharedMediaFontType(sharedMedia)
    local localeMask = getSharedMediaFontLocaleMask(sharedMedia)

    for i = 1, #FONT_OPTIONS do
        local option = FONT_OPTIONS[i]
        if option and option.label and option.path and not sharedMedia:IsValid(fontType, option.label) then
            pcall(sharedMedia.Register, sharedMedia, fontType, option.label, option.path, localeMask)
        end
    end

    self._bundledSharedMediaFontsRegistered = true
    return true
end

function vesperTools:RefreshSharedMediaFonts()
    local Configuration = self:GetModule("Configuration", true)
    if Configuration and Configuration.panel and Configuration.panel:IsShown() then
        Configuration:RefreshControls()
    end
end

function vesperTools:OnSharedMediaRegistered(_, mediatype)
    local sharedMedia = self:GetSharedMedia()
    if mediatype ~= getSharedMediaFontType(sharedMedia) then
        return
    end

    self:RefreshSharedMediaFonts()
end

function vesperTools:InitializeSharedMediaSupport()
    self:RegisterBundledSharedMediaFonts()

    local sharedMedia = self:GetSharedMedia()
    if sharedMedia
        and type(sharedMedia.RegisterCallback) == "function"
        and not self._sharedMediaFontCallbackRegistered
    then
        sharedMedia.RegisterCallback(self, "LibSharedMedia_Registered", "OnSharedMediaRegistered")
        self._sharedMediaFontCallbackRegistered = true
    end
end

function vesperTools:GetConfiguredFontSelection()
    local profile = self.db and self.db.profile
    local style = profile and profile.style or nil
    local selectedKey = style and style.fontName or nil
    local selectedPath = style and normalizeMediaPath(style.fontPath) or nil
    local sharedMedia = self:GetSharedMedia()

    self:RegisterBundledSharedMediaFonts()

    if type(selectedKey) == "string" and selectedKey ~= "" then
        local resolvedPath = getSharedMediaFontPath(sharedMedia, selectedKey)
            or (getFontOptionByLabel(selectedKey) and getFontOptionByLabel(selectedKey).path)
        if type(resolvedPath) == "string" and resolvedPath ~= "" then
            if style then
                style.fontPath = resolvedPath
            end
            return selectedKey, resolvedPath
        end
    end

    if type(selectedPath) == "string" and selectedPath ~= "" then
        local bundledOption = getFontOptionByPath(selectedPath)
        if bundledOption then
            if style then
                style.fontName = bundledOption.label
                style.fontPath = bundledOption.path
            end
            return bundledOption.label, bundledOption.path
        end

        local sharedMediaKey = getSharedMediaFontKeyByPath(sharedMedia, selectedPath)
        if sharedMediaKey then
            local resolvedPath = getSharedMediaFontPath(sharedMedia, sharedMediaKey) or selectedPath
            if style then
                style.fontName = sharedMediaKey
                style.fontPath = resolvedPath
            end
            return sharedMediaKey, resolvedPath
        end

        return nil, selectedPath
    end

    if style then
        style.fontName = DEFAULT_FONT_KEY
        style.fontPath = DEFAULT_FONT_PATH
    end

    return DEFAULT_FONT_KEY, DEFAULT_FONT_PATH
end

function vesperTools:GetConfiguredFontKey()
    local key = self:GetConfiguredFontSelection()
    return key or DEFAULT_FONT_KEY
end

function vesperTools:GetConfiguredFontLabel()
    local key = self:GetConfiguredFontKey()
    if type(key) == "string" and key ~= "" then
        return key
    end

    return self:GetFontLabelByPath(self:GetConfiguredFontPath())
end

-- Return available bundled and SharedMedia font options for config UI.
function vesperTools:GetFontOptions()
    local options = {}
    local seen = {}
    local sharedMedia = self:GetSharedMedia()

    self:RegisterBundledSharedMediaFonts()

    if sharedMedia and type(sharedMedia.List) == "function" then
        local fontList = sharedMedia:List(getSharedMediaFontType(sharedMedia))
        if type(fontList) == "table" then
            for i = 1, #fontList do
                local key = fontList[i]
                local path = getSharedMediaFontPath(sharedMedia, key)
                if type(key) == "string" and key ~= "" and type(path) == "string" and path ~= "" and not seen[key] then
                    options[#options + 1] = {
                        key = key,
                        label = key,
                        path = path,
                        source = getFontOptionByLabel(key) and "bundled" or "sharedmedia",
                    }
                    seen[key] = true
                end
            end
        end
    end

    for i = 1, #FONT_OPTIONS do
        local option = FONT_OPTIONS[i]
        if option and option.label and option.path and not seen[option.label] then
            options[#options + 1] = {
                key = option.label,
                label = option.label,
                path = option.path,
                source = "bundled",
            }
            seen[option.label] = true
        end
    end

    table.sort(options, function(a, b)
        return (a.label or "") < (b.label or "")
    end)

    return options
end

-- Use one fixed high strata for addon-owned windows so they stay above regular UI.
function vesperTools:GetAddonWindowStrata()
    return ADDON_WINDOW_STRATA
end

-- Normalize addon-owned frames onto the shared strata and optionally pin a frame level.
function vesperTools:ApplyAddonWindowLayer(frame, frameLevel)
    if not frame then
        return
    end

    frame:SetFrameStrata(ADDON_WINDOW_STRATA)
    if frameLevel then
        frame:SetFrameLevel(frameLevel)
    end

    if frame.SetToplevel and frame:GetParent() == UIParent then
        frame:SetToplevel(true)
    end
end

local function getEscapeTargetKey(frame)
    if not frame then
        return nil
    end

    if type(frame.GetName) == "function" then
        local frameName = frame:GetName()
        if type(frameName) == "string" and frameName ~= "" then
            return frameName
        end
    end

    return tostring(frame)
end

function vesperTools:SetupEscapeBinding()
    if self.escapeBindingButton then
        return
    end

    local button = CreateFrame("Button", ESCAPE_BINDING_BUTTON_NAME, UIParent)
    button:SetSize(1, 1)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetScript("OnClick", function()
        self:HandleEscapeBindingPressed()
    end)
    button:Hide()

    self.escapeBindingButton = button
    self.escapeBindingEntries = self.escapeBindingEntries or {}

    if not self.escapeBindingEventRegistered then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self.escapeBindingEventRegistered = true
    end
end

function vesperTools:ScheduleEscapeBindingRefresh()
    self.escapeBindingNeedsRefresh = true
    if self.escapeBindingRefreshScheduled then
        return
    end

    self.escapeBindingRefreshScheduled = true
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            self.escapeBindingRefreshScheduled = false
            if self.escapeBindingNeedsRefresh then
                self:RefreshEscapeBinding()
            end
        end)
        return
    end

    self.escapeBindingRefreshScheduled = false
    self:RefreshEscapeBinding()
end

function vesperTools:HasVisibleEscapeTargets()
    local entries = self.escapeBindingEntries
    if type(entries) ~= "table" then
        return false
    end

    for _, entry in pairs(entries) do
        local frame = entry.frame
        if frame and type(frame.IsShown) == "function" and frame:IsShown() then
            return true
        end
    end

    return false
end

function vesperTools:RefreshEscapeBinding()
    self:SetupEscapeBinding()

    local button = self.escapeBindingButton
    if not button then
        return
    end

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self.escapeBindingPendingCombatRefresh = true
        self.escapeBindingNeedsRefresh = true
        return
    end

    self.escapeBindingPendingCombatRefresh = false
    self.escapeBindingNeedsRefresh = false

    if type(ClearOverrideBindings) == "function" then
        ClearOverrideBindings(button)
    end

    if self:HasVisibleEscapeTargets() and type(SetOverrideBindingClick) == "function" then
        SetOverrideBindingClick(button, true, "ESCAPE", button:GetName())
    end
end

function vesperTools:GetTopEscapeTargetEntry()
    local bestEntry = nil

    for _, entry in pairs(self.escapeBindingEntries or {}) do
        local frame = entry.frame
        if frame and type(frame.IsShown) == "function" and frame:IsShown() then
            local showOrder = tonumber(entry.showOrder) or 0
            if not bestEntry or showOrder > (tonumber(bestEntry.showOrder) or 0) then
                bestEntry = entry
            end
        end
    end

    return bestEntry
end

function vesperTools:OnEscapeTargetShown(frame)
    local key = getEscapeTargetKey(frame)
    local entry = key and self.escapeBindingEntries and self.escapeBindingEntries[key] or nil
    if not entry then
        return
    end

    self.escapeBindingShowSequence = (tonumber(self.escapeBindingShowSequence) or 0) + 1
    entry.showOrder = self.escapeBindingShowSequence
    self:ScheduleEscapeBindingRefresh()
end

function vesperTools:OnEscapeTargetHidden(frame)
    local key = getEscapeTargetKey(frame)
    if key and self.escapeBindingEntries and self.escapeBindingEntries[key] then
        self.escapeBindingEntries[key].showOrder = tonumber(self.escapeBindingEntries[key].showOrder) or 0
    end

    self:ScheduleEscapeBindingRefresh()
end

function vesperTools:RegisterEscapeFrame(frame, closeCallback)
    if not frame or type(frame.IsShown) ~= "function" then
        return
    end

    self:SetupEscapeBinding()

    local key = getEscapeTargetKey(frame)
    if not key then
        return
    end

    local entries = self.escapeBindingEntries
    local entry = entries[key]
    if not entry then
        entry = {}
        entries[key] = entry
    end

    entry.frame = frame
    entry.close = type(closeCallback) == "function" and closeCallback or function(selfFrame)
        if selfFrame and type(selfFrame.Hide) == "function" then
            selfFrame:Hide()
        end
    end

    if entry.hookedFrame ~= frame then
        frame:HookScript("OnShow", function(shownFrame)
            self:OnEscapeTargetShown(shownFrame)
        end)
        frame:HookScript("OnHide", function(hiddenFrame)
            self:OnEscapeTargetHidden(hiddenFrame)
        end)
        entry.hookedFrame = frame
    end

    if frame:IsShown() then
        self:OnEscapeTargetShown(frame)
    else
        self:ScheduleEscapeBindingRefresh()
    end
end

function vesperTools:HandleEscapeBindingPressed()
    local entry = self:GetTopEscapeTargetEntry()
    if not entry then
        self:ScheduleEscapeBindingRefresh()
        return
    end

    if type(entry.close) == "function" then
        entry.close(entry.frame)
        return
    end

    if entry.frame and type(entry.frame.Hide) == "function" then
        entry.frame:Hide()
    end
end

function vesperTools:PLAYER_REGEN_ENABLED()
    if self.escapeBindingNeedsRefresh or self.escapeBindingPendingCombatRefresh then
        self:RefreshEscapeBinding()
    end
end

function vesperTools:ApplyRoundedWindowBackdrop(frame, options)
    if not frame or type(frame.SetBackdrop) ~= "function" then
        return
    end

    local resolvedOptions = type(options) == "table" and options or {}
    local cornerTexture = resolvedOptions.cornerTexture or ROUNDED_WINDOW_CORNER_TEXTURE
    local borderCornerTexture = resolvedOptions.borderCornerTexture or ROUNDED_WINDOW_BORDER_CORNER_TEXTURE
    local cornerSize = math.max(2, math.floor((tonumber(resolvedOptions.cornerSize) or ROUNDED_WINDOW_CORNER_SIZE) + 0.5))

    frame:SetBackdrop({
        bgFile = resolvedOptions.bgFile or "Interface\\Buttons\\WHITE8x8",
        edgeFile = resolvedOptions.edgeFile or "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, math.floor((tonumber(resolvedOptions.edgeSize) or 1) + 0.5)),
    })

    local overlay = frame.vesperRoundedCornerOverlay
    if not overlay then
        overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        overlay:EnableMouse(false)
        overlay.corners = {}
        overlay.borderCorners = {}
        frame.vesperRoundedCornerOverlay = overlay

        local anchors = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
        for i = 1, #anchors do
            local corner = overlay:CreateTexture(nil, "OVERLAY", nil, 6)
            corner:SetTexture(cornerTexture)
            overlay.corners[anchors[i]] = corner

            local borderCorner = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
            borderCorner:SetTexture(borderCornerTexture)
            overlay.borderCorners[anchors[i]] = borderCorner
        end

        if not frame.vesperRoundedCornerHooked then
            local function syncRoundedOverlay(self)
                local roundedOverlay = self.vesperRoundedCornerOverlay
                if not roundedOverlay then
                    return
                end

                roundedOverlay:SetFrameStrata(self:GetFrameStrata())
                roundedOverlay:SetFrameLevel(math.max((self.GetFrameLevel and self:GetFrameLevel() or 0) + 40, 1))
            end

            hooksecurefunc(frame, "SetBackdropColor", function(self, r, g, b, a)
                local roundedOverlay = self.vesperRoundedCornerOverlay
                if not roundedOverlay or not roundedOverlay.corners then
                    return
                end

                syncRoundedOverlay(self)

                for _, texture in pairs(roundedOverlay.corners) do
                    texture:SetVertexColor(r or 0, g or 0, b or 0, a == nil and 1 or a)
                end
            end)
            hooksecurefunc(frame, "SetBackdropBorderColor", function(self, r, g, b, a)
                local roundedOverlay = self.vesperRoundedCornerOverlay
                if not roundedOverlay or not roundedOverlay.borderCorners then
                    return
                end

                syncRoundedOverlay(self)

                for _, texture in pairs(roundedOverlay.borderCorners) do
                    texture:SetVertexColor(r or 0, g or 0, b or 0, a == nil and 1 or a)
                end
            end)
            hooksecurefunc(frame, "SetFrameLevel", syncRoundedOverlay)
            hooksecurefunc(frame, "SetFrameStrata", syncRoundedOverlay)
            frame.vesperRoundedCornerHooked = true
        end
    end

    overlay:SetAllPoints(frame)
    overlay:SetFrameStrata(frame:GetFrameStrata())
    overlay:SetFrameLevel(math.max((frame:GetFrameLevel() or 0) + 40, 1))

    local topLeft = overlay.corners.TOPLEFT
    topLeft:ClearAllPoints()
    topLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    topLeft:SetSize(cornerSize, cornerSize)
    topLeft:SetTexCoord(0, 1, 0, 1)
    local topLeftBorder = overlay.borderCorners.TOPLEFT
    topLeftBorder:ClearAllPoints()
    topLeftBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    topLeftBorder:SetSize(cornerSize, cornerSize)
    topLeftBorder:SetTexCoord(0, 1, 0, 1)

    local topRight = overlay.corners.TOPRIGHT
    topRight:ClearAllPoints()
    topRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    topRight:SetSize(cornerSize, cornerSize)
    topRight:SetTexCoord(1, 0, 0, 1)
    local topRightBorder = overlay.borderCorners.TOPRIGHT
    topRightBorder:ClearAllPoints()
    topRightBorder:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    topRightBorder:SetSize(cornerSize, cornerSize)
    topRightBorder:SetTexCoord(1, 0, 0, 1)

    local bottomLeft = overlay.corners.BOTTOMLEFT
    bottomLeft:ClearAllPoints()
    bottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottomLeft:SetSize(cornerSize, cornerSize)
    bottomLeft:SetTexCoord(0, 1, 1, 0)
    local bottomLeftBorder = overlay.borderCorners.BOTTOMLEFT
    bottomLeftBorder:ClearAllPoints()
    bottomLeftBorder:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottomLeftBorder:SetSize(cornerSize, cornerSize)
    bottomLeftBorder:SetTexCoord(0, 1, 1, 0)

    local bottomRight = overlay.corners.BOTTOMRIGHT
    bottomRight:ClearAllPoints()
    bottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottomRight:SetSize(cornerSize, cornerSize)
    bottomRight:SetTexCoord(1, 0, 1, 0)
    local bottomRightBorder = overlay.borderCorners.BOTTOMRIGHT
    bottomRightBorder:ClearAllPoints()
    bottomRightBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottomRightBorder:SetSize(cornerSize, cornerSize)
    bottomRightBorder:SetTexCoord(1, 0, 1, 0)
end

function vesperTools:CreateModernCloseButton(parent, onClick, options)
    if not parent then
        return nil
    end

    local resolvedOptions = type(options) == "table" and options or {}
    local size = math.max(10, math.floor((tonumber(resolvedOptions.size) or 20) + 0.5))
    local iconScale = tonumber(resolvedOptions.iconScale) or 0.5
    local backgroundAlpha = tonumber(resolvedOptions.backgroundAlpha)
    if backgroundAlpha == nil then
        backgroundAlpha = 0.06
    end
    local borderAlpha = tonumber(resolvedOptions.borderAlpha)
    if borderAlpha == nil then
        borderAlpha = 0.1
    end
    local hoverAlpha = tonumber(resolvedOptions.hoverAlpha)
    if hoverAlpha == nil then
        hoverAlpha = 0.12
    end
    local pressedAlpha = tonumber(resolvedOptions.pressedAlpha)
    if pressedAlpha == nil then
        pressedAlpha = 0.18
    end
    local iconAlpha = tonumber(resolvedOptions.iconAlpha)
    if iconAlpha == nil then
        iconAlpha = 0.92
    end
    local iconHoverAlpha = tonumber(resolvedOptions.iconHoverAlpha)
    if iconHoverAlpha == nil then
        iconHoverAlpha = 1
    end
    local iconOffsetX = math.floor((tonumber(resolvedOptions.iconOffsetX) or 0) + 0.5)
    local iconOffsetY = math.floor((tonumber(resolvedOptions.iconOffsetY) or 0) + 0.5)
    local iconTexture = resolvedOptions.iconTexture or MODERN_CLOSE_BUTTON_TEXTURE
    local clicks = type(resolvedOptions.clicks) == "table" and resolvedOptions.clicks or { "LeftButtonUp" }
    local iconInset = tonumber(resolvedOptions.iconInset)
    local iconSize
    if iconInset then
        iconSize = math.max(8, size - (math.floor(iconInset + 0.5) * 2))
    else
        iconSize = math.max(8, math.floor((size * iconScale) + 0.5))
    end

    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(size, size)
    button:RegisterForClicks(unpack(clicks))
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(1, 1, 1, backgroundAlpha)
    button:SetBackdropBorderColor(1, 1, 1, borderAlpha)

    local hover = button:CreateTexture(nil, "ARTWORK")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, hoverAlpha)
    hover:Hide()
    button.vgHoverTexture = hover

    local pressed = button:CreateTexture(nil, "ARTWORK")
    pressed:SetAllPoints()
    pressed:SetColorTexture(1, 1, 1, pressedAlpha)
    pressed:Hide()
    button.vgPressedTexture = pressed

    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("CENTER", iconOffsetX, iconOffsetY)
    icon:SetSize(iconSize, iconSize)
    icon:SetTexture(iconTexture)
    icon:SetVertexColor(1, 1, 1, iconAlpha)
    button.vgIconTexture = icon

    button:SetScript("OnEnter", function(selfButton)
        if not selfButton:IsEnabled() then
            return
        end
        selfButton.vgHoverTexture:Show()
        selfButton.vgIconTexture:SetVertexColor(1, 1, 1, iconHoverAlpha)
    end)
    button:SetScript("OnLeave", function(selfButton)
        selfButton.vgHoverTexture:Hide()
        selfButton.vgPressedTexture:Hide()
        selfButton.vgIconTexture:ClearAllPoints()
        selfButton.vgIconTexture:SetPoint("CENTER", iconOffsetX, iconOffsetY)
        selfButton.vgIconTexture:SetVertexColor(1, 1, 1, selfButton:IsEnabled() and iconAlpha or iconAlpha * 0.55)
    end)
    button:SetScript("OnMouseDown", function(selfButton, mouseButton)
        if mouseButton ~= "LeftButton" or not selfButton:IsEnabled() then
            return
        end
        selfButton.vgPressedTexture:Show()
        selfButton.vgIconTexture:ClearAllPoints()
        selfButton.vgIconTexture:SetPoint("CENTER", iconOffsetX, iconOffsetY - 1)
    end)
    button:SetScript("OnMouseUp", function(selfButton)
        selfButton.vgPressedTexture:Hide()
        selfButton.vgIconTexture:ClearAllPoints()
        selfButton.vgIconTexture:SetPoint("CENTER", iconOffsetX, iconOffsetY)
    end)

    if type(onClick) == "function" then
        button:SetScript("OnClick", onClick)
    end

    return button
end

-- Return ordered canonical hearthstone IDs.
function vesperTools:GetHearthstoneCatalog()
    return HEARTHSTONE_CATALOG
end

function vesperTools:GetRandomDiscoHearthstoneID()
    return RANDOM_DISCO_HEARTHSTONE_ID
end

function vesperTools:IsRandomDiscoHearthstoneSelection(itemID)
    return tonumber(itemID) == RANDOM_DISCO_HEARTHSTONE_ID
end

function vesperTools:GetRandomDiscoHearthstoneOption()
    return {
        itemID = RANDOM_DISCO_HEARTHSTONE_ID,
        name = L["HEARTHSTONE_RANDOM_DISCO"],
        icon = RANDOM_DISCO_ICON_TEXTURE,
        isRandomDisco = true,
    }
end

function vesperTools:GetToyWhitelistLimit()
    return MAX_UTILITY_TOY_WHITELIST
end

-- Return currently usable hearthstone variants with cached display metadata.
function vesperTools:GetAvailableHearthstoneOptions()
    local options = {}

    for i = 1, #HEARTHSTONE_CATALOG do
        local itemID = HEARTHSTONE_CATALOG[i]
        local isToy = itemID ~= DEFAULT_PRIMARY_HEARTHSTONE_ID
        local isOwned = false

        if isToy then
            isOwned = (PlayerHasToy and PlayerHasToy(itemID)) and true or false
        else
            isOwned = (GetItemCount(itemID, false, false, false) or 0) > 0
        end

        if isOwned then
            local name, icon = getItemNameAndIcon(itemID)
            options[#options + 1] = {
                itemID = itemID,
                name = name,
                icon = icon,
                isToy = isToy,
            }
        end
    end

    return options
end

-- Return hearthstones available for primary selection (excludes configured blacklist).
function vesperTools:GetPrimaryHearthstoneOptions()
    local options = self:GetAvailableHearthstoneOptions()
    local filtered = {}

    for i = 1, #options do
        local option = options[i]
        if not PRIMARY_HEARTHSTONE_BLACKLIST[option.itemID] then
            filtered[#filtered + 1] = option
        end
    end

    return filtered
end

-- Return config-facing primary hearthstone choices, including the random disco mode.
function vesperTools:GetPrimaryHearthstoneSelectionOptions()
    local options = self:GetPrimaryHearthstoneOptions()
    if #options == 0 then
        return options
    end

    local selectionOptions = {}
    for i = 1, #options do
        selectionOptions[i] = options[i]
    end

    selectionOptions[#selectionOptions + 1] = self:GetRandomDiscoHearthstoneOption()
    return selectionOptions
end

-- Return all currently owned toys with cached display metadata.
function vesperTools:GetOwnedToyOptions()
    local options = {}
    if not (C_ToyBox and PlayerHasToy) then
        return options
    end

    local toyIDs = {}
    local seenIDs = {}

    local function addToyID(itemID)
        local numericID = tonumber(itemID)
        if not numericID or numericID <= 0 or seenIDs[numericID] then
            return
        end
        seenIDs[numericID] = true
        toyIDs[#toyIDs + 1] = numericID
    end

    -- Primary source used by modern clients.
    if C_ToyBox.GetToyIDs then
        local toyIDList = C_ToyBox.GetToyIDs()
        if type(toyIDList) == "table" then
            for i = 1, #toyIDList do
                addToyID(toyIDList[i])
            end
        end
    end

    -- Fallback source for edge cases where GetToyIDs is empty/uninitialized.
    if #toyIDs == 0 and C_ToyBox.GetNumFilteredToys and C_ToyBox.GetToyFromIndex then
        local totalToys = tonumber(C_ToyBox.GetNumFilteredToys()) or 0
        for index = 1, totalToys do
            addToyID(C_ToyBox.GetToyFromIndex(index))
        end
    end

    -- Include persisted whitelist entries so users can still manage previously saved toys.
    local profile = self.db and self.db.profile
    if profile and profile.portals and type(profile.portals.utilityToyWhitelist) == "table" then
        for i = 1, #profile.portals.utilityToyWhitelist do
            addToyID(profile.portals.utilityToyWhitelist[i])
        end
    end

    for i = 1, #toyIDs do
        local itemID = toyIDs[i]
        if itemID and PlayerHasToy(itemID) then
            local name, icon = getItemNameAndIcon(itemID)
            options[#options + 1] = {
                itemID = itemID,
                name = name,
                icon = icon,
                isToy = true,
            }
        end
    end

    table.sort(options, function(a, b)
        return (a.name or "") < (b.name or "")
    end)

    return options
end

-- Return sanitized persisted toy whitelist.
function vesperTools:GetConfiguredToyWhitelist()
    local profile = self.db and self.db.profile
    if not profile then
        return {}
    end

    profile.portals = profile.portals or {}
    if type(profile.portals.utilityToyWhitelist) ~= "table" then
        profile.portals.utilityToyWhitelist = {}
    end

    local sanitized = {}
    local seen = {}
    for i = 1, #profile.portals.utilityToyWhitelist do
        local itemID = tonumber(profile.portals.utilityToyWhitelist[i])
        if #sanitized >= MAX_UTILITY_TOY_WHITELIST then
            break
        end
        if itemID and itemID > 0 and not seen[itemID] then
            sanitized[#sanitized + 1] = itemID
            seen[itemID] = true
        end
    end

    profile.portals.utilityToyWhitelist = sanitized
    return sanitized
end

-- Check if a toy is currently whitelisted.
function vesperTools:IsToyWhitelisted(itemID)
    local targetID = tonumber(itemID)
    if not targetID then
        return false
    end

    local whitelist = self:GetConfiguredToyWhitelist()
    for i = 1, #whitelist do
        if whitelist[i] == targetID then
            return true
        end
    end
    return false
end

-- Add/remove one toy from the persisted whitelist.
function vesperTools:SetToyWhitelisted(itemID, isWhitelisted)
    local targetID = tonumber(itemID)
    if not targetID then
        return false
    end

    local profile = self.db and self.db.profile
    if not profile then
        return false
    end
    profile.portals = profile.portals or {}

    local whitelist = self:GetConfiguredToyWhitelist()
    local hasEntry = false
    for i = 1, #whitelist do
        if whitelist[i] == targetID then
            hasEntry = true
            break
        end
    end

    if isWhitelisted then
        if not hasEntry then
            if #whitelist >= MAX_UTILITY_TOY_WHITELIST then
                return false
            end
            whitelist[#whitelist + 1] = targetID
        end
    else
        if hasEntry then
            local filtered = {}
            for i = 1, #whitelist do
                if whitelist[i] ~= targetID then
                    filtered[#filtered + 1] = whitelist[i]
                end
            end
            whitelist = filtered
        end
    end

    profile.portals.utilityToyWhitelist = whitelist
    return true
end

-- Return currently owned toys that are also in the user whitelist.
-- The output order follows whitelist order so users can control flyout arrangement.
function vesperTools:GetWhitelistedOwnedToyOptions()
    local whitelist = self:GetConfiguredToyWhitelist()
    if #whitelist == 0 then
        return {}
    end

    local owned = self:GetOwnedToyOptions()
    if #owned == 0 then
        return {}
    end

    local ownedByID = {}
    for i = 1, #owned do
        ownedByID[owned[i].itemID] = owned[i]
    end

    local filtered = {}
    for i = 1, #whitelist do
        local option = ownedByID[whitelist[i]]
        if option then
            filtered[#filtered + 1] = option
        end
    end

    return filtered
end

function vesperTools:GetCharacterPortalSettings()
    if not self.db then
        return nil
    end

    local charSettings = self.db.char or {}
    self.db.char = charSettings

    charSettings.portals = charSettings.portals or {}
    local portals = charSettings.portals

    if portals.primaryHearthstoneItemID == nil then
        local legacyProfile = self.db.profile
        local legacyValue = legacyProfile and legacyProfile.portals and legacyProfile.portals.primaryHearthstoneItemID
        portals.primaryHearthstoneItemID = sanitizePrimaryHearthstoneSelection(legacyValue)
    else
        portals.primaryHearthstoneItemID = sanitizePrimaryHearthstoneSelection(portals.primaryHearthstoneItemID)
    end

    return portals
end

-- Read saved primary hearthstone selection with character/default fallback.
function vesperTools:GetConfiguredPrimaryHearthstoneID()
    local portals = self:GetCharacterPortalSettings()
    if not portals then
        return DEFAULT_PRIMARY_HEARTHSTONE_ID
    end

    return portals.primaryHearthstoneItemID
end

function vesperTools:SetConfiguredPrimaryHearthstoneID(itemID)
    local portals = self:GetCharacterPortalSettings()
    if not portals then
        return DEFAULT_PRIMARY_HEARTHSTONE_ID
    end

    portals.primaryHearthstoneItemID = sanitizePrimaryHearthstoneSelection(itemID)
    return portals.primaryHearthstoneItemID
end

-- Shared range used by both config UI and runtime layout for top utility button sizing.
function vesperTools:GetTopUtilityButtonSizeBounds()
    return MIN_TOP_UTILITY_BUTTON_SIZE, MAX_TOP_UTILITY_BUTTON_SIZE, DEFAULT_TOP_UTILITY_BUTTON_SIZE
end

-- Read saved utility button size with sanitized bounds and default fallback.
function vesperTools:GetConfiguredTopUtilityButtonSize()
    local minSize, maxSize, defaultSize = self:GetTopUtilityButtonSizeBounds()
    local profile = self.db and self.db.profile
    if not profile then
        return defaultSize
    end

    profile.portals = profile.portals or {}
    local configured = math.floor((tonumber(profile.portals.utilityButtonSize) or defaultSize) + 0.5)
    if configured < minSize then
        configured = minSize
    elseif configured > maxSize then
        configured = maxSize
    end

    profile.portals.utilityButtonSize = configured
    return configured
end

-- Resolve usable primary hearthstone.
-- If configured value is unavailable, auto-fallback to first available and persist it.
function vesperTools:ResolvePrimaryHearthstoneID()
    local configuredID = self:GetConfiguredPrimaryHearthstoneID()
    local options = self:GetPrimaryHearthstoneOptions()
    if #options == 0 then
        options = self:GetAvailableHearthstoneOptions()
    end
    if #options == 0 then
        return nil
    end

    if configuredID == RANDOM_DISCO_HEARTHSTONE_ID then
        return configuredID
    end

    for i = 1, #options do
        if options[i].itemID == configuredID then
            return configuredID
        end
    end

    local fallbackID = options[1].itemID
    self:SetConfiguredPrimaryHearthstoneID(fallbackID)
    return fallbackID
end

-- Pick one currently-usable hearthstone for RANDOM DISCO mode.
function vesperTools:GetRandomPrimaryHearthstoneOption()
    local options = self:GetPrimaryHearthstoneOptions()
    if #options == 0 then
        options = self:GetAvailableHearthstoneOptions()
    end
    if #options == 0 then
        return nil
    end

    local choiceIndex = math.random(#options)
    if #options > 1 and tonumber(self._lastRandomDiscoHearthstoneID) == options[choiceIndex].itemID then
        choiceIndex = (choiceIndex % #options) + 1
    end

    local selected = options[choiceIndex]
    self._lastRandomDiscoHearthstoneID = selected.itemID
    return selected
end

-- Resolve secondary hearthstone with Arcantina-first preference.
function vesperTools:GetSecondaryHearthstoneID(primaryID)
    local options = self:GetAvailableHearthstoneOptions()
    if #options == 0 then
        return nil
    end

    local resolvedPrimary = tonumber(primaryID)
    for i = 1, #options do
        local optionID = options[i].itemID
        if optionID == PREFERRED_SECONDARY_HEARTHSTONE_ID and optionID ~= resolvedPrimary then
            return optionID
        end
    end

    local function findCandidate(itemID)
        for i = 1, #options do
            local optionID = options[i].itemID
            if optionID == itemID and optionID ~= resolvedPrimary then
                return optionID
            end
        end
        return nil
    end

    local preferredHearthstone = findCandidate(DEFAULT_PRIMARY_HEARTHSTONE_ID)
    if preferredHearthstone then
        return preferredHearthstone
    end

    for i = 1, #options do
        local optionID = options[i].itemID
        if optionID ~= resolvedPrimary then
            return optionID
        end
    end

    return options[1].itemID
end

-- Resolve active font path from profile with default fallback.
function vesperTools:GetConfiguredFontPath()
    local _, path = self:GetConfiguredFontSelection()
    return path or DEFAULT_FONT_PATH
end

-- Resolve friendly label for a font path.
function vesperTools:GetFontLabelByPath(path)
    path = normalizeMediaPath(path)

    local bundledOption = getFontOptionByPath(path)
    if bundledOption then
        return bundledOption.label
    end

    local sharedMedia = self:GetSharedMedia()
    local sharedMediaKey = getSharedMediaFontKeyByPath(sharedMedia, path)
    if sharedMediaKey then
        return sharedMediaKey
    end

    return path or L["UNKNOWN_LABEL"]
end

-- Apply current configured font to a FontString with defensive fallbacks.
-- Fallback order: configured font -> addon default -> Blizzard standard font.
function vesperTools:ApplyConfiguredFont(fontString, size, flags)
    if not fontString or type(fontString.SetFont) ~= "function" then
        return false
    end

    local resolvedSize = math.floor((tonumber(size) or 12) + 0.5)
    if resolvedSize < 6 then
        resolvedSize = 6
    end

    local resolvedFlags = type(flags) == "string" and flags or ""

    local function trySet(path, overrideFlags)
        path = normalizeMediaPath(path)
        if type(path) ~= "string" or path == "" then
            return false
        end

        local ok, setResult = pcall(fontString.SetFont, fontString, path, resolvedSize, overrideFlags)
        if not ok or setResult == false then
            return false
        end

        local assignedPath = fontString:GetFont()
        return type(assignedPath) == "string" and assignedPath ~= ""
    end

    local configuredPath = self:GetConfiguredFontPath()
    if trySet(configuredPath, resolvedFlags) or (resolvedFlags ~= "" and trySet(configuredPath, "")) then
        return true
    end

    if trySet(DEFAULT_FONT_PATH, resolvedFlags) or (resolvedFlags ~= "" and trySet(DEFAULT_FONT_PATH, "")) then
        return true
    end

    local fallback = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if trySet(fallback, resolvedFlags) or (resolvedFlags ~= "" and trySet(fallback, "")) then
        return true
    end

    return false
end

-- Return clamped opacity for a named frame key from profile style config.
-- Valid range is [0.10, 1.00] to avoid fully invisible windows.
function vesperTools:GetConfiguredOpacity(frameKey)
    local defaultOpacity = 0.95
    local profile = self.db and self.db.profile
    if not profile then
        return defaultOpacity
    end

    profile.style = profile.style or {}
    profile.style.backgroundOpacity = profile.style.backgroundOpacity or {}

    local value = tonumber(profile.style.backgroundOpacity[frameKey])
    if not value then
        profile.style.backgroundOpacity[frameKey] = defaultOpacity
        return defaultOpacity
    end

    if value < 0.10 then
        value = 0.10
    elseif value > 1 then
        value = 1
    end

    profile.style.backgroundOpacity[frameKey] = value
    return value
end

-- Return clamped font size for a frame key from profile style config.
-- Keeps per-frame size values stable even with stale/invalid SavedVariables.
function vesperTools:GetConfiguredFontSize(frameKey, defaultSize, minSize, maxSize)
    local resolvedDefault = tonumber(defaultSize) or 12
    local resolvedMin = tonumber(minSize) or 8
    local resolvedMax = tonumber(maxSize) or 24
    if resolvedMin > resolvedMax then
        resolvedMin, resolvedMax = resolvedMax, resolvedMin
    end

    local profile = self.db and self.db.profile
    if not profile then
        if resolvedDefault < resolvedMin then
            return resolvedMin
        end
        if resolvedDefault > resolvedMax then
            return resolvedMax
        end
        return resolvedDefault
    end

    profile.style = profile.style or {}
    profile.style.fontSize = profile.style.fontSize or {}

    local value = tonumber(profile.style.fontSize[frameKey])
    if not value then
        value = resolvedDefault
    end

    if value < resolvedMin then
        value = resolvedMin
    elseif value > resolvedMax then
        value = resolvedMax
    end

    profile.style.fontSize[frameKey] = value
    return value
end

-- Open custom configuration window if module is loaded.
function vesperTools:OpenConfig()
    local Configuration = self:GetModule("Configuration", true)
    if Configuration and type(Configuration.OpenConfig) == "function" then
        Configuration:OpenConfig()
        return
    end
    self:Print(L["CONFIG_MODULE_NOT_FOUND"])
end

-- Copy legacy DB globals forward before AceDB opens the modern names.
local function MigrateLegacySavedVariables()
    if _G[CURRENT_MAIN_DB_NAME] == nil and _G[LEGACY_MAIN_DB_NAME] ~= nil then
        _G[CURRENT_MAIN_DB_NAME] = _G[LEGACY_MAIN_DB_NAME]
    end

    if _G[CURRENT_BAGS_DB_NAME] == nil and _G[LEGACY_BAGS_DB_NAME] ~= nil then
        _G[CURRENT_BAGS_DB_NAME] = _G[LEGACY_BAGS_DB_NAME]
    end
end

-- Build the main addon DBs and normalize their default shape on load.
function vesperTools:OnInitialize()
    MigrateLegacySavedVariables()

    -- Called when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New(CURRENT_MAIN_DB_NAME, {
        profile = {
            icon = {
                point = "CENTER",
                x = 0,
                y = 0,
            },
            style = {
                -- Configurable typography and panel opacity values.
                fontName = DEFAULT_FONT_KEY,
                fontPath = DEFAULT_FONT_PATH,
                fontSize = {
                    roster = 12,
                    portals = 12,
                    bestKeys = 11,
                },
                backgroundOpacity = {
                    roster = 0.95,
                    portals = 0.95,
                    bestKeys = 0.95,
                },
            },
            roster = {
                onlineCountBlacklist = {},
            },
            portals = {
                -- Toy IDs shown in the utility flyout button above portals.
                utilityToyWhitelist = {},
                -- Icon size used by top utility hearthstone/toy buttons.
                utilityButtonSize = DEFAULT_TOP_UTILITY_BUTTON_SIZE,
            },
        },
        char = {
            portals = {},
        },
        global = {
            keystones = {}, -- Persistent keystone storage
            ilvlSync = {},  -- Persistent ilvl storage from guild sync
            bestKeys = {},  -- Persistent best M+ keys from guild sync
        },
    }, true)
    self:InitializeSharedMediaSupport()

    self.bagsDB = LibStub("AceDB-3.0"):New(CURRENT_BAGS_DB_NAME, {
        profile = {
            window = {
                point = "CENTER",
                relativePoint = "CENTER",
                xOfs = 0,
                yOfs = 0,
                width = DEFAULT_BAGS_WINDOW_WIDTH,
                height = DEFAULT_BAGS_WINDOW_HEIGHT,
            },
            bankWindow = {
                point = "CENTER",
                relativePoint = "CENTER",
                xOfs = 0,
                yOfs = 0,
                width = DEFAULT_BANK_WINDOW_WIDTH,
                height = DEFAULT_BANK_WINDOW_HEIGHT,
            },
            display = {
                columns = DEFAULT_BAGS_COLUMNS,
                itemIconSize = DEFAULT_BAGS_ITEM_ICON_SIZE,
                stackCountFontSize = DEFAULT_BAGS_STACK_COUNT_FONT_SIZE,
                itemLevelFontSize = DEFAULT_BAGS_ITEM_LEVEL_FONT_SIZE,
                showEquippedBags = false,
                showItemLevel = false,
                showCurrencyBar = true,
                currencyBarIDs = {},
                qualityGlowIntensity = DEFAULT_BAGS_QUALITY_GLOW_INTENSITY,
                combineStacks = false,
                categoryLayout = {},
            },
            bankDisplay = {
                columns = DEFAULT_BANK_COLUMNS,
                itemIconSize = DEFAULT_BANK_ITEM_ICON_SIZE,
                stackCountFontSize = DEFAULT_BANK_STACK_COUNT_FONT_SIZE,
                itemLevelFontSize = DEFAULT_BANK_ITEM_LEVEL_FONT_SIZE,
                showItemLevel = false,
                qualityGlowIntensity = DEFAULT_BANK_QUALITY_GLOW_INTENSITY,
                combineStacks = false,
            },
            guildLookup = {
                enabled = false,
                allowIncomingRequests = false,
            },
            lastViewedCharacterGUID = nil,
            lastViewedBankCharacterGUID = nil,
            lastViewedVaultCharacterGUID = nil,
            lastViewedBankView = "character",
            vaultWindow = {
                point = "CENTER",
                relativePoint = "CENTER",
                xOfs = 0,
                yOfs = 0,
                width = 760,
                height = 644,
            },
            replaceBackpack = false,
            replaceCharacterBank = false,
            replaceAccountBank = false,
        },
        global = {
            schemaVersion = 2,
            charactersByGUID = {},
            itemMeta = {},
            accountIndex = {
                itemOwners = {},
                itemTotals = {},
                categoryTotals = {},
                categoryItems = {},
            },
            bank = {
                charactersByGUID = {},
                warband = {
                    bags = {},
                    itemTotals = {},
                    categoryTotals = {},
                    categoryItems = {},
                    lastSeen = 0,
                },
            },
            vault = {
                charactersByGUID = {},
            },
        },
    }, true)

    if self.db.profile and self.db.profile.minimap ~= nil then
        self.db.profile.minimap = nil
    end

    self:Print(L["ADDON_LOADED_MESSAGE"])
end

function vesperTools:GetBagsDB()
    return self.bagsDB
end

-- Normalize the bags profile subtree before any UI module reads from it.
function vesperTools:GetBagsProfile()
    if not self.bagsDB then
        return nil
    end

    local profile = self.bagsDB.profile or {}
    self.bagsDB.profile = profile

    profile.window = profile.window or {}
    if type(profile.window.point) ~= "string" or profile.window.point == "" then
        profile.window.point = "CENTER"
    end
    if type(profile.window.relativePoint) ~= "string" or profile.window.relativePoint == "" then
        profile.window.relativePoint = "CENTER"
    end
    profile.window.xOfs = tonumber(profile.window.xOfs) or 0
    profile.window.yOfs = tonumber(profile.window.yOfs) or 0
    profile.window.width = math.max(480, math.floor((tonumber(profile.window.width) or DEFAULT_BAGS_WINDOW_WIDTH) + 0.5))
    profile.window.height = math.max(220, math.floor((tonumber(profile.window.height) or DEFAULT_BAGS_WINDOW_HEIGHT) + 0.5))

    profile.bankWindow = profile.bankWindow or {}
    if type(profile.bankWindow.point) ~= "string" or profile.bankWindow.point == "" then
        profile.bankWindow.point = "CENTER"
    end
    if type(profile.bankWindow.relativePoint) ~= "string" or profile.bankWindow.relativePoint == "" then
        profile.bankWindow.relativePoint = "CENTER"
    end
    profile.bankWindow.xOfs = tonumber(profile.bankWindow.xOfs) or 0
    profile.bankWindow.yOfs = tonumber(profile.bankWindow.yOfs) or 0
    profile.bankWindow.width = math.max(480, math.floor((tonumber(profile.bankWindow.width) or DEFAULT_BANK_WINDOW_WIDTH) + 0.5))
    profile.bankWindow.height = math.max(220, math.floor((tonumber(profile.bankWindow.height) or DEFAULT_BANK_WINDOW_HEIGHT) + 0.5))

    profile.vaultWindow = profile.vaultWindow or {}
    if type(profile.vaultWindow.point) ~= "string" or profile.vaultWindow.point == "" then
        profile.vaultWindow.point = "CENTER"
    end
    if type(profile.vaultWindow.relativePoint) ~= "string" or profile.vaultWindow.relativePoint == "" then
        profile.vaultWindow.relativePoint = "CENTER"
    end
    profile.vaultWindow.xOfs = tonumber(profile.vaultWindow.xOfs) or 0
    profile.vaultWindow.yOfs = tonumber(profile.vaultWindow.yOfs) or 0
    profile.vaultWindow.width = math.max(560, math.floor((tonumber(profile.vaultWindow.width) or 760) + 0.5))
    profile.vaultWindow.height = math.max(644, math.floor((tonumber(profile.vaultWindow.height) or 644) + 0.5))

    profile.display = profile.display or {}
    profile.display.columns = math.max(1, math.min(20, math.floor((tonumber(profile.display.columns) or DEFAULT_BAGS_COLUMNS) + 0.5)))
    profile.display.itemIconSize = math.max(24, math.min(56, math.floor((tonumber(profile.display.itemIconSize) or DEFAULT_BAGS_ITEM_ICON_SIZE) + 0.5)))
    profile.display.stackCountFontSize = math.max(8, math.min(20, math.floor((tonumber(profile.display.stackCountFontSize) or DEFAULT_BAGS_STACK_COUNT_FONT_SIZE) + 0.5)))
    profile.display.itemLevelFontSize = math.max(8, math.min(18, math.floor((tonumber(profile.display.itemLevelFontSize) or DEFAULT_BAGS_ITEM_LEVEL_FONT_SIZE) + 0.5)))
    profile.display.showEquippedBags = profile.display.showEquippedBags and true or false
    profile.display.showItemLevel = profile.display.showItemLevel and true or false
    if profile.display.showCurrencyBar == nil then
        profile.display.showCurrencyBar = true
    else
        profile.display.showCurrencyBar = profile.display.showCurrencyBar and true or false
    end
    profile.display.currencyBarIDs = sanitizeCurrencyIDList(profile.display.currencyBarIDs)
    profile.display.qualityGlowIntensity = math.max(0, math.min(1, tonumber(profile.display.qualityGlowIntensity) or DEFAULT_BAGS_QUALITY_GLOW_INTENSITY))
    profile.display.combineStacks = profile.display.combineStacks and true or false
    if type(profile.display.categoryLayout) ~= "table" then
        profile.display.categoryLayout = {}
    end
    for categoryKey, entry in pairs(profile.display.categoryLayout) do
        if type(categoryKey) ~= "string" or categoryKey == "" or type(entry) ~= "table" then
            profile.display.categoryLayout[categoryKey] = nil
        else
            local order = math.floor((tonumber(entry.order) or 0) + 0.5)
            local span = math.floor((tonumber(entry.span) or 0) + 0.5)
            if order <= 0 and span <= 0 then
                profile.display.categoryLayout[categoryKey] = nil
            else
                entry.order = order > 0 and order or nil
                entry.span = span > 0 and span or nil
            end
        end
    end
    profile.bankDisplay = profile.bankDisplay or {}
    profile.bankDisplay.columns = math.max(1, math.min(20, math.floor((tonumber(profile.bankDisplay.columns) or DEFAULT_BANK_COLUMNS) + 0.5)))
    profile.bankDisplay.itemIconSize = math.max(24, math.min(56, math.floor((tonumber(profile.bankDisplay.itemIconSize) or DEFAULT_BANK_ITEM_ICON_SIZE) + 0.5)))
    profile.bankDisplay.stackCountFontSize = math.max(8, math.min(20, math.floor((tonumber(profile.bankDisplay.stackCountFontSize) or DEFAULT_BANK_STACK_COUNT_FONT_SIZE) + 0.5)))
    profile.bankDisplay.itemLevelFontSize = math.max(8, math.min(18, math.floor((tonumber(profile.bankDisplay.itemLevelFontSize) or DEFAULT_BANK_ITEM_LEVEL_FONT_SIZE) + 0.5)))
    profile.bankDisplay.showItemLevel = profile.bankDisplay.showItemLevel and true or false
    profile.bankDisplay.qualityGlowIntensity = math.max(0, math.min(1, tonumber(profile.bankDisplay.qualityGlowIntensity) or DEFAULT_BANK_QUALITY_GLOW_INTENSITY))
    profile.bankDisplay.combineStacks = profile.bankDisplay.combineStacks and true or false
    profile.guildLookup = profile.guildLookup or {}
    profile.guildLookup.enabled = profile.guildLookup.enabled and true or false
    profile.guildLookup.allowIncomingRequests = profile.guildLookup.allowIncomingRequests and true or false
    if type(profile.collapsedCategories) ~= "table" then
        profile.collapsedCategories = {}
    end
    if type(profile.collapsedBankCategories) ~= "table" then
        profile.collapsedBankCategories = {}
    end

    if type(profile.lastViewedCharacterGUID) ~= "string" or profile.lastViewedCharacterGUID == "" then
        profile.lastViewedCharacterGUID = nil
    end
    if type(profile.lastViewedBankCharacterGUID) ~= "string" or profile.lastViewedBankCharacterGUID == "" then
        profile.lastViewedBankCharacterGUID = nil
    end
    if type(profile.lastViewedVaultCharacterGUID) ~= "string" or profile.lastViewedVaultCharacterGUID == "" then
        profile.lastViewedVaultCharacterGUID = nil
    end
    if profile.lastViewedBankView ~= "character" and profile.lastViewedBankView ~= "warband" then
        profile.lastViewedBankView = "character"
    end

    profile.replaceBackpack = profile.replaceBackpack and true or false
    profile.replaceCharacterBank = profile.replaceCharacterBank and true or false
    profile.replaceAccountBank = profile.replaceAccountBank and true or false

    return profile
end

function vesperTools:GetBagCurrencyBarLimit()
    return MAX_BAGS_CURRENCY_BAR_ENTRIES
end

function vesperTools:GetCurrencyInfoByID(currencyID)
    return getCurrencyInfoByID(currencyID)
end

function vesperTools:GetTrackedBagCurrencyOptions()
    local options = {}
    local seen = {}
    local watchedCount = getNumWatchedTokens()

    for index = 1, watchedCount do
        local info = getBackpackCurrencyInfo(index)
        if info and info.currencyID and info.currencyID > 0 and not seen[info.currencyID] then
            options[#options + 1] = {
                currencyID = info.currencyID,
                name = info.name,
                quantity = info.quantity,
                iconFileID = info.iconFileID,
                isShowInBackpack = true,
                maxQuantity = info.maxQuantity,
                totalEarned = info.totalEarned,
                maxWeeklyQuantity = info.maxWeeklyQuantity,
                quantityEarnedThisWeek = info.quantityEarnedThisWeek,
                sortIndex = index,
            }
            seen[info.currencyID] = true
        end
    end

    return options
end

function vesperTools:GetGoldCurrencyBarEntry()
    return {
        isGold = true,
        name = MONEY or "Gold",
        quantity = GetMoney and (tonumber(GetMoney()) or 0) or 0,
        iconFileID = GOLD_BAR_ICON_TEXTURE,
        isShowInBackpack = true,
        discovered = true,
        maxQuantity = 0,
        totalEarned = nil,
        maxWeeklyQuantity = 0,
        quantityEarnedThisWeek = 0,
    }
end

function vesperTools:GetConfiguredBagCurrencyIDs()
    local profile = self:GetBagsProfile()
    if not profile or not profile.display then
        return {}
    end

    return profile.display.currencyBarIDs or {}
end

function vesperTools:ClearConfiguredBagCurrencies()
    local profile = self:GetBagsProfile()
    if not profile then
        return
    end

    profile.display = profile.display or {}
    profile.display.currencyBarIDs = {}
end

function vesperTools:SetBagCurrencySelected(currencyID, shouldSelect)
    local profile = self:GetBagsProfile()
    if not profile then
        return false
    end

    local numericCurrencyID = math.floor((tonumber(currencyID) or 0) + 0.5)
    if numericCurrencyID <= 0 then
        return false
    end

    profile.display = profile.display or {}
    local selectedIDs = sanitizeCurrencyIDList(profile.display.currencyBarIDs)
    local wasSelected = false
    local existingIndex = nil

    for i = 1, #selectedIDs do
        if selectedIDs[i] == numericCurrencyID then
            wasSelected = true
            existingIndex = i
            break
        end
    end

    if shouldSelect then
        if wasSelected then
            profile.display.currencyBarIDs = selectedIDs
            return true
        end

        if #selectedIDs >= MAX_BAGS_CURRENCY_BAR_ENTRIES then
            profile.display.currencyBarIDs = selectedIDs
            return false
        end

        selectedIDs[#selectedIDs + 1] = numericCurrencyID
    elseif existingIndex then
        table.remove(selectedIDs, existingIndex)
    end

    profile.display.currencyBarIDs = selectedIDs
    return true
end

function vesperTools:GetCurrencyBarSelectionOptions()
    local options = {}
    local strictOptions = {}
    local priorityOptions = {}
    local broadOptions = {}
    local seen = {}
    local prioritySeen = {}
    local broadSeen = {}
    local count = getCurrencyListSize()
    local index = 1
    local currentExpansionName = getCurrentExpansionName()
    local normalizedCurrentExpansionName = normalizeCurrencyLabel(currentExpansionName)
    local expansionNameSet = getExpansionNameSet()
    local professionNameSet = getProfessionNameSet()
    local inCurrentExpansionSection = currentExpansionName == nil
    local inProfessionSection = false

    while index <= count do
        local info = getCurrencyListInfo(index)
        if info and info.isHeader and not info.isHeaderExpanded and type(ExpandCurrencyList) == "function" then
            pcall(ExpandCurrencyList, index, 1)
            count = getCurrencyListSize()
            info = getCurrencyListInfo(index) or info
        end

        if info and info.isHeader then
            local normalizedHeaderName = normalizeCurrencyLabel(info.name)
            if normalizedHeaderName and expansionNameSet[normalizedHeaderName] then
                inCurrentExpansionSection = normalizedCurrentExpansionName == nil
                    or normalizedHeaderName == normalizedCurrentExpansionName
                inProfessionSection = false
            elseif inCurrentExpansionSection then
                inProfessionSection = labelContainsAnyToken(info.name, professionNameSet)
            end
        end

        if info
            and not info.isHeader
            and not info.isTypeUnused
            and info.discovered
            and info.currencyID
            and info.currencyID > 0
            and type(info.name) == "string"
            and info.name ~= ""
            and not inProfessionSection
        then
            local option = {
                currencyID = info.currencyID,
                name = info.name,
                quantity = info.quantity,
                iconFileID = info.iconFileID,
                isShowInBackpack = info.isShowInBackpack,
                maxQuantity = info.maxQuantity,
                totalEarned = info.totalEarned,
                maxWeeklyQuantity = info.maxWeeklyQuantity,
                quantityEarnedThisWeek = info.quantityEarnedThisWeek,
                canEarnPerWeek = info.canEarnPerWeek,
                useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
                sortIndex = index,
            }

            if not broadSeen[option.currencyID] then
                broadOptions[#broadOptions + 1] = option
                broadSeen[option.currencyID] = true
            end

            if inCurrentExpansionSection and not seen[option.currencyID] then
                strictOptions[#strictOptions + 1] = option
                seen[option.currencyID] = true
            end

            if not prioritySeen[option.currencyID]
                and (option.isShowInBackpack
                    or option.canEarnPerWeek
                    or (tonumber(option.maxWeeklyQuantity) or 0) > 0
                    or option.useTotalEarnedForMaxQty)
            then
                priorityOptions[#priorityOptions + 1] = option
                prioritySeen[option.currencyID] = true
            end
        end

        index = index + 1
    end

    if #strictOptions > 0 then
        options = strictOptions
    elseif #priorityOptions > 0 then
        options = priorityOptions
    elseif #broadOptions > 0 then
        options = broadOptions
    end

    seen = {}
    for i = 1, #options do
        seen[options[i].currencyID] = true
    end

    if #options == 0 then
        local trackedOptions = self:GetTrackedBagCurrencyOptions()
        for i = 1, #trackedOptions do
            local option = trackedOptions[i]
            if option and option.currencyID and not seen[option.currencyID] then
                options[#options + 1] = option
                seen[option.currencyID] = true
            end
        end
    end

    local selectedIDs = self:GetConfiguredBagCurrencyIDs()
    for i = 1, #selectedIDs do
        local currencyID = selectedIDs[i]
        if not seen[currencyID] then
            local info = getCurrencyInfoByID(currencyID)
            if info then
                options[#options + 1] = {
                    currencyID = currencyID,
                    name = info.name,
                    quantity = info.quantity,
                    iconFileID = info.iconFileID,
                    isShowInBackpack = info.isShowInBackpack,
                    maxQuantity = info.maxQuantity,
                    totalEarned = info.totalEarned,
                    maxWeeklyQuantity = info.maxWeeklyQuantity,
                    quantityEarnedThisWeek = info.quantityEarnedThisWeek,
                    sortIndex = 100000 + i,
                }
                seen[currencyID] = true
            end
        end
    end

    return options
end

function vesperTools:GetCurrentCharacterGUID()
    local guid = UnitGUID("player")
    if type(guid) == "string" and guid ~= "" then
        return guid
    end

    local name = UnitName("player") or UNKNOWN
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "UnknownRealm"
    return string.format("name:%s-%s", name, realm)
end

-- Shared inventory lookup helpers forwarded to BagsStore.
function vesperTools:GetCurrentCharacterFullName()
    local name = UnitName("player") or UNKNOWN
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "UnknownRealm"
    return string.format("%s-%s", name, realm)
end

function vesperTools:NormalizePlayerFullName(name)
    if type(name) ~= "string" then
        return nil
    end

    local normalized = strtrim(name)
    if normalized == "" then
        return nil
    end

    if not string.find(normalized, "-", 1, true) then
        local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "UnknownRealm"
        normalized = string.format("%s-%s", normalized, realm)
    end

    return normalized
end

function vesperTools:GetRosterOnlineCountBlacklist()
    local profile = self.db and self.db.profile
    if not profile then
        return {}
    end

    profile.roster = profile.roster or {}
    if type(profile.roster.onlineCountBlacklist) ~= "table" then
        profile.roster.onlineCountBlacklist = {}
    end

    local blacklist = profile.roster.onlineCountBlacklist
    local sanitized = {}
    local changed = false

    for key, value in pairs(blacklist) do
        local candidateName = nil
        if type(key) == "number" then
            candidateName = type(value) == "string" and value or nil
            changed = true
        elseif value then
            candidateName = type(key) == "string" and key or nil
            if value ~= true then
                changed = true
            end
        elseif value ~= nil then
            changed = true
        end

        local normalized = self:NormalizePlayerFullName(candidateName)
        if normalized then
            sanitized[normalized] = true
            if key ~= normalized then
                changed = true
            end
        elseif candidateName ~= nil then
            changed = true
        end
    end

    if changed then
        profile.roster.onlineCountBlacklist = sanitized
        blacklist = sanitized
    end

    return blacklist
end

function vesperTools:GetRosterOnlineCountBlacklistCount()
    local count = 0
    for _ in pairs(self:GetRosterOnlineCountBlacklist()) do
        count = count + 1
    end
    return count
end

function vesperTools:IsRosterOnlineCountBlacklisted(name)
    local normalized = self:NormalizePlayerFullName(name)
    if not normalized then
        return false
    end

    return self:GetRosterOnlineCountBlacklist()[normalized] and true or false
end

function vesperTools:SetRosterOnlineCountBlacklisted(name, isBlacklisted)
    local normalized = self:NormalizePlayerFullName(name)
    if not normalized then
        return false
    end

    local blacklist = self:GetRosterOnlineCountBlacklist()
    if isBlacklisted then
        blacklist[normalized] = true
    else
        blacklist[normalized] = nil
    end

    self:UpdateFloatingIconOnlineCount()
    return true
end

function vesperTools:ClearRosterOnlineCountBlacklist()
    local profile = self.db and self.db.profile
    if not profile then
        return
    end

    profile.roster = profile.roster or {}
    profile.roster.onlineCountBlacklist = {}
    self:UpdateFloatingIconOnlineCount()
end

function vesperTools:GetCharacterBagSnapshot(characterKey)
    local BagsStore = self:GetModule("BagsStore", true)
    if not BagsStore then
        return nil
    end
    return BagsStore:GetCharacterBagSnapshot(characterKey)
end

function vesperTools:GetCharacterItemCount(characterKey, itemID)
    local BagsStore = self:GetModule("BagsStore", true)
    if not BagsStore then
        return 0
    end
    return BagsStore:GetCharacterItemCount(characterKey, itemID)
end

function vesperTools:GetAccountItemOwners(itemID)
    local BagsStore = self:GetModule("BagsStore", true)
    if not BagsStore then
        return nil
    end
    return BagsStore:GetAccountItemOwners(itemID)
end

function vesperTools:GetCharacterCategoryItems(characterKey, categoryKey)
    local BagsStore = self:GetModule("BagsStore", true)
    if not BagsStore then
        return {}
    end
    return BagsStore:GetCharacterCategoryItems(characterKey, categoryKey)
end

function vesperTools:GetAccountCategoryItems(categoryKey)
    local BagsStore = self:GetModule("BagsStore", true)
    if not BagsStore then
        return nil
    end
    return BagsStore:GetAccountCategoryItems(categoryKey)
end

function vesperTools:MarkFullCarryRescan(reason)
    local BagsStore = self:GetModule("BagsStore", true)
    if not BagsStore then
        return
    end
    BagsStore:MarkFullCarryRescan(reason)
end

function vesperTools:GetOnlineGuildMembers(includeBlacklisted)
    local members = {}
    if not IsInGuild() then
        return members
    end

    local blacklist = includeBlacklisted and nil or self:GetRosterOnlineCountBlacklist()
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, _, level, _, zone, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline and name then
            local fullName = self:NormalizePlayerFullName(name) or name
            if includeBlacklisted or not blacklist or not blacklist[fullName] then
                local displayName = name:match("([^-]+)") or name
                table.insert(members, {
                    name = displayName,
                    fullName = fullName,
                    level = level or 0,
                    zone = (zone and zone ~= "" and zone) or UNKNOWN,
                })
            end
        end
    end

    table.sort(members, function(a, b)
        local aName = a.name or a.fullName or ""
        local bName = b.name or b.fullName or ""
        if aName ~= bName then
            return aName < bName
        end
        return (a.fullName or "") < (b.fullName or "")
    end)

    return members
end

-- Refresh the numeric online badge shown on the floating icon.
function vesperTools:UpdateFloatingIconOnlineCount()
    if not self.iconButton or not self.iconButton.onlineCountText then
        return
    end

    local count = 0
    if IsInGuild() then
        count = #self:GetOnlineGuildMembers()
    end

    self.iconButton.onlineCountText:SetText(tostring(count))
end

function vesperTools:OnGuildRosterUpdate()
    self:UpdateFloatingIconOnlineCount()
end

-- Build the draggable floating launcher button and its tooltip behavior.
function vesperTools:CreateFloatingIcon()
    local btn = CreateFrame("Button", "vesperToolsIcon", UIParent)
    btn:SetSize(40, 40)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    self:ApplyAddonWindowLayer(btn)
    
    -- Load Saved Position
    local pos = self.db.profile.icon
    btn:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    
    -- Artwork
    local tex = btn:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Icons\\Spell_Nature_Polymorph")
    btn.texture = tex
    
    local countText = btn:CreateFontString(nil, "OVERLAY")
    countText:SetPoint("CENTER", 0, 0)
    countText:SetFont("Interface\\AddOns\\vesperTools\\Media\\UbuntuNerdFont-Bold.ttf", 20, "OUTLINE")
    countText:SetTextColor(1, 1, 1, 1)
    countText:SetShadowOffset(1, -1)
    countText:SetShadowColor(0, 0, 0, 1)
    countText:SetText("0")
    btn.onlineCountText = countText
    self.iconButton = btn

    -- Drag Script - only drag if Shift+LeftButton is held
    btn:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        vesperTools.db.profile.icon.point = point
        vesperTools.db.profile.icon.x = x
        vesperTools.db.profile.icon.y = y
    end)
    
    -- Click Script - left click to toggle roster and portals (no shift required)
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and not IsShiftKeyDown() then
            local Roster = vesperTools:GetModule("Roster", true)
            local Portals = vesperTools:GetModule("Portals", true)
            if Roster then Roster:Toggle() end
            if Portals then Portals:Toggle() end
            vesperTools:SendMessage("VESPERTOOLS_ADDON_OPENED")
        end
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        if IsInGuild() then
            RequestGuildRosterUpdate()
        end

        local onlineMembers = vesperTools:GetOnlineGuildMembers()

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["MINIMAP_TOOLTIP_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_TOGGLE"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_MOVE"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(L["MINIMAP_TOOLTIP_GUILD_ONLINE_FMT"], #onlineMembers), 1, 0.82, 0)

        if #onlineMembers == 0 then
            if IsInGuild() then
                GameTooltip:AddLine(L["MINIMAP_TOOLTIP_NO_GUILD_ONLINE"], 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine(L["MINIMAP_TOOLTIP_NOT_IN_GUILD"], 0.6, 0.6, 0.6)
            end
        else
            for _, member in ipairs(onlineMembers) do
                GameTooltip:AddDoubleLine(
                    string.format(L["MINIMAP_TOOLTIP_MEMBER_FMT"], member.name, member.level),
                    member.zone,
                    1, 1, 1,
                    0.8, 0.8, 0.8
                )
            end
        end

        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Register top-level slash commands, events, and the floating launcher.
function vesperTools:OnEnable()
    -- Called when the addon is enabled
    self:RegisterChatCommand("vesper", "HandleChatCommand")
    self:RegisterChatCommand("vg", "HandleChatCommand")
    
    -- HealthCheck if modules are loaded
    local Roster = self:GetModule("Roster", true)
    local Portals = self:GetModule("Portals", true)
    if not Roster then
        self:Print(L["ROSTER_MODULE_WARNING"])
    end
    if not Portals then
        self:Print(L["PORTALS_MODULE_WARNING"])
    end
    
    self:CreateFloatingIcon()
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnGuildRosterUpdate")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "OnGuildRosterUpdate")
    if IsInGuild() then
        RequestGuildRosterUpdate()
    end
    self:UpdateFloatingIconOnlineCount()
end

function vesperTools:OnDisable()
    -- Called when the addon is disabled
end

-- Route slash commands to the relevant top-level addon windows or debug actions.
function vesperTools:HandleChatCommand(input)
    -- Normalize chat command once so aliases/casing are handled uniformly.
    local normalizedInput = input and strtrim(input) or ""
    local loweredInput = string.lower(normalizedInput)

    if normalizedInput == "" then
        -- Open the roster and portals window by default
        local Roster = self:GetModule("Roster", true)
        local Portals = self:GetModule("Portals", true)
        if Roster and Portals then
            Roster:Toggle()
            Portals:Toggle()
            self:SendMessage("VESPERTOOLS_ADDON_OPENED")
        else
            self:Print(L["ROSTER_OR_PORTALS_MODULE_MISSING"])
        end
    elseif loweredInput == "config" or loweredInput == "options" then
        -- Keep both aliases for convenience and discoverability.
        self:OpenConfig()
    elseif loweredInput == "bags" then
        local BagsWindow = self:GetModule("BagsWindow", true)
        if BagsWindow and type(BagsWindow.Toggle) == "function" then
            BagsWindow:Toggle()
        else
            self:Print(L["BAGS_WINDOW_MODULE_NOT_FOUND"])
        end
    elseif loweredInput == "bank" then
        local BankWindow = self:GetModule("BankWindow", true)
        if BankWindow and type(BankWindow.Toggle) == "function" then
            BankWindow:Toggle()
        else
            self:Print(L["BANK_WINDOW_MODULE_NOT_FOUND"])
        end
    elseif loweredInput == "reset" then
        -- Reset icon position
        self.db.profile.icon = { point = "CENTER", x = 0, y = 0 }
        local icon = _G["vesperToolsIcon"]
        if icon then
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end

        -- Reset roster frame position
        self.db.profile.rosterPosition = nil
        local rosterFrame = _G["vesperToolsFrame"]
        if rosterFrame then
            rosterFrame:ClearAllPoints()
            rosterFrame:SetPoint("RIGHT", UIParent, "CENTER", -250, 0)
        end

        -- Reset portals frame position
        self.db.profile.portalsPosition = nil
        local portalFrame = _G["vesperToolsPortalFrame"]
        if portalFrame then
            portalFrame:ClearAllPoints()
            portalFrame:SetPoint("LEFT", UIParent, "CENTER", 250, 0)
        end

        local bagsProfile = self:GetBagsProfile()
        if bagsProfile then
            bagsProfile.window = {
                point = "CENTER",
                relativePoint = "CENTER",
                xOfs = 0,
                yOfs = 0,
                width = DEFAULT_BAGS_WINDOW_WIDTH,
                height = DEFAULT_BAGS_WINDOW_HEIGHT,
            }
            bagsProfile.bankWindow = {
                point = "CENTER",
                relativePoint = "CENTER",
                xOfs = 0,
                yOfs = 0,
                width = DEFAULT_BANK_WINDOW_WIDTH,
                height = DEFAULT_BANK_WINDOW_HEIGHT,
            }
        end

        local bagsFrame = _G["vesperToolsBagsWindow"]
        if bagsFrame then
            bagsFrame:ClearAllPoints()
            bagsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            bagsFrame:SetSize(DEFAULT_BAGS_WINDOW_WIDTH, DEFAULT_BAGS_WINDOW_HEIGHT)
        end

        local bankFrame = _G["vesperToolsBankWindow"]
        if bankFrame then
            bankFrame:ClearAllPoints()
            bankFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            bankFrame:SetSize(DEFAULT_BANK_WINDOW_WIDTH, DEFAULT_BANK_WINDOW_HEIGHT)
        end

        self:Print(L["ALL_FRAME_POSITIONS_RESET"])
    elseif loweredInput == "sync" then
        local Auto = self:GetModule("Automation", true)
        if Auto then
            Auto:ManualSync()
        else
            self:Print(L["AUTOMATION_MODULE_NOT_FOUND"])
        end
    elseif loweredInput == "debug" or loweredInput == "keys" then
        -- Debug: Dump keystone database
        local KeystoneSync = self:GetModule("KeystoneSync", true)
        if KeystoneSync then
            KeystoneSync:DebugDumpKeystones()
        else
            self:Print(L["KEYSTONE_SYNC_MODULE_NOT_FOUND"])
        end
    elseif loweredInput == "bestkeys" then
        -- Debug: Dump best keys database
        local DataHandle = self:GetModule("DataHandle", true)
        if not DataHandle then
            self:Print(L["DATA_HANDLE_MODULE_NOT_FOUND"])
            return
        end
        local db = DataHandle:GetBestKeysDB()
        if not db or not next(db) then
            self:Print(L["BEST_KEYS_DATABASE_EMPTY"])
            return
        end
        self:Print(L["BEST_KEYS_DATABASE_HEADER"])
        local count = 0
        for playerName, data in pairs(db) do
            local entries = {}
            for mapID, info in pairs(data) do
                if type(info) == "table" and info.level then
                    local dungName = C_ChallengeMode.GetMapUIInfo(mapID) or tostring(mapID)
                    local timeStr = string.format("%d:%02d", math.floor(info.duration / 60), info.duration % 60)
                    local timedStr = info.inTime and L["BEST_KEYS_STATUS_TIMED"] or L["BEST_KEYS_STATUS_OVER"]
                    table.insert(entries, string.format(L["BEST_KEYS_DATABASE_LINE_FMT"], dungName, info.level, timeStr, timedStr))
                end
            end
            local age = data.timestamp and (time() - data.timestamp) or 0
            self:Print(string.format(L["BEST_KEYS_DATABASE_ENTRY_HEADER_FMT"], playerName, age))
            for _, e in ipairs(entries) do
                self:Print(e)
            end
            count = count + 1
        end
        self:Print(string.format(L["BEST_KEYS_DATABASE_TOTAL_FMT"], count))
    else
        self:Print(string.format(L["UNKNOWN_COMMAND_FMT"], normalizedInput))
        self:Print(L["SLASH_USAGE"])
    end
end
