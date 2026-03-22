local addonName, addonTable = ...
local localeDefaults = addonTable.LocaleDefaults or {}

-- Helper to safely get localee
local L = addonTable.L or {}
setmetatable(L, { __index = function(t, k) return k end })

-- Check dependencies
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

-- Global Addon Objectt
vesperTools = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local AceLocale = LibStub("AceLocale-3.0", true)
if AceLocale then
    L = AceLocale:GetLocale(addonName)
end
addonTable.L = L
vesperTools.L = L

local CURRENT_MAIN_DB_NAME = "vesperToolsDB"
local CURRENT_BAGS_DB_NAME = "vesperToolsBagsDB"
local LEGACY_MAIN_DB_NAME = "VesperGuildDB"
local LEGACY_BAGS_DB_NAME = "VesperGuildBagsDB"

local function RequestGuildRosterUpdate()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

-- Shared default font used when profile-specific value is missing or invalid.
local DEFAULT_FONT_PATH = "Interface\\AddOns\\vesperTools\\Media\\expressway.ttf"
local DEFAULT_PRIMARY_HEARTHSTONE_ID = 6948
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
local MODERN_CLOSE_BUTTON_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\CloseModern-128"

-- Curated font options exposed in configuration UI.
local FONT_OPTIONS = {
    { label = "Expressway", path = "Interface\\AddOns\\vesperTools\\Media\\expressway.ttf" },
    { label = "Noto Sans SemiBold", path = "Interface\\AddOns\\vesperTools\\Media\\NotoSans-SemiBold.ttf" },
    { label = "Ubuntu Nerd Regular", path = "Interface\\AddOns\\vesperTools\\Media\\UbuntuNerdFont-Regular.ttf" },
    { label = "Ubuntu Nerd Bold", path = "Interface\\AddOns\\vesperTools\\Media\\UbuntuNerdFont-Bold.ttf" },
    { label = "Ubuntu Nerd Condensed", path = "Interface\\AddOns\\vesperTools\\Media\\UbuntuNerdFont-Condensed.ttf" },
    { label = "Ubuntu Nerd Propo Regular", path = "Interface\\AddOns\\vesperTools\\Media\\UbuntuNerdFontPropo-Regular.ttf" },
}

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

-- Return available bundled font options for config UI.
function vesperTools:GetFontOptions()
    return FONT_OPTIONS
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
    local iconInset = tonumber(resolvedOptions.iconInset)
    local iconSize
    if iconInset then
        iconSize = math.max(8, size - (math.floor(iconInset + 0.5) * 2))
    else
        iconSize = math.max(8, math.floor((size * iconScale) + 0.5))
    end

    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(size, size)
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
    icon:SetTexture(MODERN_CLOSE_BUTTON_TEXTURE)
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

-- Read saved primary hearthstone selection with profile/default fallback.
function vesperTools:GetConfiguredPrimaryHearthstoneID()
    local profile = self.db and self.db.profile
    if not profile then
        return DEFAULT_PRIMARY_HEARTHSTONE_ID
    end

    profile.portals = profile.portals or {}
    local configured = tonumber(profile.portals.primaryHearthstoneItemID) or DEFAULT_PRIMARY_HEARTHSTONE_ID
    profile.portals.primaryHearthstoneItemID = configured
    return configured
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

    for i = 1, #options do
        if options[i].itemID == configuredID then
            return configuredID
        end
    end

    local fallbackID = options[1].itemID
    local profile = self.db and self.db.profile
    if profile then
        profile.portals = profile.portals or {}
        profile.portals.primaryHearthstoneItemID = fallbackID
    end
    return fallbackID
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
    local profile = self.db and self.db.profile
    if not profile then
        return DEFAULT_FONT_PATH
    end

    profile.style = profile.style or {}
    local configured = profile.style.fontPath
    if type(configured) == "string" and configured ~= "" then
        return configured
    end

    profile.style.fontPath = DEFAULT_FONT_PATH
    return DEFAULT_FONT_PATH
end

-- Resolve friendly label for a font path.
function vesperTools:GetFontLabelByPath(path)
    for i = 1, #FONT_OPTIONS do
        local option = FONT_OPTIONS[i]
        if option.path == path then
            return option.label
        end
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

local function MigrateLegacySavedVariables()
    if _G[CURRENT_MAIN_DB_NAME] == nil and _G[LEGACY_MAIN_DB_NAME] ~= nil then
        _G[CURRENT_MAIN_DB_NAME] = _G[LEGACY_MAIN_DB_NAME]
    end

    if _G[CURRENT_BAGS_DB_NAME] == nil and _G[LEGACY_BAGS_DB_NAME] ~= nil then
        _G[CURRENT_BAGS_DB_NAME] = _G[LEGACY_BAGS_DB_NAME]
    end
