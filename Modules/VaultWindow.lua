local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local VaultWindow = vesperTools:NewModule("VaultWindow", "AceEvent-3.0")
local L = vesperTools.L

local MIN_WINDOW_WIDTH = 560
local MIN_WINDOW_HEIGHT = 600
local CHARACTER_DROPDOWN_WIDTH = 240
local CHARACTER_DROPDOWN_HEIGHT = 22
local CHARACTER_MENU_ROW_HEIGHT = 24
local CHARACTER_MENU_PADDING = 4
local CHARACTER_MENU_GAP = 4
local NAV_LEFT_INSET = 10
local NAV_RIGHT_INSET = 40
local WINDOW_CONTENT_PADDING = 10
local SECTION_GAP = 12
local SECTION_HEADER_HEIGHT = 22
local ROW_HEIGHT = 42
local ROW_GAP = 6
local LIVE_BUTTON_WIDTH = 86
local HEADER_ACTION_BUTTON_HEIGHT = 22
local DROPDOWN_ARROW_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\DropdownArrow-50"
local FALLBACK_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"
local LOCKED_CHEST_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\VaultClosedChest-64"
local PREVIEW_CHEST_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\VaultPreviewChest-64"
local UPGRADE_TRACK_NAMES = {
    Explorer = "Explorer",
    Adventurer = "Adventurer",
    Veteran = "Veteran",
    Champion = "Champion",
    Hero = "Hero",
    Myth = "Myth",
}
local UPGRADE_TRACK_ORDER = {
    "Myth",
    "Hero",
    "Champion",
    "Veteran",
    "Adventurer",
    "Explorer",
}
local UPGRADE_TRACK_COLORS = {
    Explorer = "ff9aa4b2",
    Adventurer = "ff5fbf8f",
    Veteran = "ff44c767",
    Champion = "ff4f8df7",
    Hero = "ffa95cff",
    Myth = "ffff9a2e",
}
local TRACK_MAX_STEP = 6
-- Midnight Season 1 Great Vault preview mappings.
local DUNGEON_VAULT_PREVIEW_BY_LEVEL = {
    heroic = { trackName = "Veteran", step = 4, itemLevel = 243 },
    mythic0 = { trackName = "Champion", step = 4, itemLevel = 256 },
    [2] = { trackName = "Hero", step = 1, itemLevel = 259 },
    [3] = { trackName = "Hero", step = 1, itemLevel = 259 },
    [4] = { trackName = "Hero", step = 2, itemLevel = 263 },
    [5] = { trackName = "Hero", step = 2, itemLevel = 263 },
    [6] = { trackName = "Hero", step = 3, itemLevel = 266 },
    [7] = { trackName = "Hero", step = 4, itemLevel = 269 },
    [8] = { trackName = "Hero", step = 4, itemLevel = 269 },
    [9] = { trackName = "Hero", step = 4, itemLevel = 269 },
    [10] = { trackName = "Myth", step = 1, itemLevel = 272 },
}
local DELVE_VAULT_PREVIEW_BY_LEVEL = {
    [1] = { trackName = "Veteran", step = 1, itemLevel = 233 },
    [2] = { trackName = "Veteran", step = 2, itemLevel = 237 },
    [3] = { trackName = "Veteran", step = 3, itemLevel = 240 },
    [4] = { trackName = "Veteran", step = 4, itemLevel = 243 },
    [5] = { trackName = "Champion", step = 1, itemLevel = 246 },
    [6] = { trackName = "Champion", step = 3, itemLevel = 253 },
    [7] = { trackName = "Champion", step = 4, itemLevel = 256 },
    [8] = { trackName = "Hero", step = 1, itemLevel = 259 },
}
local RAID_DIFFICULTY_PREVIEW = {
    [17] = { trackName = "Veteran" },
    [14] = { trackName = "Champion" },
    [15] = { trackName = "Hero" },
    [16] = { trackName = "Myth" },
}
local RAID_DIFFICULTY_SOURCE_KEYS = {
    [17] = "VAULT_SOURCE_RAID_LFR",
    [14] = "VAULT_SOURCE_RAID_NORMAL",
    [15] = "VAULT_SOURCE_RAID_HEROIC",
    [16] = "VAULT_SOURCE_RAID_MYTHIC",
}
local normalizeTooltipText