end

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
            portals = {
                -- User-selected hearthstone used by the primary top utility button.
                primaryHearthstoneItemID = DEFAULT_PRIMARY_HEARTHSTONE_ID,
                -- Toy IDs shown in the utility flyout button above portals.
                utilityToyWhitelist = {},
                -- Icon size used by top utility hearthstone/toy buttons.
                utilityButtonSize = DEFAULT_TOP_UTILITY_BUTTON_SIZE,
            },
        },
        global = {
            keystones = {}, -- Persistent keystone storage
            ilvlSync = {},  -- Persistent ilvl storage from guild sync
            bestKeys = {},  -- Persistent best M+ keys from guild sync
        },
    }, true)

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
                qualityGlowIntensity = DEFAULT_BAGS_QUALITY_GLOW_INTENSITY,
                combineStacks = false,
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
            lastViewedCharacterGUID = nil,
            lastViewedBankView = "warband",
            replaceBackpack = false,
            replaceCharacterBank = false,
            replaceAccountBank = false,
        },
        global = {
            schemaVersion = 1,
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

    profile.display = profile.display or {}
    profile.display.columns = math.max(1, math.min(20, math.floor((tonumber(profile.display.columns) or DEFAULT_BAGS_COLUMNS) + 0.5)))
    profile.display.itemIconSize = math.max(24, math.min(56, math.floor((tonumber(profile.display.itemIconSize) or DEFAULT_BAGS_ITEM_ICON_SIZE) + 0.5)))
    profile.display.stackCountFontSize = math.max(8, math.min(20, math.floor((tonumber(profile.display.stackCountFontSize) or DEFAULT_BAGS_STACK_COUNT_FONT_SIZE) + 0.5)))
    profile.display.itemLevelFontSize = math.max(8, math.min(18, math.floor((tonumber(profile.display.itemLevelFontSize) or DEFAULT_BAGS_ITEM_LEVEL_FONT_SIZE) + 0.5)))
    profile.display.showEquippedBags = profile.display.showEquippedBags and true or false
    profile.display.showItemLevel = profile.display.showItemLevel and true or false
    profile.display.qualityGlowIntensity = math.max(0, math.min(1, tonumber(profile.display.qualityGlowIntensity) or DEFAULT_BAGS_QUALITY_GLOW_INTENSITY))
    profile.display.combineStacks = profile.display.combineStacks and true or false
    profile.bankDisplay = profile.bankDisplay or {}
    profile.bankDisplay.columns = math.max(1, math.min(20, math.floor((tonumber(profile.bankDisplay.columns) or DEFAULT_BANK_COLUMNS) + 0.5)))
    profile.bankDisplay.itemIconSize = math.max(24, math.min(56, math.floor((tonumber(profile.bankDisplay.itemIconSize) or DEFAULT_BANK_ITEM_ICON_SIZE) + 0.5)))
    profile.bankDisplay.stackCountFontSize = math.max(8, math.min(20, math.floor((tonumber(profile.bankDisplay.stackCountFontSize) or DEFAULT_BANK_STACK_COUNT_FONT_SIZE) + 0.5)))
    profile.bankDisplay.itemLevelFontSize = math.max(8, math.min(18, math.floor((tonumber(profile.bankDisplay.itemLevelFontSize) or DEFAULT_BANK_ITEM_LEVEL_FONT_SIZE) + 0.5)))
    profile.bankDisplay.showItemLevel = profile.bankDisplay.showItemLevel and true or false
    profile.bankDisplay.qualityGlowIntensity = math.max(0, math.min(1, tonumber(profile.bankDisplay.qualityGlowIntensity) or DEFAULT_BANK_QUALITY_GLOW_INTENSITY))
    profile.bankDisplay.combineStacks = profile.bankDisplay.combineStacks and true or false
    if type(profile.collapsedCategories) ~= "table" then
        profile.collapsedCategories = {}
    end
    if type(profile.collapsedBankCategories) ~= "table" then
        profile.collapsedBankCategories = {}
    end

    if type(profile.lastViewedCharacterGUID) ~= "string" or profile.lastViewedCharacterGUID == "" then
        profile.lastViewedCharacterGUID = nil
    end
    if profile.lastViewedBankView ~= "character" and profile.lastViewedBankView ~= "warband" then
        profile.lastViewedBankView = "warband"
    end

    profile.replaceBackpack = profile.replaceBackpack and true or false
    profile.replaceCharacterBank = profile.replaceCharacterBank and true or false
    profile.replaceAccountBank = profile.replaceAccountBank and true or false

    return profile
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

function vesperTools:GetCurrentCharacterFullName()
    local name = UnitName("player") or UNKNOWN
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "UnknownRealm"
    return string.format("%s-%s", name, realm)
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

function vesperTools:GetOnlineGuildMembers()
    local members = {}
    if not IsInGuild() then
        return members
    end

    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, _, level, _, zone, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline and name then
            local displayName = name:match("([^-]+)") or name
            table.insert(members, {
                name = displayName,
                level = level or 0,
                zone = (zone and zone ~= "" and zone) or UNKNOWN,
            })
        end
    end

    table.sort(members, function(a, b)
        return a.name < b.name
    end)

    return members
end

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

-- Baaaaaaa, create a sheep
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