local function buildRewardTypeOrder()
    local order = {}
    local seen = {}
    local thresholdType = Enum and Enum.WeeklyRewardChestThresholdType or nil

    local function add(value)
        if type(value) ~= "number" or seen[value] then
            return
        end
        seen[value] = true
        order[#order + 1] = value
    end

    if thresholdType then
        add(thresholdType.Activities)
        add(thresholdType.Raid)
        add(thresholdType.World)
    end

    return order
end

local REWARD_TYPE_ORDER = buildRewardTypeOrder()

local function normalizeLink(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    return value
end

local function getRewardDisplayLink(activity)
    if type(activity) ~= "table" then
        return nil
    end

    return normalizeLink(activity.itemLink)
        or normalizeLink(activity.actualItemLink)
        or normalizeLink(activity.exampleItemLink)
        or normalizeLink(activity.upgradeItemLink)
        or normalizeLink(activity.actualUpgradeItemLink)
        or normalizeLink(activity.exampleUpgradeItemLink)
        or nil
end

local function getActualRewardLink(activity)
    if type(activity) ~= "table" then
        return nil
    end

    return normalizeLink(activity.actualItemLink)
        or normalizeLink(activity.actualUpgradeItemLink)
        or nil
end

local function extractItemIDFromLink(link)
    local resolvedLink = normalizeLink(link)
    if not resolvedLink then
        return nil
    end

    local itemID = resolvedLink:match("item:(%-?%d+)")
    local numeric = tonumber(itemID)
    if numeric and numeric > 0 then
        return math.floor(numeric + 0.5)
    end

    return nil
end

local function getItemIconForLink(link)
    local resolvedLink = normalizeLink(link)
    if not resolvedLink then
        return FALLBACK_ICON_TEXTURE
    end

    if C_Item and C_Item.GetItemInfo then
        local itemInfo = C_Item.GetItemInfo(resolvedLink)
        if type(itemInfo) == "table" and itemInfo.iconFileID then
            return itemInfo.iconFileID
        end
    end

    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, iconFileID = C_Item.GetItemInfoInstant(resolvedLink)
        if iconFileID then
            return iconFileID
        end
    end

    local itemID = extractItemIDFromLink(resolvedLink)
    if itemID and C_Item and C_Item.GetItemIconByID then
        local iconFileID = C_Item.GetItemIconByID(itemID)
        if iconFileID then
            return iconFileID
        end
    end

    if GetItemIcon then
        local iconFileID = GetItemIcon(resolvedLink)
        if iconFileID then
            return iconFileID
        end
    end

    local _, _, _, _, iconFileID = GetItemInfoInstant(resolvedLink)
    return iconFileID or FALLBACK_ICON_TEXTURE
end

local function getDetailedItemLevel(link)
    local resolvedLink = normalizeLink(link)
    if not resolvedLink or not GetDetailedItemLevelInfo then
        return nil
    end

    local resolvedItemLevel = GetDetailedItemLevelInfo(resolvedLink)
    local itemLevel = tonumber(resolvedItemLevel)
    if itemLevel and itemLevel > 0 then
        return math.floor(itemLevel + 0.5)
    end

    return nil
end

local function buildTrackDisplayText(trackName, step)
    local label = UPGRADE_TRACK_NAMES[trackName]
    if not label then
        return nil
    end

    if step and step > 0 then
        return string.format("%s %d/%d", label, step, TRACK_MAX_STEP)
    end

    return label
end

local function extractUpgradeTrackInfo(text)
    local normalized = normalizeTooltipText(text)
    if not normalized then
        return nil, nil
    end

    local exactMatch = UPGRADE_TRACK_NAMES[normalized]
    if exactMatch then
        return exactMatch, exactMatch
    end

    local fullTrackText, prefixedMatch = normalized:match("^Upgrade Level:%s*((%a+)%s+%d+/%d+)$")
    if prefixedMatch and UPGRADE_TRACK_NAMES[prefixedMatch] then
        return UPGRADE_TRACK_NAMES[prefixedMatch], fullTrackText
    end

    fullTrackText, prefixedMatch = normalized:match("^Upgrade:%s*((%a+)%s+%d+/%d+)$")
    if prefixedMatch and UPGRADE_TRACK_NAMES[prefixedMatch] then
        return UPGRADE_TRACK_NAMES[prefixedMatch], fullTrackText
    end

    fullTrackText, prefixedMatch = normalized:match("^Track:%s*((%a+)%s+%d+/%d+)$")
    if prefixedMatch and UPGRADE_TRACK_NAMES[prefixedMatch] then
        return UPGRADE_TRACK_NAMES[prefixedMatch], fullTrackText
    end

    prefixedMatch = normalized:match("^Upgrade Level:%s*(%a+)$")
        or normalized:match("^Upgrade:%s*(%a+)$")
        or normalized:match("^Track:%s*(%a+)$")
        or normalized:match("^(%a+)%s+%d+/%d+$")
        or normalized:match("^(%a+)$")

    if prefixedMatch and UPGRADE_TRACK_NAMES[prefixedMatch] then
        local normalizedTrack = UPGRADE_TRACK_NAMES[prefixedMatch]
        local trackText = normalized
        if trackText:find(":", 1, true) then
            trackText = buildTrackDisplayText(normalizedTrack)
        end
        return normalizedTrack, trackText or normalizedTrack
    end

    for index = 1, #UPGRADE_TRACK_ORDER do
        local trackName = UPGRADE_TRACK_ORDER[index]
        if normalized:find(trackName, 1, true) then
            return trackName, trackName
        end
    end

    return nil, nil
end

local function getDisplayItemName(link)
    local resolvedLink = normalizeLink(link)
    if not resolvedLink then
        return nil
    end

    if C_Item and C_Item.GetItemInfo then
        local itemInfo = C_Item.GetItemInfo(resolvedLink)
        if type(itemInfo) == "table" then
            local itemName = itemInfo.itemName or itemInfo.name
            if type(itemName) == "string" and itemName ~= "" then
                return itemName
            end
        end
    end

    local itemName = GetItemInfo(resolvedLink)
    if type(itemName) == "string" and itemName ~= "" then
        return itemName
    end

    local itemID = extractItemIDFromLink(resolvedLink)
    if itemID and C_Item and C_Item.GetItemNameByID then
        itemName = C_Item.GetItemNameByID(itemID)
        if type(itemName) == "string" and itemName ~= "" then
            return itemName
        end
    end

    return nil
end

normalizeTooltipText = function(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local normalized = text
    normalized = normalized:gsub("|c%x%x%x%x%x%x%x%x", "")
    normalized = normalized:gsub("|r", "")
    normalized = normalized:gsub("[%z\1-\31]", " ")
    normalized = normalized:gsub("%s+", " ")
    normalized = strtrim(normalized)
    if normalized == "" then
        return nil
    end

    return normalized
end

local function getUpgradeTrackInfo(link)
    local resolvedLink = normalizeLink(link)
    if not resolvedLink or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then
        return nil, nil
    end

    local tooltipData = C_TooltipInfo.GetHyperlink(resolvedLink)
    if type(tooltipData) ~= "table" or type(tooltipData.lines) ~= "table" then
        return nil, nil
    end

    for index = 1, #tooltipData.lines do
        local line = tooltipData.lines[index]
        if type(line) == "table" then
            local textCandidates = {
                line.leftText,
                line.rightText,
                line.text,
            }

            for candidateIndex = 1, #textCandidates do
                local trackName, trackText = extractUpgradeTrackInfo(textCandidates[candidateIndex])
                if trackName then
                    return trackName, trackText
                end
            end
        end
    end

    return nil, nil
end

local function getActualRewardTrackInfo(activity)
    if type(activity) ~= "table" then
        return nil, nil
    end

    local links = {
        activity.actualUpgradeItemLink,
        activity.actualItemLink,
    }
    local seen = {}

    for index = 1, #links do
        local link = normalizeLink(links[index])
        if link and not seen[link] then
            seen[link] = true

            local trackName, trackText = getUpgradeTrackInfo(link)
            if trackName then
                return trackName, trackText
            end
        end
    end

    return nil, nil
end

local function formatTrackLabel(trackLabel, trackText)
    local label = trackText or UPGRADE_TRACK_NAMES[trackLabel]
    if not label then
        return nil
    end

    local colorCode = UPGRADE_TRACK_COLORS[trackLabel] or "ffffffff"
    return string.format("|c%s%s|r", colorCode, label)
end

local function getPreviewLinkItemLevel(activity)
    return getDetailedItemLevel(getRewardDisplayLink(activity))
end

local function getRaidSourceLabel(sourceDifficultyID)
    local difficultyID = tonumber(sourceDifficultyID)
    if not difficultyID or difficultyID <= 0 then
        return L["VAULT_SOURCE_RAID"]
    end

    difficultyID = math.floor(difficultyID + 0.5)

    if difficultyID == 17 and GetDifficultyInfo then
        local difficultyName = GetDifficultyInfo(difficultyID)
        if type(difficultyName) == "string" and difficultyName ~= "" then
            return difficultyName
        end
    end

    if difficultyID ~= 17 and GetDifficultyInfo then
        local difficultyName = GetDifficultyInfo(difficultyID)
        if type(difficultyName) == "string" and difficultyName ~= "" then
            return string.format(L["VAULT_SOURCE_RAID_FMT"], difficultyName)
        end
    end

    local fallbackKey = RAID_DIFFICULTY_SOURCE_KEYS[difficultyID]
    if fallbackKey then
        return L[fallbackKey]
    end

    return L["VAULT_SOURCE_RAID"]
end

local function getDungeonPreviewInfo(activity)
    local level = math.max(0, tonumber(activity and activity.level) or 0)
    local previewItemLevel = getPreviewLinkItemLevel(activity)
    local entry
    local sourceLabel

    if level >= 10 then
        entry = DUNGEON_VAULT_PREVIEW_BY_LEVEL[10]
        sourceLabel = string.format(L["VAULT_SOURCE_DUNGEON_PLUS_FMT"], level)
    elseif level >= 2 then
        entry = DUNGEON_VAULT_PREVIEW_BY_LEVEL[level]
        sourceLabel = string.format(L["VAULT_SOURCE_DUNGEON_PLUS_FMT"], level)
    elseif level >= 1 then
        entry = DUNGEON_VAULT_PREVIEW_BY_LEVEL.heroic
        sourceLabel = L["VAULT_SOURCE_DUNGEON_HEROIC"]
    elseif previewItemLevel and previewItemLevel <= DUNGEON_VAULT_PREVIEW_BY_LEVEL.heroic.itemLevel then
        entry = DUNGEON_VAULT_PREVIEW_BY_LEVEL.heroic
        sourceLabel = L["VAULT_SOURCE_DUNGEON_HEROIC"]
    else
        entry = DUNGEON_VAULT_PREVIEW_BY_LEVEL.mythic0
        sourceLabel = L["VAULT_SOURCE_DUNGEON_M0"]
    end

    return {
        trackName = entry and entry.trackName or nil,
        trackText = entry and buildTrackDisplayText(entry.trackName, entry.step) or nil,
        itemLevel = entry and entry.itemLevel or previewItemLevel,
        sourceLabel = sourceLabel,
    }
end

local function getDelvePreviewInfo(activity)
    local level = math.max(1, tonumber(activity and activity.level) or 1)
    local entry = DELVE_VAULT_PREVIEW_BY_LEVEL[math.min(level, 8)] or DELVE_VAULT_PREVIEW_BY_LEVEL[8]

    return {
        trackName = entry and entry.trackName or nil,
        trackText = entry and buildTrackDisplayText(entry.trackName, entry.step) or nil,
        itemLevel = entry and entry.itemLevel or getPreviewLinkItemLevel(activity),
        sourceLabel = string.format(L["VAULT_SOURCE_DELVE_FMT"], level),
    }
end

local function getRaidPreviewInfo(activity)
    local difficultyID = tonumber(activity and activity.sourceDifficultyID)
    local preview = difficultyID and RAID_DIFFICULTY_PREVIEW[math.floor(difficultyID + 0.5)] or nil

    return {
        trackName = preview and preview.trackName or nil,
        trackText = preview and buildTrackDisplayText(preview.trackName) or nil,
        itemLevel = nil,
        sourceLabel = getRaidSourceLabel(difficultyID),
    }
end

local function getComputedPreviewInfo(rewardType, activity)
    local thresholdType = Enum and Enum.WeeklyRewardChestThresholdType or nil
    if not thresholdType then
        return {
            trackName = nil,
            trackText = nil,
            itemLevel = getPreviewLinkItemLevel(activity),
            sourceLabel = nil,
        }
    end

    if rewardType == thresholdType.Activities then
        return getDungeonPreviewInfo(activity)
    end
    if rewardType == thresholdType.World then
        return getDelvePreviewInfo(activity)
    end
    if rewardType == thresholdType.Raid then
        return getRaidPreviewInfo(activity)
    end

    return {
        trackName = nil,
        trackText = nil,
        itemLevel = getPreviewLinkItemLevel(activity),
        sourceLabel = nil,
    }
end

local function getActivityRaidDisplayText(activity)
    local raidText = type(activity and activity.raidString) == "string" and strtrim(activity.raidString) or nil
    if not raidText or raidText == "" then
        return nil
    end

    if not raidText:find("%", 1, true) then
        return raidText
    end

    local threshold = math.max(0, tonumber(activity and activity.threshold) or 0)
    if threshold > 0 then
        local ok, formatted = pcall(string.format, raidText, threshold)
        if ok and type(formatted) == "string" and formatted ~= "" then
            return formatted
        end

        local replaced = raidText:gsub("%%d", tostring(threshold))
        if replaced ~= "" then
            return replaced
        end
    end

    return raidText:gsub("%%d", "")
end

local function buildPreviewTooltipLines(rewardType, activity, itemLevel, trackText, sourceLabel, isLocked)
    local lines = {}
    local progress = math.max(0, tonumber(activity and activity.progress) or 0)
    local threshold = math.max(0, tonumber(activity and activity.threshold) or 0)

    if threshold > 0 then
        if isLocked then
            lines[#lines + 1] = string.format("%d/%d", progress, threshold)
        else
            lines[#lines + 1] = L["VAULT_READY"]
        end
    end

    if sourceLabel then
        lines[#lines + 1] = sourceLabel
    end

    if trackText then
        lines[#lines + 1] = trackText
    end

    if itemLevel and itemLevel > 0 then
        lines[#lines + 1] = string.format(L["VAULT_ITEM_LEVEL_FMT"], itemLevel)
    end

    local thresholdType = Enum and Enum.WeeklyRewardChestThresholdType or nil
    if thresholdType and rewardType == thresholdType.Raid then
        local raidText = getActivityRaidDisplayText(activity)
        if raidText then
            lines[#lines + 1] = raidText
        end
    end

    if #lines == 0 then
        lines[#lines + 1] = L["VAULT_REWARD_PREVIEW"]
    end

    return lines
end

local function formatCapturedTimestamp(timestamp)
    local resolved = tonumber(timestamp)
    if not resolved or resolved <= 0 then
        return nil
    end

    return date("%b %d %H:%M", resolved)
end

function VaultWindow:OnInitialize()
    self.frame = nil
    self.titleText = nil
    self.modeText = nil
    self.characterDropdown = nil
    self.characterDropdownText = nil
    self.characterDropdownArrow = nil
    self.characterMenu = nil
    self.characterMenuDismiss = nil
    self.characterMenuButtons = {}
    self.openLiveButton = nil
    self.openLiveButtonText = nil
    self.captureText = nil
    self.content = nil
    self.scrollFrame = nil
    self.scrollContent = nil
    self.emptyText = nil
    self.sectionFrames = {}
    self.selectedCharacterKey = nil
    self.displayCharacters = {}
    self.currentDisplayCharacter = nil
    self.currentSnapshot = nil
end

function VaultWindow:OnEnable()
    self:RegisterMessage("VESPERTOOLS_VAULT_SNAPSHOT_UPDATED", "OnVaultDataChanged")
    self:RegisterMessage("VESPERTOOLS_VAULT_CHARACTER_UPDATED", "OnVaultDataChanged")
    self:RegisterMessage("VESPERTOOLS_CONFIG_CHANGED", "OnConfigChanged")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end

function VaultWindow:GetStore()
    return vesperTools:GetModule("VaultStore", true)
end

function VaultWindow:OnVaultDataChanged()
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function VaultWindow:OnConfigChanged()
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function VaultWindow:GET_ITEM_INFO_RECEIVED()
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function VaultWindow:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
        return
    end

    self:ShowWindow()
end

function VaultWindow:ShowWindow()
    if not self.frame then
        self:CreateWindow()
    end

    self:SelectCurrentCharacterForOpen()
    self:RefreshWindow()
    self.frame:Show()
    self.frame:Raise()
end

function VaultWindow:SelectCurrentCharacterForOpen()
    local store = self:GetStore()
    if not store or type(store.CreateOrUpdateCurrentCharacter) ~= "function" then
        return
    end

    store:CreateOrUpdateCurrentCharacter()
    local currentCharacterKey = store:GetCurrentCharacterKey()
    if type(currentCharacterKey) ~= "string" or currentCharacterKey == "" then
        return
    end

    self.selectedCharacterKey = currentCharacterKey

    local bagsProfile = vesperTools:GetBagsProfile()
    if bagsProfile then
        bagsProfile.lastViewedVaultCharacterGUID = currentCharacterKey
    end
end

function VaultWindow:ResolveSelectedCharacter()
    local store = self:GetStore()
    if not store then
        self.displayCharacters = {}
        self.selectedCharacterKey = nil
        return nil
    end

    self.displayCharacters = type(store.GetDisplayCharacters) == "function" and store:GetDisplayCharacters() or {}
    if #self.displayCharacters == 0 then
        self.selectedCharacterKey = nil
        return nil
    end

    local bagsProfile = vesperTools:GetBagsProfile()
    local selectedKey = self.selectedCharacterKey or (bagsProfile and bagsProfile.lastViewedVaultCharacterGUID) or nil
    for i = 1, #self.displayCharacters do
        if self.displayCharacters[i].key == selectedKey then
            self.selectedCharacterKey = selectedKey
            return self.displayCharacters[i]
        end
    end

    self.selectedCharacterKey = self.displayCharacters[1].key
    if bagsProfile then
        bagsProfile.lastViewedVaultCharacterGUID = self.selectedCharacterKey
    end
    return self.displayCharacters[1]
end

function VaultWindow:SetSelectedCharacter(characterKey)
    if type(characterKey) ~= "string" or characterKey == "" then
        return
    end

    self.selectedCharacterKey = characterKey
    local bagsProfile = vesperTools:GetBagsProfile()
    if bagsProfile then
        bagsProfile.lastViewedVaultCharacterGUID = characterKey
    end
    self:RefreshWindow()
end

function VaultWindow:UpdateCharacterDropdownVisual()
    if not self.characterDropdown then
        return
    end

    local isOpen = self.characterMenu and self.characterMenu:IsShown()
    local backdropAlpha = isOpen and 0.98 or 0.92
    self.characterDropdown:SetBackdropColor(0.08, 0.08, 0.1, backdropAlpha)
    if self.characterDropdownArrow then
        self.characterDropdownArrow:SetTexture(DROPDOWN_ARROW_TEXTURE)
        self.characterDropdownArrow:SetRotation(isOpen and math.pi or 0)
    end
end

function VaultWindow:HideCharacterMenu()
    if self.characterMenu then
        self.characterMenu:Hide()
    end

    if self.characterMenuDismiss then
        self.characterMenuDismiss:Hide()
    end

    self:UpdateCharacterDropdownVisual()
end

function VaultWindow:GetCharacterMenuFrames()
    if not self.characterMenuDismiss then
        local dismiss = CreateFrame("Button", nil, UIParent)
        dismiss:SetAllPoints(UIParent)
        dismiss:SetFrameStrata("TOOLTIP")
        dismiss:SetToplevel(true)
        dismiss:EnableMouse(true)
        dismiss:SetScript("OnClick", function()
            self:HideCharacterMenu()
        end)
        dismiss:Hide()
        self.characterMenuDismiss = dismiss
    end

    if not self.characterMenu then
        local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu:SetClampedToScreen(true)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        menu:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
        menu:SetBackdropBorderColor(1, 1, 1, 0.12)
        menu:SetFrameStrata("TOOLTIP")
        menu:SetToplevel(true)
        menu:Hide()
        self.characterMenu = menu
    end

    local baseLevel = math.max(90, (self.frame and self.frame:GetFrameLevel() or 0) + 60)
    self.characterMenuDismiss:SetFrameLevel(baseLevel - 1)
    self.characterMenu:SetFrameLevel(baseLevel)

    return self.characterMenu, self.characterMenuDismiss
end

function VaultWindow:AcquireCharacterMenuButton(menu)
    local index = #self.characterMenuButtons + 1
    local button = CreateFrame("Button", nil, menu)
    button:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
    button:GetNormalTexture():SetVertexColor(0, 0, 0, 0)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    button:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.18)

    local selectedBackground = button:CreateTexture(nil, "BACKGROUND")
    selectedBackground:SetAllPoints()
    selectedBackground:SetColorTexture(0.22, 0.44, 0.7, 0.22)
    selectedBackground:Hide()
    button.selectedBackground = selectedBackground

    local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", button, "LEFT", 10, 0)
    text:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(text, 12, "")
    button.text = text

    button:SetScript("OnClick", function(selfButton)
        self:HideCharacterMenu()
        if selfButton.characterKey then
            self:SetSelectedCharacter(selfButton.characterKey)
        end
    end)

    self.characterMenuButtons[index] = button
    return button
end

function VaultWindow:RefreshCharacterMenu()
    local menu = self.characterMenu
    if not menu then
        return
    end

    local menuWidth = math.max(CHARACTER_DROPDOWN_WIDTH, self.characterDropdown and math.floor((self.characterDropdown:GetWidth() or CHARACTER_DROPDOWN_WIDTH) + 0.5) or CHARACTER_DROPDOWN_WIDTH)
    local innerWidth = menuWidth - (CHARACTER_MENU_PADDING * 2)
    local visibleCount = #self.displayCharacters

    for i = 1, visibleCount do
        local character = self.displayCharacters[i]
        local button = self.characterMenuButtons[i] or self:AcquireCharacterMenuButton(menu)
        button.characterKey = character.key
        button:SetSize(innerWidth, CHARACTER_MENU_ROW_HEIGHT)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", CHARACTER_MENU_PADDING, -CHARACTER_MENU_PADDING - ((i - 1) * CHARACTER_MENU_ROW_HEIGHT))
        button.text:SetText(character.fullName)
        if character.key == self.selectedCharacterKey then
            button.selectedBackground:Show()
            button.text:SetTextColor(0.92, 0.97, 1, 1)
        else
            button.selectedBackground:Hide()
            button.text:SetTextColor(0.82, 0.86, 0.92, 1)
        end
        button:Show()
    end

    for i = visibleCount + 1, #self.characterMenuButtons do
        self.characterMenuButtons[i]:Hide()
    end

    menu:SetSize(menuWidth, (CHARACTER_MENU_PADDING * 2) + (visibleCount * CHARACTER_MENU_ROW_HEIGHT))
end

function VaultWindow:OpenCharacterMenu(button)
    if not button then
        return
    end

    local menu, dismiss = self:GetCharacterMenuFrames()
    if menu:IsShown() then
        self:HideCharacterMenu()
        return
    end

    self:RefreshCharacterMenu()

    dismiss:Show()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -CHARACTER_MENU_GAP)
    menu:Show()
    self:UpdateCharacterDropdownVisual()
end

function VaultWindow:SaveWindowState()
    if not self.frame then
        return
    end

    local bagsProfile = vesperTools:GetBagsProfile()
    if not bagsProfile then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = self.frame:GetPoint()
    bagsProfile.vaultWindow.point = point
    bagsProfile.vaultWindow.relativePoint = relativePoint
    bagsProfile.vaultWindow.xOfs = xOfs
    bagsProfile.vaultWindow.yOfs = yOfs
    bagsProfile.vaultWindow.width = math.floor((self.frame:GetWidth() or MIN_WINDOW_WIDTH) + 0.5)
    bagsProfile.vaultWindow.height = math.floor((self.frame:GetHeight() or MIN_WINDOW_HEIGHT) + 0.5)
end

function VaultWindow:GetLaneTitle(rewardType)
    local thresholdType = Enum and Enum.WeeklyRewardChestThresholdType or nil
    if thresholdType and rewardType == thresholdType.Activities then
        return L["VAULT_LANE_ACTIVITIES"]
    end
    if thresholdType and rewardType == thresholdType.Raid then
        return L["VAULT_LANE_RAID"]
    end
    if thresholdType and rewardType == thresholdType.World then
        return L["VAULT_LANE_WORLD"]
    end

    return L["UNKNOWN_LABEL"]
end

function VaultWindow:SetOpenLiveButtonEnabled(isEnabled)
    if not self.openLiveButton then
        return
    end

    if isEnabled then
        self.openLiveButton:Enable()
        self.openLiveButton:SetAlpha(1)
    else
        self.openLiveButton:Disable()
        self.openLiveButton:SetAlpha(0.5)
    end
end

function VaultWindow:OpenLiveVault()
    local selectedCharacter = self.currentDisplayCharacter
    if not selectedCharacter or not selectedCharacter.isCurrent then
        return
    end

    if UIParentLoadAddOn and not WeeklyRewards_ShowUI then
        UIParentLoadAddOn("Blizzard_WeeklyRewards")
    end

    if WeeklyRewards_ShowUI then
        WeeklyRewards_ShowUI()
    end

    local store = self:GetStore()
    if store and type(store.QueueCapture) == "function" then
        store:QueueCapture(0.15)
    end
end

function VaultWindow:ConfigureOpenLiveButtonTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

    if self.currentDisplayCharacter and self.currentDisplayCharacter.isCurrent then
        GameTooltip:SetText(L["VAULT_OPEN_LIVE"], 1, 1, 1)
        GameTooltip:AddLine(L["VAULT_OPEN_LIVE_HINT"], 0.85, 0.85, 0.85, true)
    else
        GameTooltip:SetText(L["VAULT_CURRENT_CHARACTER_ONLY"], 1, 0.4, 0.4)
        GameTooltip:AddLine(L["VAULT_OPEN_LIVE_UNAVAILABLE"], 0.85, 0.85, 0.85, true)
    end

    GameTooltip:Show()
end

function VaultWindow:CreateWindow()
    local bagsProfile = vesperTools:GetBagsProfile()
    local width = math.max(MIN_WINDOW_WIDTH, bagsProfile and bagsProfile.vaultWindow and bagsProfile.vaultWindow.width or 760)
    local height = math.max(MIN_WINDOW_HEIGHT, bagsProfile and bagsProfile.vaultWindow and bagsProfile.vaultWindow.height or MIN_WINDOW_HEIGHT)

    local frame = CreateFrame("Frame", "vesperToolsVaultWindow", UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    vesperTools:ApplyAddonWindowLayer(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(false)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("portals"))

    local _, englishClass = UnitClass("player")
    local classColor = C_ClassColor.GetClassColor(englishClass)
    frame:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)

    if bagsProfile and bagsProfile.vaultWindow then
        frame:SetPoint(
            bagsProfile.vaultWindow.point,
            UIParent,
            bagsProfile.vaultWindow.relativePoint,
            bagsProfile.vaultWindow.xOfs,
            bagsProfile.vaultWindow.yOfs
        )
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local titlebar = CreateFrame("Frame", nil, frame)
    titlebar:SetHeight(32)
    titlebar:SetPoint("TOPLEFT", 1, -1)
    titlebar:SetPoint("TOPRIGHT", -1, -1)
    titlebar:EnableMouse(true)
    titlebar:RegisterForDrag("LeftButton")
    titlebar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titlebar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SaveWindowState()
    end)

    local titleBackground = titlebar:CreateTexture(nil, "BACKGROUND")
    titleBackground:SetAllPoints()
    titleBackground:SetColorTexture(0.1, 0.1, 0.1, 1)

    local titleText = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", 10, 0)
    titleText:SetText(L["GREAT_VAULT"])
    vesperTools:ApplyConfiguredFont(titleText, vesperTools:GetConfiguredFontSize("roster", 12, 8, 24) + 4, "")
    self.titleText = titleText

    local modeText = titlebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modeText:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
    vesperTools:ApplyConfiguredFont(modeText, 12, "")
    self.modeText = modeText

    local closeButton = vesperTools:CreateModernCloseButton(titlebar, function()
        self:HideCharacterMenu()
        frame:Hide()
    end, {
        size = 20,
        iconScale = 0.52,
        backgroundAlpha = 0.04,
        borderAlpha = 0.08,
        hoverAlpha = 0.12,
        pressedAlpha = 0.18,
    })
    closeButton:SetPoint("RIGHT", -6, 0)

    local navFrame = CreateFrame("Frame", nil, frame)
    navFrame:SetHeight(28)
    navFrame:SetPoint("TOPLEFT", titlebar, "BOTTOMLEFT", NAV_LEFT_INSET, -8)
    navFrame:SetPoint("TOPRIGHT", titlebar, "BOTTOMRIGHT", -NAV_RIGHT_INSET, -8)

    local characterDropdown = CreateFrame("Button", nil, navFrame, "BackdropTemplate")
    characterDropdown:SetPoint("LEFT", navFrame, "LEFT", 0, 0)
    characterDropdown:SetSize(CHARACTER_DROPDOWN_WIDTH, CHARACTER_DROPDOWN_HEIGHT)
    characterDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    characterDropdown:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    characterDropdown:SetBackdropBorderColor(1, 1, 1, 0.12)
    characterDropdown:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    characterDropdown:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    characterDropdown:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    characterDropdown:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)
    characterDropdown:SetScript("OnClick", function(selfButton)
        self:OpenCharacterMenu(selfButton)
    end)
    self.characterDropdown = characterDropdown

    local characterDropdownText = characterDropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    characterDropdownText:SetPoint("LEFT", characterDropdown, "LEFT", 8, 0)
    characterDropdownText:SetPoint("RIGHT", characterDropdown, "RIGHT", -24, 0)
    characterDropdownText:SetJustifyH("LEFT")
    characterDropdownText:SetJustifyV("MIDDLE")
    characterDropdownText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(characterDropdownText, 12, "")
    self.characterDropdownText = characterDropdownText

    local characterDropdownArrow = characterDropdown:CreateTexture(nil, "ARTWORK")
    characterDropdownArrow:SetPoint("RIGHT", characterDropdown, "RIGHT", -8, 0)
    characterDropdownArrow:SetSize(10, 10)
    characterDropdownArrow:SetTexture(DROPDOWN_ARROW_TEXTURE)
    characterDropdownArrow:SetVertexColor(1, 1, 1, 0.98)
    self.characterDropdownArrow = characterDropdownArrow

    local openLiveButton = CreateFrame("Button", nil, navFrame, "BackdropTemplate")
    openLiveButton:SetPoint("RIGHT", navFrame, "RIGHT", 0, 0)
    openLiveButton:SetSize(LIVE_BUTTON_WIDTH, HEADER_ACTION_BUTTON_HEIGHT)
    openLiveButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    openLiveButton:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    openLiveButton:SetBackdropBorderColor(1, 1, 1, 0.12)
    openLiveButton:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    openLiveButton:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    openLiveButton:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    openLiveButton:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)
    openLiveButton:SetScript("OnClick", function()
        self:OpenLiveVault()
    end)
    openLiveButton:SetScript("OnEnter", function(selfButton)
        self:ConfigureOpenLiveButtonTooltip(selfButton)
    end)
    openLiveButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.openLiveButton = openLiveButton

    local openLiveButtonText = openLiveButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    openLiveButtonText:SetPoint("CENTER", 0, 0)
    openLiveButtonText:SetText(L["VAULT_OPEN_LIVE"])
    vesperTools:ApplyConfiguredFont(openLiveButtonText, 11, "")
    self.openLiveButtonText = openLiveButtonText

    local captureText = navFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    captureText:SetPoint("LEFT", characterDropdown, "RIGHT", 10, 0)
    captureText:SetPoint("RIGHT", openLiveButton, "LEFT", -10, 0)
    captureText:SetJustifyH("LEFT")
    captureText:SetJustifyV("MIDDLE")
    captureText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(captureText, 11, "")
    self.captureText = captureText

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", navFrame, "BOTTOMLEFT", 0, -16)
    content:SetPoint("TOPRIGHT", navFrame, "BOTTOMRIGHT", 0, -16)
    content:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", WINDOW_CONTENT_PADDING, WINDOW_CONTENT_PADDING)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -WINDOW_CONTENT_PADDING, WINDOW_CONTENT_PADDING)
    self.content = content

    local scrollContent = CreateFrame("Frame", nil, content)
    scrollContent:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    scrollContent:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    scrollContent:SetHeight(1)
    self.scrollFrame = nil
    self.scrollContent = scrollContent

    local emptyText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("TOPLEFT", 0, 0)
    emptyText:SetPoint("TOPRIGHT", 0, 0)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetJustifyV("TOP")
    emptyText:SetWordWrap(true)
    emptyText:SetText(L["VAULT_EMPTY"])
    vesperTools:ApplyConfiguredFont(emptyText, 12, "")
    emptyText:Hide()
    self.emptyText = emptyText

    self.frame = frame
    frame:SetScript("OnHide", function()
        self:HideCharacterMenu()
    end)
end

function VaultWindow:AcquireSectionFrame()
    local index = #self.sectionFrames + 1
    local section = CreateFrame("Frame", nil, self.scrollContent or self.content)
    section.rows = {}

    local title = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetJustifyH("LEFT")
    title:SetJustifyV("TOP")
    vesperTools:ApplyConfiguredFont(title, 13, "")
    section.title = title

    local divider = section:CreateTexture(nil, "BACKGROUND")
    divider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, -18)
    divider:SetHeight(1)
    divider:SetColorTexture(1, 1, 1, 0.10)
    section.divider = divider

    self.sectionFrames[index] = section
    return section
end

function VaultWindow:AcquireActivityRow(section)
    local rows = section.rows or {}
    local index = #rows + 1
    local row = CreateFrame("Button", nil, section, "BackdropTemplate")
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    row:SetBackdropColor(0.08, 0.08, 0.1, 0.82)
    row:SetBackdropBorderColor(1, 1, 1, 0.08)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    row:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.12)

    local iconBackground = row:CreateTexture(nil, "BACKGROUND")
    iconBackground:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -7)
    iconBackground:SetSize(28, 28)
    iconBackground:SetColorTexture(0, 0, 0, 0.85)
    row.iconBackground = iconBackground

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconBackground, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", iconBackground, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(FALLBACK_ICON_TEXTURE)
    row.icon = icon

    local titleText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    titleText:SetPoint("TOPLEFT", iconBackground, "TOPRIGHT", 10, 0)
    titleText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -7)
    titleText:SetJustifyH("LEFT")
    titleText:SetJustifyV("TOP")
    titleText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(titleText, 12, "")
    row.titleText = titleText

    local detailText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detailText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -7)
    detailText:SetJustifyH("RIGHT")
    detailText:SetJustifyV("TOP")
    detailText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(detailText, 11, "")
    row.detailText = detailText

    titleText:ClearAllPoints()
    titleText:SetPoint("TOPLEFT", iconBackground, "TOPRIGHT", 10, 0)
    titleText:SetPoint("TOPRIGHT", detailText, "TOPLEFT", -8, 0)

    local itemText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    itemText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -3)
    itemText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -24)
    itemText:SetJustifyH("LEFT")
    itemText:SetJustifyV("TOP")
    itemText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(itemText, 11, "")
    row.itemText = itemText

    row:SetScript("OnEnter", function(selfRow)
        GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
        if selfRow.tooltipLink then
            GameTooltip:SetHyperlink(selfRow.tooltipLink)
        else
            GameTooltip:SetText(selfRow.tooltipTitle or L["GREAT_VAULT"], 1, 1, 1)
            if type(selfRow.tooltipLines) == "table" and #selfRow.tooltipLines > 0 then
                for index = 1, #selfRow.tooltipLines do
                    GameTooltip:AddLine(selfRow.tooltipLines[index], 0.85, 0.85, 0.85, true)
                end
            elseif selfRow.tooltipText then
                GameTooltip:AddLine(selfRow.tooltipText, 0.85, 0.85, 0.85, true)
            end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    rows[index] = row
    section.rows = rows
    return row
end

function VaultWindow:RefreshActivityRow(row, rewardType, activity, contentWidth)
    local actualLink = getActualRewardLink(activity)
    local previewLink = getRewardDisplayLink(activity)
    local displayName = getDisplayItemName(actualLink)
    local previewInfo = getComputedPreviewInfo(rewardType, activity)
    local actualTrackName, actualTrackText = getActualRewardTrackInfo(activity)
    local trackName = actualTrackName or previewInfo.trackName
    local trackText = actualTrackText or previewInfo.trackText
    local formattedTrackLabel = formatTrackLabel(trackName, trackText)
    local slotIndex = math.max(1, tonumber(activity and activity.index) or 1)
    local progress = math.max(0, tonumber(activity and activity.progress) or 0)
    local threshold = math.max(0, tonumber(activity and activity.threshold) or 0)
    local isLocked = threshold > 0 and progress < threshold
    local hasActualReward = actualLink ~= nil
    local itemLevel = (hasActualReward and getDetailedItemLevel(actualLink)) or previewInfo.itemLevel or getDetailedItemLevel(previewLink)
    local sourceLabel = previewInfo.sourceLabel
    local titleText = string.format(L["VAULT_SLOT_FMT"], slotIndex)

    local detailParts = {}
    if threshold > 0 then
        if not isLocked then
            detailParts[#detailParts + 1] = L["VAULT_READY"]
        else
            detailParts[#detailParts + 1] = string.format("%d/%d", progress, threshold)
        end
    end
    if formattedTrackLabel then
        detailParts[#detailParts + 1] = formattedTrackLabel
    end
    if itemLevel and itemLevel > 0 then
        detailParts[#detailParts + 1] = string.format(L["VAULT_ITEM_LEVEL_FMT"], itemLevel)
    end

    local baseItemText
    if hasActualReward and not isLocked then
        baseItemText = displayName or L["VAULT_NO_REWARD_INFO"]
    else
        baseItemText = L["VAULT_REWARD_PREVIEW"]
    end

    local itemText = sourceLabel and string.format("%s - %s", sourceLabel, baseItemText) or baseItemText

    row:SetSize(contentWidth, ROW_HEIGHT)
    if isLocked then
        row.icon:SetTexture(LOCKED_CHEST_TEXTURE)
    elseif hasActualReward then
        row.icon:SetTexture(getItemIconForLink(actualLink))
    else
        row.icon:SetTexture(PREVIEW_CHEST_TEXTURE)
    end
    row.icon:SetAlpha(isLocked and 0.92 or 1)
    row.icon:Show()
    row.iconBackground:Show()
    row:SetAlpha(isLocked and 0.58 or 1)
    row:SetBackdropColor(0.08, 0.08, 0.1, isLocked and 0.48 or 0.82)
    row:SetBackdropBorderColor(1, 1, 1, isLocked and 0.05 or 0.08)
    row.titleText:SetText(titleText)
    row.titleText:SetTextColor(isLocked and 0.66 or 0.92, isLocked and 0.7 or 0.97, isLocked and 0.76 or 1, 1)
    row.detailText:SetText(table.concat(detailParts, " | "))
    row.detailText:SetTextColor(isLocked and 0.5 or 0.78, isLocked and 0.54 or 0.82, isLocked and 0.6 or 0.88, 1)
    row.itemText:SetText(itemText)
    row.itemText:SetTextColor(isLocked and 0.54 or (hasActualReward and 0.82 or 0.76), isLocked and 0.58 or (hasActualReward and 0.86 or 0.89), isLocked and 0.64 or (hasActualReward and 0.92 or 1), 1)
    row.tooltipLink = (hasActualReward and not isLocked) and actualLink or nil
    row.tooltipTitle = titleText
    row.tooltipLines = (hasActualReward and not isLocked) and nil or buildPreviewTooltipLines(rewardType, activity, itemLevel, trackText, sourceLabel, isLocked)
    row.tooltipText = nil
    row:Show()
end

function VaultWindow:RefreshSection(section, rewardType, activities, contentWidth)
    section.title:SetText(self:GetLaneTitle(rewardType))

    for index = 1, #activities do
        local row = section.rows[index] or self:AcquireActivityRow(section)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -(SECTION_HEADER_HEIGHT + ((index - 1) * (ROW_HEIGHT + ROW_GAP))))
        self:RefreshActivityRow(row, rewardType, activities[index], contentWidth)
    end

    for index = #activities + 1, #(section.rows or {}) do
        section.rows[index]:Hide()
    end

    local height = SECTION_HEADER_HEIGHT + (#activities * ROW_HEIGHT) + (math.max(0, #activities - 1) * ROW_GAP)
    section:SetSize(contentWidth, height)
    section:Show()
    return height
end

function VaultWindow:RefreshSections(snapshot)
    local contentWidth = math.max(1, math.floor((self.content and self.content:GetWidth() or 1) + 0.5))
    if contentWidth <= 1 and self.frame then
        contentWidth = math.max(1, math.floor((self.frame:GetWidth() or MIN_WINDOW_WIDTH) - (WINDOW_CONTENT_PADDING * 2) - NAV_LEFT_INSET - NAV_RIGHT_INSET + 0.5))
    end
    local shownCount = 0
    local previousSection = nil
    local totalHeight = 0

    for index = 1, #REWARD_TYPE_ORDER do
        local rewardType = REWARD_TYPE_ORDER[index]
        local activities = snapshot and snapshot.activities and snapshot.activities[rewardType] or nil
        if type(activities) == "table" and #activities > 0 then
            shownCount = shownCount + 1
            local section = self.sectionFrames[shownCount] or self:AcquireSectionFrame()
            section:ClearAllPoints()
            if previousSection then
                section:SetPoint("TOPLEFT", previousSection, "BOTTOMLEFT", 0, -SECTION_GAP)
                totalHeight = totalHeight + SECTION_GAP
            else
                section:SetPoint("TOPLEFT", self.scrollContent or self.content, "TOPLEFT", 0, 0)
            end
            local sectionHeight = self:RefreshSection(section, rewardType, activities, contentWidth)
            totalHeight = totalHeight + sectionHeight
            previousSection = section
        end
    end

    for index = shownCount + 1, #self.sectionFrames do
        self.sectionFrames[index]:Hide()
    end

    if self.scrollContent then
        self.scrollContent:SetHeight(math.max(totalHeight, self.content and self.content:GetHeight() or 1))
    end

    return shownCount
end

function VaultWindow:RefreshWindow()
    if not self.frame then
        return
    end

    local store = self:GetStore()
    if store and type(store.CreateOrUpdateCurrentCharacter) == "function" then
        store:CreateOrUpdateCurrentCharacter()
    end

    local bagsProfile = vesperTools:GetBagsProfile()
    if self.frame then
        self.frame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("portals"))
    end

    local selectedCharacter = self:ResolveSelectedCharacter()
    local snapshot = selectedCharacter and store and type(store.GetCharacterVaultSnapshot) == "function"
        and store:GetCharacterVaultSnapshot(selectedCharacter.key)
        or nil

    self.currentDisplayCharacter = selectedCharacter
    self.currentSnapshot = snapshot

    if self.characterDropdownText then
        self.characterDropdownText:SetText(selectedCharacter and selectedCharacter.fullName or vesperTools:GetCurrentCharacterFullName())
    end

    if self.modeText then
        if snapshot then
            self.modeText:SetText(selectedCharacter and selectedCharacter.isCurrent and L["BAGS_LIVE"] or L["BAGS_READ_ONLY"])
        else
            self.modeText:SetText("")
        end
    end

    if self.captureText then
        local capturedAtText = snapshot and formatCapturedTimestamp(snapshot.capturedAt) or nil
        self.captureText:SetText(capturedAtText and string.format(L["VAULT_STATUS_CAPTURED_FMT"], capturedAtText) or "")
    end

    if self.openLiveButton then
        self:SetOpenLiveButtonEnabled(selectedCharacter and selectedCharacter.isCurrent and true or false)
    end

    self:UpdateCharacterDropdownVisual()
    self:HideCharacterMenu()

    local hasSections = self:RefreshSections(snapshot)
    if hasSections and hasSections > 0 then
        self.emptyText:Hide()
    else
        self.emptyText:SetText(L["VAULT_EMPTY"])
        self.emptyText:Show()
    end
end
