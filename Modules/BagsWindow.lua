local VesperGuild = VesperGuild or LibStub("AceAddon-3.0"):GetAddon("VesperGuild")
local BagsWindow = VesperGuild:NewModule("BagsWindow", "AceEvent-3.0")
local L = VesperGuild.L
local ITEM_CLASS = Enum and Enum.ItemClass or {}

local MIN_WINDOW_WIDTH = 480
local MIN_WINDOW_HEIGHT = 220
local DEFAULT_BUTTON_SIZE = 38
local BUTTON_GAP = 6
local SECTION_GAP = 18
local HEADER_HEIGHT = 28
local SUMMARY_GAP = 14
local CONTENT_SIDE_PADDING = 8
local WINDOW_SCREEN_MARGIN = 48
local WINDOW_CHROME_HEIGHT = 96
local CHARACTER_DROPDOWN_WIDTH = 220
local CHARACTER_DROPDOWN_HEIGHT = 22
local CHARACTER_MENU_ROW_HEIGHT = 24
local CHARACTER_MENU_PADDING = 4
local CHARACTER_MENU_GAP = 4
local HEADER_ACTION_BUTTON_HEIGHT = 22
local BAG_SLOTS_BUTTON_WIDTH = 52
local CLEANUP_BUTTON_WIDTH = 70
local COMBINE_BUTTON_WIDTH = 76
local HEADER_ACTION_BUTTON_GAP = 6
local TITLEBAR_SEARCH_WIDTH = 220
local TITLEBAR_SEARCH_HEIGHT = 22
local TITLEBAR_SEARCH_CLEAR_BUTTON_SIZE = 14
local CHARACTER_DROPDOWN_ARROW_TEXTURE = "Interface\\AddOns\\VesperGuild\\Media\\DropdownArrow-50"
local EQUIPPED_BAG_IDS = {}
local REAGENT_BAG_ID = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or nil

if Enum and Enum.BagIndex then
    EQUIPPED_BAG_IDS = {
        Enum.BagIndex.Bag_1,
        Enum.BagIndex.Bag_2,
        Enum.BagIndex.Bag_3,
        Enum.BagIndex.Bag_4,
        Enum.BagIndex.ReagentBag,
    }
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function safeColorForQuality(quality)
    if quality == nil then
        return 0.18, 0.18, 0.18
    end

    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r or 0.18, color.g or 0.18, color.b or 0.18
    end

    return 0.18, 0.18, 0.18
end

local function buildFallbackItemName(itemID)
    return string.format(L["ITEM_FALLBACK_FMT"], tostring(itemID))
end

local function normalizeSearchText(text)
    if type(text) ~= "string" then
        return nil
    end

    local normalized = text
    normalized = normalized:gsub("|c%x%x%x%x%x%x%x%x", "")
    normalized = normalized:gsub("|r", "")
    normalized = normalized:gsub("|T.-|t", " ")
    normalized = normalized:gsub("|A.-|a", " ")
    normalized = normalized:gsub("[%z\1-\31]", " ")
    normalized = normalized:gsub("%s+", " ")
    normalized = strtrim(normalized)
    if normalized == "" then
        return nil
    end

    return string.lower(normalized)
end

local function getNewItemGlowAtlas(quality)
    if type(NEW_ITEM_ATLAS_BY_QUALITY) == "table" and quality and NEW_ITEM_ATLAS_BY_QUALITY[quality] then
        return NEW_ITEM_ATLAS_BY_QUALITY[quality]
    end
    return "bags-glow-white"
end

function BagsWindow:OnInitialize()
    self.frame = nil
    self.titleText = nil
    self.modeText = nil
    self.searchBox = nil
    self.searchClearButton = nil
    self.searchPlaceholder = nil
    self.searchQuery = nil
    self.characterDropdown = nil
    self.characterDropdownText = nil
    self.characterDropdownArrow = nil
    self.characterMenu = nil
    self.characterMenuDismiss = nil
    self.characterMenuButtons = {}
    self.bagSlotsMenu = nil
    self.bagSlotsMenuButtons = {}
    self.bagSlotsButton = nil
    self.bagSlotsButtonText = nil
    self.cleanupButton = nil
    self.cleanupButtonText = nil
    self.combineStacksButton = nil
    self.combineStacksButtonText = nil
    self.combineStacksButtonGlow = nil
    self.content = nil
    self.emptyText = nil
    self.sectionFrames = {}
    self.itemButtons = {}
    self.equippedBagButtons = {}
    self.summaryButtons = {}
    self.selectedCharacterKey = nil
    self.displayCharacters = {}
    self.currentDisplayCharacter = nil
    self.currentSnapshot = nil
    self.newItemGlowKeysSeen = {}
end

function BagsWindow:OnEnable()
    self:RegisterMessage("VESPERGUILD_BAGS_SNAPSHOT_UPDATED", "OnBagDataChanged")
    self:RegisterMessage("VESPERGUILD_BAGS_CHARACTER_UPDATED", "OnBagDataChanged")
    self:RegisterMessage("VESPERGUILD_BAGS_INDEX_UPDATED", "OnBagDataChanged")
    self:RegisterMessage("VESPERGUILD_CONFIG_CHANGED", "OnConfigChanged")
end

function BagsWindow:GetStore()
    return VesperGuild:GetModule("BagsStore", true)
end

function BagsWindow:OnBagDataChanged()
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function BagsWindow:OnConfigChanged()
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function BagsWindow:CleanupLegacyScrollArtifacts()
    if self.scrollFrame then
        self.scrollFrame:Hide()
        self.scrollFrame:SetParent(nil)
        self.scrollFrame = nil
    end

    if self.scrollBar then
        self.scrollBar:Hide()
        self.scrollBar:SetParent(nil)
        self.scrollBar = nil
    end

    local legacyFrame = _G["VesperGuildBagsWindowScrollFrame"]
    if legacyFrame then
        legacyFrame:Hide()
        legacyFrame:SetParent(nil)
    end

    local legacyBar = _G["VesperGuildBagsWindowScrollFrameScrollBar"] or _G["VesperGuildBagsWindowScrollBar"]
    if legacyBar then
        legacyBar:Hide()
        legacyBar:SetParent(nil)
    end
end

function BagsWindow:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
        return
    end

    self:ShowWindow()
end

function BagsWindow:ShowWindow()
    if not self.frame then
        self:CreateWindow()
    end

    self:CleanupLegacyScrollArtifacts()
    self:SelectCurrentCharacterForOpen()
    self:RefreshWindow()
    self.frame:Show()
    self.frame:Raise()
end

function BagsWindow:SelectCurrentCharacterForOpen()
    local store = self:GetStore()
    if not store then
        return
    end

    if store.CreateOrUpdateCurrentCharacter then
        store:CreateOrUpdateCurrentCharacter()
    end

    local currentCharacterKey = store.GetCurrentCharacterKey and store:GetCurrentCharacterKey() or nil
    if type(currentCharacterKey) ~= "string" or currentCharacterKey == "" then
        return
    end

    self.selectedCharacterKey = currentCharacterKey

    local bagsProfile = VesperGuild:GetBagsProfile()
    if bagsProfile then
        bagsProfile.lastViewedCharacterGUID = currentCharacterKey
    end
end

function BagsWindow:ResolveSelectedCharacter()
    local store = self:GetStore()
    if not store then
        self.displayCharacters = {}
        self.selectedCharacterKey = nil
        return nil
    end

    self.displayCharacters = store:GetDisplayCharacters()

    if #self.displayCharacters == 0 then
        self.selectedCharacterKey = nil
        return nil
    end

    local bagsProfile = VesperGuild:GetBagsProfile()
    local selectedKey = self.selectedCharacterKey or (bagsProfile and bagsProfile.lastViewedCharacterGUID) or nil
    for i = 1, #self.displayCharacters do
        if self.displayCharacters[i].key == selectedKey then
            self.selectedCharacterKey = selectedKey
            return self.displayCharacters[i]
        end
    end

    self.selectedCharacterKey = self.displayCharacters[1].key
    if bagsProfile then
        bagsProfile.lastViewedCharacterGUID = self.selectedCharacterKey
    end
    return self.displayCharacters[1]
end

function BagsWindow:SetCharacterDropdownEnabled(isEnabled)
    if not self.characterDropdown then
        return
    end

    if isEnabled then
        self.characterDropdown:Enable()
        self.characterDropdown:SetAlpha(1)
    else
        self.characterDropdown:Disable()
        self.characterDropdown:SetAlpha(0.5)
    end
end

function BagsWindow:UpdateCharacterDropdownVisual()
    if not self.characterDropdown then
        return
    end

    local isOpen = self.characterMenu and self.characterMenu:IsShown()
    local backdropAlpha = isOpen and 0.98 or 0.92
    self.characterDropdown:SetBackdropColor(0.08, 0.08, 0.1, backdropAlpha)
    if self.characterDropdownArrow then
        self.characterDropdownArrow:SetTexture(CHARACTER_DROPDOWN_ARROW_TEXTURE)
        self.characterDropdownArrow:SetRotation(isOpen and math.pi or 0)
    end
end

function BagsWindow:SetSelectedCharacter(characterKey)
    if type(characterKey) ~= "string" or characterKey == "" then
        return
    end

    self:HideBagSlotsMenu()
    self.selectedCharacterKey = characterKey
    local bagsProfile = VesperGuild:GetBagsProfile()
    if bagsProfile then
        bagsProfile.lastViewedCharacterGUID = characterKey
    end
    self:RefreshWindow()
end

function BagsWindow:HideCharacterMenu()
    if self.characterMenu then
        self.characterMenu:Hide()
    end

    if self.characterMenuDismiss then
        self.characterMenuDismiss:Hide()
    end

    self:UpdateCharacterDropdownVisual()
end

function BagsWindow:HideBagSlotsMenu()
    if self.bagSlotsMenu then
        self.bagSlotsMenu:Hide()
    end

    self:UpdateBagSlotsButtonVisual(false)
end

function BagsWindow:GetCharacterMenuFrames()
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

function BagsWindow:GetBagSlotsMenuFrames()
    if not self.bagSlotsMenu then
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
        self.bagSlotsMenu = menu
    end

    local baseLevel = math.max(90, (self.frame and self.frame:GetFrameLevel() or 0) + 20)
    self.bagSlotsMenu:SetFrameLevel(baseLevel)

    return self.bagSlotsMenu
end

function BagsWindow:AcquireCharacterMenuButton(menu)
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
    VesperGuild:ApplyConfiguredFont(text, 12, "")
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

function BagsWindow:RefreshCharacterMenu()
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

function BagsWindow:OpenCharacterMenu(button)
    if not button or #self.displayCharacters == 0 then
        return
    end

    local menu, dismiss = self:GetCharacterMenuFrames()
    if menu:IsShown() then
        self:HideCharacterMenu()
        return
    end

    self:HideBagSlotsMenu()
    self:RefreshCharacterMenu()

    dismiss:Show()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -CHARACTER_MENU_GAP)
    menu:Show()
    menu:Raise()
    self:UpdateCharacterDropdownVisual()
end

function BagsWindow:AcquireBagSlotsMenuButton(menu)
    local index = #self.bagSlotsMenuButtons + 1
    local button = CreateFrame("Button", nil, menu, "BackdropTemplate")
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    VesperGuild:ApplyConfiguredFont(count, 11, "OUTLINE")
    button.count = count

    self.bagSlotsMenuButtons[index] = button
    return button
end

function BagsWindow:RefreshBagSlotsMenu(selectedCharacter, snapshot, viewSettings)
    local menu = self.bagSlotsMenu
    if not menu then
        return false
    end

    selectedCharacter = selectedCharacter or self:ResolveSelectedCharacter()
    if not selectedCharacter then
        return false
    end

    local store = self:GetStore()
    snapshot = snapshot or (store and store.GetCharacterBagSnapshot and store:GetCharacterBagSnapshot(selectedCharacter.key) or nil)
    if not snapshot then
        return false
    end

    viewSettings = viewSettings or self:GetViewSettings()
    local entries = self:GetEquippedBagSlotEntries(selectedCharacter, snapshot)
    if #entries == 0 then
        return false
    end

    local padding = 4
    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local buttonGap = viewSettings and viewSettings.buttonGap or BUTTON_GAP

    for i = 1, #entries do
        local button = self.bagSlotsMenuButtons[i] or self:AcquireBagSlotsMenuButton(menu)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", padding + ((i - 1) * (itemIconSize + buttonGap)), -padding)
        self:ConfigureEquippedBagButton(button, entries[i], viewSettings)
    end

    for i = #entries + 1, #self.bagSlotsMenuButtons do
        self.bagSlotsMenuButtons[i]:Hide()
    end

    menu:SetSize((padding * 2) + (#entries * itemIconSize) + (math.max(0, #entries - 1) * buttonGap), (padding * 2) + itemIconSize)
    return true
end

function BagsWindow:OpenBagSlotsMenu(button)
    if not button then
        return
    end

    local menu = self:GetBagSlotsMenuFrames()
    if menu:IsShown() then
        self:HideBagSlotsMenu()
        return
    end

    self:HideCharacterMenu()

    local selectedCharacter = self:ResolveSelectedCharacter()
    if not selectedCharacter then
        return
    end

    local store = self:GetStore()
    local snapshot = store and store.GetCharacterBagSnapshot and store:GetCharacterBagSnapshot(selectedCharacter.key) or nil
    if not self:RefreshBagSlotsMenu(selectedCharacter, snapshot) then
        return
    end

    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -CHARACTER_MENU_GAP)
    menu:Show()
    menu:Raise()
    self:UpdateBagSlotsButtonVisual(true)
end

function BagsWindow:SaveWindowState()
    if not self.frame then
        return
    end

    local bagsProfile = VesperGuild:GetBagsProfile()
    if not bagsProfile then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = self.frame:GetPoint()
    bagsProfile.window.point = point
    bagsProfile.window.relativePoint = relativePoint
    bagsProfile.window.xOfs = xOfs
    bagsProfile.window.yOfs = yOfs
    bagsProfile.window.width = math.floor((self.frame:GetWidth() or MIN_WINDOW_WIDTH) + 0.5)
    bagsProfile.window.height = math.floor((self.frame:GetHeight() or MIN_WINDOW_HEIGHT) + 0.5)
end

function BagsWindow:GetCollapsedCategoryTable(characterKey, create)
    local bagsProfile = VesperGuild:GetBagsProfile()
    if not bagsProfile or type(characterKey) ~= "string" or characterKey == "" then
        return nil
    end

    bagsProfile.collapsedCategories = bagsProfile.collapsedCategories or {}
    if create and type(bagsProfile.collapsedCategories[characterKey]) ~= "table" then
        bagsProfile.collapsedCategories[characterKey] = {}
    end

    return bagsProfile.collapsedCategories[characterKey]
end

function BagsWindow:IsCategoryCollapsed(characterKey, categoryKey)
    local collapsed = self:GetCollapsedCategoryTable(characterKey, false)
    return collapsed and collapsed[categoryKey] and true or false
end

function BagsWindow:SetCategoryCollapsed(characterKey, categoryKey, isCollapsed)
    if type(characterKey) ~= "string" or characterKey == "" or type(categoryKey) ~= "string" or categoryKey == "" then
        return
    end

    local collapsed = self:GetCollapsedCategoryTable(characterKey, isCollapsed)
    if not collapsed then
        return
    end

    if isCollapsed then
        collapsed[categoryKey] = true
        return
    end

    collapsed[categoryKey] = nil
    if next(collapsed) then
        return
    end

    local bagsProfile = VesperGuild:GetBagsProfile()
    if bagsProfile and bagsProfile.collapsedCategories then
        bagsProfile.collapsedCategories[characterKey] = nil
    end
end

function BagsWindow:ToggleCategoryCollapsed(characterKey, categoryKey)
    self:SetCategoryCollapsed(characterKey, categoryKey, not self:IsCategoryCollapsed(characterKey, categoryKey))
    self:RefreshWindow()
end

function BagsWindow:GetViewSettings()
    local bagsProfile = VesperGuild:GetBagsProfile()
    local display = bagsProfile and bagsProfile.display or nil
    local itemIconSize = math.max(24, math.min(56, math.floor((display and tonumber(display.itemIconSize) or DEFAULT_BUTTON_SIZE) + 0.5)))
    local columns = math.max(1, math.min(20, math.floor((display and tonumber(display.columns) or 10) + 0.5)))
    local stackCountFontSize = math.max(8, math.min(20, math.floor((display and tonumber(display.stackCountFontSize) or 11) + 0.5)))
    local itemLevelFontSize = math.max(8, math.min(18, math.floor((display and tonumber(display.itemLevelFontSize) or 9) + 0.5)))
    local qualityGlowIntensity = math.max(0, math.min(1, display and tonumber(display.qualityGlowIntensity) or 0.65))

    return {
        columns = columns,
        itemIconSize = itemIconSize,
        stackCountFontSize = stackCountFontSize,
        itemLevelFontSize = itemLevelFontSize,
        buttonGap = BUTTON_GAP,
        showItemLevel = display and display.showItemLevel and true or false,
        qualityGlowIntensity = qualityGlowIntensity,
        combineStacks = display and display.combineStacks and true or false,
    }
end

function BagsWindow:ToggleBagSlots()
    if not self.bagSlotsButton then
        return
    end

    self:OpenBagSlotsMenu(self.bagSlotsButton)
end

function BagsWindow:ToggleCombineStacks()
    local bagsProfile = VesperGuild:GetBagsProfile()
    if not bagsProfile then
        return
    end

    bagsProfile.display = bagsProfile.display or {}
    bagsProfile.display.combineStacks = not (bagsProfile.display.combineStacks and true or false)
    self:RefreshWindow()
end

function BagsWindow:UpdateCombineStacksButtonVisual(isActive)
    if not self.combineStacksButton then
        return
    end

    local active = isActive and true or false
    self.combineStacksButton:SetBackdropColor(0.08, 0.08, 0.1, active and 0.98 or 0.92)
    self.combineStacksButton:SetBackdropBorderColor(active and 0.55 or 1, active and 0.84 or 1, active and 1 or 1, active and 0.42 or 0.12)
    if self.combineStacksButtonText then
        self.combineStacksButtonText:SetTextColor(active and 0.94 or 0.86, active and 0.98 or 0.9, active and 1 or 0.94, 1)
    end
    if self.combineStacksButtonGlow then
        if active then
            self.combineStacksButtonGlow:Show()
            self.combineStacksButtonGlow:SetAlpha(0.16)
        else
            self.combineStacksButtonGlow:SetAlpha(0)
            self.combineStacksButtonGlow:Hide()
        end
    end
end

function BagsWindow:UpdateBagSlotsButtonVisual(isActive)
    if not self.bagSlotsButton then
        return
    end

    local active = isActive and true or false
    self.bagSlotsButton:SetBackdropColor(0.08, 0.08, 0.1, active and 0.98 or 0.92)
    self.bagSlotsButton:SetBackdropBorderColor(active and 0.55 or 1, active and 0.84 or 1, active and 1 or 1, active and 0.42 or 0.12)
    if self.bagSlotsButtonText then
        self.bagSlotsButtonText:SetTextColor(active and 0.94 or 0.86, active and 0.98 or 0.9, active and 1 or 0.94, 1)
    end
end

function BagsWindow:UpdateCleanupButtonVisual(isEnabled)
    if not self.cleanupButton then
        return
    end

    local enabled = isEnabled and true or false
    self.cleanupButton:SetEnabled(enabled)
    self.cleanupButton:SetAlpha(enabled and 1 or 0.45)
    self.cleanupButton:SetBackdropColor(0.08, 0.08, 0.1, enabled and 0.92 or 0.84)
    self.cleanupButton:SetBackdropBorderColor(1, 1, 1, enabled and 0.12 or 0.06)
    if self.cleanupButtonText then
        self.cleanupButtonText:SetTextColor(enabled and 0.9 or 0.62, enabled and 0.94 or 0.62, enabled and 1 or 0.62, 1)
    end
end

function BagsWindow:ConfigureBagSlotsButtonTooltip(button, isActive)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["BAGS_BAG_SLOTS"], 1, 1, 1)
    GameTooltip:AddLine(isActive and L["BAGS_BAG_SLOTS_ON"] or L["BAGS_BAG_SLOTS_OFF"], 0.85, 0.85, 0.85)
    GameTooltip:Show()
end

function BagsWindow:ConfigureCombineStacksButtonTooltip(button, isActive)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["BAGS_COMBINE_STACKS"], 1, 1, 1)
    GameTooltip:AddLine(isActive and L["BAGS_COMBINE_STACKS_ON"] or L["BAGS_COMBINE_STACKS_OFF"], 0.85, 0.85, 0.85)
    GameTooltip:Show()
end

function BagsWindow:ConfigureCleanupButtonTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["BAGS_CLEAR_NEW_ITEMS"], 1, 1, 1)
    GameTooltip:AddLine(L["BAGS_CLEAR_NEW_ITEMS_HINT"], 0.85, 0.85, 0.85, true)
    GameTooltip:Show()
end

function BagsWindow:CanClearNewItemsForSelectedCharacter()
    if not (C_NewItems and (C_NewItems.RemoveNewItem or C_NewItems.ClearAll)) then
        return false
    end

    local store = self:GetStore()
    if not store or not store.GetCurrentCharacterKey then
        return false
    end

    local currentCharacterKey = store:GetCurrentCharacterKey()
    return type(currentCharacterKey) == "string"
        and currentCharacterKey ~= ""
        and currentCharacterKey == self.selectedCharacterKey
end

function BagsWindow:ClearNewItemMarkers()
    if not self:CanClearNewItemsForSelectedCharacter() then
        return
    end

    local store = self:GetStore()
    local removeNewItem = C_NewItems and C_NewItems.RemoveNewItem or nil
    local usedFallback = true

    if removeNewItem and store and store.GetTrackedBagIDs and C_Container and C_Container.GetContainerNumSlots then
        usedFallback = false
        local trackedBagIDs = store:GetTrackedBagIDs()
        for i = 1, #trackedBagIDs do
            local bagID = trackedBagIDs[i]
            local slotCount = tonumber(C_Container.GetContainerNumSlots(bagID)) or 0
            for slotID = 1, slotCount do
                local shouldRemove = true
                if C_NewItems.IsNewItem then
                    local ok, isNewItem = pcall(C_NewItems.IsNewItem, bagID, slotID)
                    shouldRemove = ok and isNewItem and true or false
                end

                if shouldRemove then
                    pcall(removeNewItem, bagID, slotID)
                end
            end
        end
    end

    if usedFallback and C_NewItems and C_NewItems.ClearAll then
        pcall(C_NewItems.ClearAll)
    end

    wipe(self.newItemGlowKeysSeen)
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function BagsWindow:GetCombineRecordKey(record)
    if type(record) ~= "table" then
        return nil
    end

    if type(record.hyperlink) == "string" and record.hyperlink ~= "" then
        return record.hyperlink
    end

    if record.itemID then
        return string.format("item:%s", tostring(record.itemID))
    end

    return record.sortKey or record.itemName or UNKNOWN
end

function BagsWindow:UpdateSearchPlaceholder()
    if not self.searchBox or not self.searchPlaceholder then
        return
    end

    local text = self.searchBox:GetText()
    local hasText = type(text) == "string" and text ~= ""
    if hasText or self.searchBox:HasFocus() then
        self.searchPlaceholder:Hide()
    else
        self.searchPlaceholder:Show()
    end

    self:UpdateSearchClearButton(hasText)
end

function BagsWindow:UpdateSearchClearButton(hasText)
    if not self.searchClearButton then
        return
    end

    local enabled = hasText and true or false
    self.searchClearButton:SetEnabled(enabled)
    self.searchClearButton:SetAlpha(enabled and 1 or 0.42)
end

function BagsWindow:SetSearchQuery(text)
    self.searchQuery = normalizeSearchText(text)
    self:UpdateSearchPlaceholder()
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function BagsWindow:ClearSearch()
    local hadQuery = self.searchQuery ~= nil
    self.searchQuery = nil
    if self.searchBox and self.searchBox:GetText() ~= "" then
        self.searchBox:SetText("")
    else
        self:UpdateSearchPlaceholder()
    end
    if hadQuery and self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function BagsWindow:GetSearchTokens()
    if not self.searchQuery then
        return nil
    end

    local tokens = {}
    for token in self.searchQuery:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end

    return #tokens > 0 and tokens or nil
end

function BagsWindow:RecordMatchesSearch(record, searchTokens)
    if not searchTokens or #searchTokens == 0 then
        return true
    end

    local haystack = record and record.searchText
    if not haystack then
        haystack = normalizeSearchText(table.concat({
            record and record.itemName or "",
            record and record.itemDescription or "",
        }, " "))
    end

    if not haystack then
        return false
    end

    for i = 1, #searchTokens do
        if not string.find(haystack, searchTokens[i], 1, true) then
            return false
        end
    end

    return true
end

function BagsWindow:ApplySearchDimState(button, record, searchTokens)
    local matchesSearch = self:RecordMatchesSearch(record, searchTokens)
    button.searchMatched = matchesSearch
    button.icon:SetDesaturated((record.isLocked or not matchesSearch) and true or false)
    button:SetAlpha(matchesSearch and 1 or 0.24)
end

function BagsWindow:BuildDisplayItems(items, viewSettings)
    if not viewSettings or not viewSettings.combineStacks then
        return items
    end

    local displayItems = {}
    local groupedByKey = {}

    for i = 1, #items do
        local record = items[i]
        local key = self:GetCombineRecordKey(record)
        local count = math.max(1, tonumber(record and record.stackCount) or 1)
        local entry = groupedByKey[key]

        if not entry then
            entry = {}
            for fieldKey, fieldValue in pairs(record) do
                entry[fieldKey] = fieldValue
            end
            entry.stackCount = count
            entry.combinedStacks = 1
            entry.combinedRecords = { record }
            entry.isCombined = false
            groupedByKey[key] = entry
            displayItems[#displayItems + 1] = entry
        else
            entry.stackCount = (tonumber(entry.stackCount) or 0) + count
            entry.combinedStacks = (tonumber(entry.combinedStacks) or 1) + 1
            entry.isCombined = true
            entry.isLocked = entry.isLocked or record.isLocked
            entry.isQuestItem = entry.isQuestItem or record.isQuestItem
            entry.isCraftingReagent = entry.isCraftingReagent or record.isCraftingReagent
            if not entry.itemDescription and record.itemDescription then
                entry.itemDescription = record.itemDescription
            end
            if not entry.searchText and record.searchText then
                entry.searchText = record.searchText
            end
            entry.combinedRecords[#entry.combinedRecords + 1] = record
        end
    end

    return displayItems
end

function BagsWindow:CreateWindow()
    local bagsProfile = VesperGuild:GetBagsProfile()
    local width = bagsProfile and bagsProfile.window.width or 900
    local height = bagsProfile and bagsProfile.window.height or 560

    local frame = CreateFrame("Frame", "VesperGuildBagsWindow", UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    VesperGuild:ApplyAddonWindowLayer(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(false)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.07, 0.07, 0.07, 0.95)

    local _, englishClass = UnitClass("player")
    local classColor = C_ClassColor.GetClassColor(englishClass)
    frame:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)

    if bagsProfile and bagsProfile.window then
        frame:SetPoint(
            bagsProfile.window.point,
            UIParent,
            bagsProfile.window.relativePoint,
            bagsProfile.window.xOfs,
            bagsProfile.window.yOfs
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
    titleText:SetText(L["BAGS_TITLE"])
    VesperGuild:ApplyConfiguredFont(titleText, VesperGuild:GetConfiguredFontSize("roster", 12, 8, 24) + 4, "")
    self.titleText = titleText

    local modeText = titlebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modeText:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
    VesperGuild:ApplyConfiguredFont(modeText, 12, "")
    self.modeText = modeText

    local searchBox = CreateFrame("EditBox", nil, titlebar, "BackdropTemplate")
    searchBox:SetPoint("CENTER", titlebar, "CENTER", 0, 0)
    searchBox:SetSize(TITLEBAR_SEARCH_WIDTH, TITLEBAR_SEARCH_HEIGHT)
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(8, TITLEBAR_SEARCH_CLEAR_BUTTON_SIZE + 10, 0, 0)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    searchBox:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    searchBox:SetBackdropBorderColor(1, 1, 1, 0.12)
    VesperGuild:ApplyConfiguredFont(searchBox, 12, "")
    searchBox:SetScript("OnTextChanged", function(selfBox, userInput)
        self:UpdateSearchPlaceholder()
        if userInput then
            self:SetSearchQuery(selfBox:GetText())
        end
    end)
    searchBox:SetScript("OnEditFocusGained", function()
        self:UpdateSearchPlaceholder()
    end)
    searchBox:SetScript("OnEditFocusLost", function()
        self:UpdateSearchPlaceholder()
    end)
    searchBox:SetScript("OnEnterPressed", function(selfBox)
        selfBox:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(selfBox)
        self:ClearSearch()
        selfBox:ClearFocus()
    end)
    self.searchBox = searchBox

    local searchClearButton = VesperGuild:CreateModernCloseButton(searchBox, function()
        self:ClearSearch()
        searchBox:SetFocus()
    end, {
        size = TITLEBAR_SEARCH_CLEAR_BUTTON_SIZE,
        iconScale = 0.5,
        backgroundAlpha = 0,
        borderAlpha = 0,
        hoverAlpha = 0.08,
        pressedAlpha = 0.12,
        iconAlpha = 0.82,
        iconHoverAlpha = 1,
    })
    searchClearButton:SetPoint("RIGHT", searchBox, "RIGHT", -3, 0)
    self.searchClearButton = searchClearButton

    local searchPlaceholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    searchPlaceholder:SetPoint("RIGHT", searchClearButton, "LEFT", -4, 0)
    searchPlaceholder:SetJustifyH("LEFT")
    searchPlaceholder:SetJustifyV("MIDDLE")
    searchPlaceholder:SetWordWrap(false)
    searchPlaceholder:SetText(L["BAGS_SEARCH_PLACEHOLDER"])
    VesperGuild:ApplyConfiguredFont(searchPlaceholder, 12, "")
    self.searchPlaceholder = searchPlaceholder

    local closeButton = VesperGuild:CreateModernCloseButton(titlebar, function()
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
    navFrame:SetPoint("TOPLEFT", titlebar, "BOTTOMLEFT", 10, -8)
    navFrame:SetPoint("TOPRIGHT", titlebar, "BOTTOMRIGHT", -40, -8)

    local bagSlotsButton = CreateFrame("Button", nil, navFrame, "BackdropTemplate")
    bagSlotsButton:SetPoint("RIGHT", navFrame, "RIGHT", -(COMBINE_BUTTON_WIDTH + CLEANUP_BUTTON_WIDTH + (HEADER_ACTION_BUTTON_GAP * 2)), 0)
    bagSlotsButton:SetSize(BAG_SLOTS_BUTTON_WIDTH, HEADER_ACTION_BUTTON_HEIGHT)
    bagSlotsButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bagSlotsButton:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    bagSlotsButton:SetBackdropBorderColor(1, 1, 1, 0.12)
    bagSlotsButton:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    bagSlotsButton:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    bagSlotsButton:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    bagSlotsButton:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)
    bagSlotsButton:SetScript("OnClick", function(selfButton)
        self:OpenBagSlotsMenu(selfButton)
    end)
    bagSlotsButton:SetScript("OnEnter", function(selfButton)
        local isActive = self.bagSlotsMenu and self.bagSlotsMenu:IsShown() and true or false
        self:ConfigureBagSlotsButtonTooltip(selfButton, isActive)
    end)
    bagSlotsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.bagSlotsButton = bagSlotsButton

    local bagSlotsButtonText = bagSlotsButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bagSlotsButtonText:SetPoint("CENTER", 0, 0)
    bagSlotsButtonText:SetText(L["BAGS_BAG_SLOTS"])
    VesperGuild:ApplyConfiguredFont(bagSlotsButtonText, 11, "")
    self.bagSlotsButtonText = bagSlotsButtonText

    local cleanupButton = CreateFrame("Button", nil, navFrame, "BackdropTemplate")
    cleanupButton:SetPoint("RIGHT", navFrame, "RIGHT", -(COMBINE_BUTTON_WIDTH + HEADER_ACTION_BUTTON_GAP), 0)
    cleanupButton:SetSize(CLEANUP_BUTTON_WIDTH, HEADER_ACTION_BUTTON_HEIGHT)
    cleanupButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    cleanupButton:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    cleanupButton:SetBackdropBorderColor(1, 1, 1, 0.12)
    cleanupButton:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    cleanupButton:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    cleanupButton:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    cleanupButton:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)
    cleanupButton:SetScript("OnClick", function()
        self:ClearNewItemMarkers()
    end)
    cleanupButton:SetScript("OnEnter", function(selfButton)
        self:ConfigureCleanupButtonTooltip(selfButton)
    end)
    cleanupButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.cleanupButton = cleanupButton

    local cleanupButtonText = cleanupButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cleanupButtonText:SetPoint("CENTER", 0, 0)
    cleanupButtonText:SetText(L["BAGS_CLEAR_NEW_ITEMS"])
    VesperGuild:ApplyConfiguredFont(cleanupButtonText, 11, "")
    self.cleanupButtonText = cleanupButtonText

    local combineStacksButton = CreateFrame("Button", nil, navFrame, "BackdropTemplate")
    combineStacksButton:SetPoint("RIGHT", navFrame, "RIGHT", 0, 0)
    combineStacksButton:SetSize(COMBINE_BUTTON_WIDTH, HEADER_ACTION_BUTTON_HEIGHT)
    combineStacksButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    combineStacksButton:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    combineStacksButton:SetBackdropBorderColor(1, 1, 1, 0.12)
    combineStacksButton:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    combineStacksButton:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    combineStacksButton:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    combineStacksButton:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)
    combineStacksButton:SetScript("OnClick", function()
        self:ToggleCombineStacks()
    end)
    combineStacksButton:SetScript("OnEnter", function(selfButton)
        local bagsProfile = VesperGuild:GetBagsProfile()
        local isActive = bagsProfile and bagsProfile.display and bagsProfile.display.combineStacks and true or false
        self:ConfigureCombineStacksButtonTooltip(selfButton, isActive)
    end)
    combineStacksButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.combineStacksButton = combineStacksButton

    local combineStacksButtonGlow = combineStacksButton:CreateTexture(nil, "BACKGROUND")
    combineStacksButtonGlow:SetPoint("TOPLEFT", combineStacksButton, "TOPLEFT", 1, -1)
    combineStacksButtonGlow:SetPoint("BOTTOMRIGHT", combineStacksButton, "BOTTOMRIGHT", -1, 1)
    combineStacksButtonGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    combineStacksButtonGlow:SetVertexColor(0.36, 0.66, 1, 1)
    combineStacksButtonGlow:SetBlendMode("ADD")
    combineStacksButtonGlow:SetAlpha(0)
    combineStacksButtonGlow:Hide()
    self.combineStacksButtonGlow = combineStacksButtonGlow

    local combineStacksButtonText = combineStacksButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    combineStacksButtonText:SetPoint("CENTER", 0, 0)
    combineStacksButtonText:SetText(L["BAGS_COMBINE_BUTTON"])
    VesperGuild:ApplyConfiguredFont(combineStacksButtonText, 11, "")
    self.combineStacksButtonText = combineStacksButtonText

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
    VesperGuild:ApplyConfiguredFont(characterDropdownText, 12, "")
    self.characterDropdownText = characterDropdownText

    local characterDropdownArrow = characterDropdown:CreateTexture(nil, "ARTWORK")
    characterDropdownArrow:SetPoint("RIGHT", characterDropdown, "RIGHT", -8, 0)
    characterDropdownArrow:SetSize(10, 10)
    characterDropdownArrow:SetTexture(CHARACTER_DROPDOWN_ARROW_TEXTURE)
    characterDropdownArrow:SetVertexColor(1, 1, 1, 0.98)
    self.characterDropdownArrow = characterDropdownArrow

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", navFrame, "BOTTOMLEFT", 0, -10)
    content:SetSize(1, 1)
    self.content = content

    local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("TOPLEFT", 8, -8)
    emptyText:SetWidth(math.max(620, width - 60))
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText(L["BAGS_EMPTY"])
    VesperGuild:ApplyConfiguredFont(emptyText, 12, "")
    emptyText:Hide()
    self.emptyText = emptyText

    self.frame = frame
    frame:SetScript("OnHide", function()
        self:HideCharacterMenu()
        self:HideBagSlotsMenu()
        self:ClearSearch()
    end)
    self:UpdateSearchPlaceholder()
    self:CleanupLegacyScrollArtifacts()
end

function BagsWindow:BuildLayoutGroups(store, characterKey, categories, viewSettings)
    local groups = {}
    local maxItemCount = 0

    for i = 1, #categories do
        local category = categories[i]
        local items = store:GetCharacterCategoryItems(characterKey, category.key)
        if #items > 0 then
            local displayItems = self:BuildDisplayItems(items, viewSettings)
            local hidden = self:IsCategoryCollapsed(characterKey, category.key)
            if not hidden and #displayItems > maxItemCount then
                maxItemCount = #displayItems
            end
            groups[#groups + 1] = {
                category = category,
                items = displayItems,
                hidden = hidden,
            }
        end
    end

    return groups, maxItemCount
end

function BagsWindow:MeasureContentHeight(groups, columns, viewSettings, hasSummary)
    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local buttonGap = viewSettings and viewSettings.buttonGap or BUTTON_GAP
    local height = 8

    if hasSummary then
        height = height + itemIconSize + SUMMARY_GAP
    end

    if #groups == 0 then
        return height + 28
    end

    for i = 1, #groups do
        height = height + HEADER_HEIGHT
        if not groups[i].hidden then
            local itemCount = #groups[i].items
            local rows = math.max(1, math.ceil(itemCount / columns))
            height = height + (rows * itemIconSize)
            height = height + (math.max(0, rows - 1) * buttonGap)
        end
        height = height + SECTION_GAP
    end

    return height + 12
end

function BagsWindow:ResolveAutoLayout(groups, maxItemCount, viewSettings)
    local screenWidth = UIParent:GetWidth() or 1920
    local maxFrameWidth = math.max(MIN_WINDOW_WIDTH, math.floor(screenWidth - WINDOW_SCREEN_MARGIN))
    local maxContentWidth = math.max(MIN_WINDOW_WIDTH - 32, maxFrameWidth - 32)
    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local buttonGap = viewSettings and viewSettings.buttonGap or BUTTON_GAP
    local configuredColumns = viewSettings and viewSettings.columns or 10
    local maxColumns = math.max(1, math.floor((maxContentWidth - (CONTENT_SIDE_PADDING * 2) + buttonGap) / (itemIconSize + buttonGap)))
    local desiredColumns = maxItemCount > 0 and math.min(configuredColumns, maxItemCount) or 1
    local columns = clamp(desiredColumns, 1, maxColumns)

    local gridWidth = (CONTENT_SIDE_PADDING * 2) + (columns * itemIconSize) + (math.max(0, columns - 1) * buttonGap)
    local summaryWidth = (CONTENT_SIDE_PADDING * 2) + (itemIconSize * 2) + buttonGap
    local contentWidth = math.max(gridWidth, summaryWidth)
    local contentHeight = self:MeasureContentHeight(groups, columns, viewSettings, true)
    local desiredWidth = math.max(MIN_WINDOW_WIDTH, contentWidth + 20)
    local desiredHeight = WINDOW_CHROME_HEIGHT + contentHeight
    local frameWidth = clamp(desiredWidth, MIN_WINDOW_WIDTH, maxFrameWidth)
    local frameHeight = math.max(MIN_WINDOW_HEIGHT, desiredHeight)

    return {
        columns = columns,
        contentWidth = contentWidth,
        contentHeight = contentHeight,
        frameWidth = frameWidth,
        frameHeight = frameHeight,
    }
end

function BagsWindow:AcquireSectionFrame()
    local index = #self.sectionFrames + 1
    local section = CreateFrame("Frame", nil, self.content)
    section:SetHeight(HEADER_HEIGHT)
    section:EnableMouse(true)

    local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetJustifyH("LEFT")
    VesperGuild:ApplyConfiguredFont(title, 14, "")
    section.title = title

    local divider = section:CreateTexture(nil, "BACKGROUND")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", section, "LEFT", 0, -20)
    divider:SetPoint("RIGHT", section, "RIGHT", 0, -20)
    divider:SetColorTexture(1, 1, 1, 0.08)
    section.divider = divider

    self.sectionFrames[index] = section
    return section
end

function BagsWindow:AcquireItemButton()
    local button = CreateFrame("Button", nil, self.content, "BackdropTemplate")
    button:SetSize(DEFAULT_BUTTON_SIZE, DEFAULT_BUTTON_SIZE)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local glow = button:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
    glow:SetColorTexture(1, 1, 1, 0)
    glow:Hide()
    button.glow = glow

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local newGlow = button:CreateTexture(nil, "OVERLAY")
    newGlow:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    newGlow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    newGlow:SetBlendMode("ADD")
    newGlow:SetAlpha(0.95)
    newGlow:Hide()
    button.newGlow = newGlow

    local newGlowAnim = newGlow:CreateAnimationGroup()
    newGlowAnim:SetLooping("REPEAT")

    local pulseIn = newGlowAnim:CreateAnimation("Alpha")
    pulseIn:SetOrder(1)
    pulseIn:SetFromAlpha(0.55)
    pulseIn:SetToAlpha(1.0)
    pulseIn:SetDuration(0.35)
    pulseIn:SetSmoothing("IN_OUT")

    local pulseOut = newGlowAnim:CreateAnimation("Alpha")
    pulseOut:SetOrder(2)
    pulseOut:SetFromAlpha(1.0)
    pulseOut:SetToAlpha(0.55)
    pulseOut:SetDuration(0.35)
    pulseOut:SetSmoothing("IN_OUT")

    button.newGlowAnim = newGlowAnim

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    VesperGuild:ApplyConfiguredFont(count, 11, "OUTLINE")
    button.count = count

    local itemLevel = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemLevel:SetPoint("TOPLEFT", 3, -2)
    itemLevel:SetJustifyH("LEFT")
    VesperGuild:ApplyConfiguredFont(itemLevel, 9, "OUTLINE")
    itemLevel:Hide()
    button.itemLevel = itemLevel

    self.itemButtons[#self.itemButtons + 1] = button
    return button
end

function BagsWindow:AcquireSummaryButton()
    local button = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
    button:SetSize(DEFAULT_BUTTON_SIZE, DEFAULT_BUTTON_SIZE)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.06, 0.06, 0.06, 1)
    button:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
    button:EnableMouse(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetDesaturated(true)
    button.icon = icon

    local count = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    count:SetPoint("CENTER", 0, 0)
    VesperGuild:ApplyConfiguredFont(count, 13, "OUTLINE")
    button.count = count

    self.summaryButtons[#self.summaryButtons + 1] = button
    return button
end

function BagsWindow:AcquireEquippedBagButton()
    local button = CreateFrame("Button", nil, self.content, "BackdropTemplate")
    button:SetSize(DEFAULT_BUTTON_SIZE, DEFAULT_BUTTON_SIZE)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    VesperGuild:ApplyConfiguredFont(count, 11, "OUTLINE")
    button.count = count

    self.equippedBagButtons[#self.equippedBagButtons + 1] = button
    return button
end

function BagsWindow:HideAllReusableFrames()
    for i = 1, #self.sectionFrames do
        self.sectionFrames[i]:Hide()
    end
    for i = 1, #self.itemButtons do
        self.itemButtons[i]:Hide()
    end
    for i = 1, #self.equippedBagButtons do
        self.equippedBagButtons[i]:Hide()
    end
    for i = 1, #self.summaryButtons do
        self.summaryButtons[i]:Hide()
    end
end

function BagsWindow:GetEquippedBagSlotEntries(selectedCharacter, snapshot)
    local entries = {}
    local carried = type(snapshot) == "table" and snapshot.carried or nil
    local bags = type(carried) == "table" and carried.bags or nil
    if not selectedCharacter or type(bags) ~= "table" then
        return entries
    end

    for i = 1, #EQUIPPED_BAG_IDS do
        local bagID = EQUIPPED_BAG_IDS[i]
        local bag = bags[bagID] or {}
        local isReagent = REAGENT_BAG_ID and bagID == REAGENT_BAG_ID or false
        local entry = {
            bagID = bagID,
            name = bag.name or (isReagent and L["BAGS_BAG_SLOT_EMPTY_REAGENT"] or L["BAGS_BAG_SLOT_EMPTY"]),
            iconFileID = bag.iconFileID or "Interface\\Icons\\INV_Misc_Bag_08",
            size = tonumber(bag.size) or 0,
            ownerName = selectedCharacter.fullName,
            isCurrentCharacter = selectedCharacter.isCurrent and true or false,
            isReagent = isReagent,
        }

        if selectedCharacter.isCurrent and C_Container and C_Container.ContainerIDToInventoryID then
            local inventorySlotID = C_Container.ContainerIDToInventoryID(bagID)
            entry.inventorySlotID = inventorySlotID
            if inventorySlotID then
                entry.hyperlink = GetInventoryItemLink and GetInventoryItemLink("player", inventorySlotID) or nil
                entry.itemID = GetInventoryItemID and GetInventoryItemID("player", inventorySlotID) or nil
                entry.iconFileID = (GetInventoryItemTexture and GetInventoryItemTexture("player", inventorySlotID)) or entry.iconFileID
                entry.quality = GetInventoryItemQuality and GetInventoryItemQuality("player", inventorySlotID) or nil
            end
        end

        if entry.size <= 0 and not entry.hyperlink then
            if GetInventorySlotInfo then
                local _, emptySlotTexture = GetInventorySlotInfo(string.format("Bag%s", tostring(bagID)))
                if emptySlotTexture then
                    entry.iconFileID = emptySlotTexture
                end
            end
            entry.name = isReagent and L["BAGS_BAG_SLOT_EMPTY_REAGENT"] or L["BAGS_BAG_SLOT_EMPTY"]
        end

        entries[#entries + 1] = entry
    end

    return entries
end

function BagsWindow:ConfigureEquippedBagTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.isCurrentCharacter and button.inventorySlotID and button.hyperlink and GameTooltip.SetInventoryItem then
        GameTooltip:SetInventoryItem("player", button.inventorySlotID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("%s: %s", L["BAGS_LIVE"], button.ownerName or UNKNOWN), 0.85, 0.85, 0.85)
    else
        GameTooltip:SetText(button.itemName or UNKNOWN, 1, 1, 1)
        if button.bagSize and button.bagSize > 0 then
            GameTooltip:AddLine(string.format(L["BAGS_BAG_SLOT_SIZE_FMT"], button.bagSize), 0.85, 0.85, 0.85)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("%s: %s", button.isCurrentCharacter and L["BAGS_LIVE"] or L["BAGS_READ_ONLY"], button.ownerName or UNKNOWN), 0.85, 0.85, 0.85)
    end
    GameTooltip:Show()
end

function BagsWindow:HandleEquippedBagClick(button)
    if not button or not button.isCurrentCharacter or not button.inventorySlotID or InCombatLockdown() then
        return
    end

    if type(button.hyperlink) == "string" and button.hyperlink ~= "" and HandleModifiedItemClick and HandleModifiedItemClick(button.hyperlink) then
        return
    end

    if CursorHasItem and CursorHasItem() and PutItemInBag then
        PutItemInBag(button.inventorySlotID)
        return
    end

    if PickupBagFromSlot then
        PickupBagFromSlot(button.inventorySlotID)
        return
    end

    if PickupInventoryItem then
        PickupInventoryItem(button.inventorySlotID)
    end
end

function BagsWindow:ConfigureEquippedBagButton(button, entry, viewSettings)
    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local countFontSize = math.max(8, math.min(20, tonumber(viewSettings and viewSettings.stackCountFontSize) or 11))

    button:SetSize(itemIconSize, itemIconSize)
    VesperGuild:ApplyConfiguredFont(button.count, countFontSize, "OUTLINE")
    button.itemName = entry.name
    button.hyperlink = entry.hyperlink
    button.ownerName = entry.ownerName
    button.inventorySlotID = entry.inventorySlotID
    button.isCurrentCharacter = entry.isCurrentCharacter and true or false
    button.bagSize = tonumber(entry.size) or 0
    button.icon:SetTexture(entry.iconFileID or "Interface\\Icons\\INV_Misc_Bag_08")
    button.count:SetText(button.bagSize > 0 and tostring(button.bagSize) or "")

    if entry.quality ~= nil then
        local r, g, b = safeColorForQuality(entry.quality)
        button:SetBackdropBorderColor(r, g, b, 0.5)
    else
        button:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
    end
    button:SetBackdropColor(0.08, 0.08, 0.08, 1)
    button.icon:SetDesaturated(button.bagSize <= 0)
    button:SetAlpha(button.bagSize > 0 and 1 or 0.68)

    button:SetScript("OnEnter", function(selfButton)
        self:ConfigureEquippedBagTooltip(selfButton)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(selfButton)
        self:HandleEquippedBagClick(selfButton)
    end)
    button:SetScript("OnDragStart", function(selfButton)
        self:HandleEquippedBagClick(selfButton)
    end)
    button:SetScript("OnReceiveDrag", function(selfButton)
        self:HandleEquippedBagClick(selfButton)
    end)
    button:Show()
end

function BagsWindow:ConfigureTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.isCurrentCharacter and not button.isCombined and button.bagID and button.slotID then
        GameTooltip:SetBagItem(button.bagID, button.slotID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("%s: %s", L["BAGS_LIVE"], button.ownerName or UNKNOWN), 0.85, 0.85, 0.85)
    else
        if type(button.hyperlink) == "string" and button.hyperlink ~= "" then
            GameTooltip:SetHyperlink(button.hyperlink)
        else
            GameTooltip:SetText(button.itemName or buildFallbackItemName(button.itemID), 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("%s: %s", button.isCurrentCharacter and L["BAGS_LIVE"] or L["BAGS_READ_ONLY"], button.ownerName or UNKNOWN), 0.85, 0.85, 0.85)
    end
    if button.isCombined then
        GameTooltip:AddLine(string.format(L["BAGS_COMBINED_FROM_FMT"], tonumber(button.combinedStacks) or 1), 0.85, 0.85, 0.85)
        GameTooltip:AddLine(string.format(L["BAGS_TOTAL_ITEMS_FMT"], tonumber(button.totalCount) or tonumber(button.stackCount) or 0), 0.85, 0.85, 0.85)
    end
    GameTooltip:Show()
end

function BagsWindow:ConfigureSummaryTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.summaryLabel or UNKNOWN, 1, 1, 1)
    GameTooltip:AddLine(tostring(button.summaryCount or 0), 0.85, 0.85, 0.85)
    GameTooltip:Show()
end

function BagsWindow:HandleItemClick(button, mouseButton)
    if type(button.hyperlink) == "string" and button.hyperlink ~= "" and HandleModifiedItemClick and HandleModifiedItemClick(button.hyperlink) then
        return
    end

    if button.isCombined or not button.isCurrentCharacter or InCombatLockdown() then
        return
    end

    if mouseButton == "RightButton" then
        if C_Container and C_Container.UseContainerItem then
            C_Container.UseContainerItem(button.bagID, button.slotID)
        end
    elseif C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(button.bagID, button.slotID)
    end
end

function BagsWindow:CanDisplayItemLevel(record)
    if not record or not record.itemID then
        return false
    end

    local classID
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, resolvedClassID = C_Item.GetItemInfoInstant(record.itemID)
        classID = resolvedClassID
    elseif GetItemInfoInstant then
        local _, _, _, _, _, resolvedClassID = GetItemInfoInstant(record.itemID)
        classID = resolvedClassID
    end

    return classID == ITEM_CLASS.Weapon or classID == ITEM_CLASS.Armor
end

function BagsWindow:GetItemLevelForRecord(record)
    if not self:CanDisplayItemLevel(record) then
        return nil
    end

    local itemLevel
    if GetDetailedItemLevelInfo then
        itemLevel = GetDetailedItemLevelInfo(record.hyperlink or record.itemID)
    end
    if (not itemLevel or itemLevel <= 0) and C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(record.hyperlink or record.itemID)
    end

    itemLevel = tonumber(itemLevel)
    if not itemLevel or itemLevel <= 0 then
        return nil
    end

    return math.floor(itemLevel + 0.5)
end

function BagsWindow:IsNewItem(record, isCurrentCharacter)
    if type(record) == "table" and type(record.combinedRecords) == "table" then
        for i = 1, #record.combinedRecords do
            if self:IsNewItem(record.combinedRecords[i], isCurrentCharacter) then
                return true
            end
        end
    end

    if not isCurrentCharacter or not record or not record.bagID or not record.slotID then
        return false
    end

    if C_NewItems and C_NewItems.IsNewItem then
        local ok, isNewItem = pcall(C_NewItems.IsNewItem, record.bagID, record.slotID)
        if ok and isNewItem then
            return true
        end
    end

    return record.isNewItem and true or false
end

function BagsWindow:ShouldShowNewItemGlow(record, isCurrentCharacter)
    if not self:IsNewItem(record, isCurrentCharacter) then
        return false
    end

    local glowKey = self:GetCombineRecordKey(record)
    if not glowKey then
        glowKey = string.format("slot:%s:%s", tostring(record and record.bagID or 0), tostring(record and record.slotID or 0))
    end

    self.newItemGlowKeysSeen = self.newItemGlowKeysSeen or {}
    if self.newItemGlowKeysSeen[glowKey] then
        return false
    end

    self.newItemGlowKeysSeen[glowKey] = true
    return true
end

function BagsWindow:ConfigureItemButton(button, record, isCurrentCharacter, ownerName, viewSettings)
    button.itemID = record.itemID
    button.itemName = record.itemName
    button.itemDescription = record.itemDescription
    button.searchText = record.searchText
    button.hyperlink = record.hyperlink
    button.isCombined = record.isCombined and true or false
    button.bagID = button.isCombined and nil or record.bagID
    button.slotID = button.isCombined and nil or record.slotID
    button.isCurrentCharacter = isCurrentCharacter
    button.ownerName = ownerName
    button.combinedStacks = tonumber(record.combinedStacks) or 1
    button.totalCount = tonumber(record.stackCount) or 1

    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local countFontSize = math.max(8, math.min(20, tonumber(viewSettings and viewSettings.stackCountFontSize) or 11))
    local itemLevelFontSize = math.max(8, math.min(18, tonumber(viewSettings and viewSettings.itemLevelFontSize) or 9))

    button:SetSize(itemIconSize, itemIconSize)
    VesperGuild:ApplyConfiguredFont(button.count, countFontSize, "OUTLINE")
    VesperGuild:ApplyConfiguredFont(button.itemLevel, itemLevelFontSize, "OUTLINE")

    button.icon:SetTexture(record.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.count:SetText(((button.isCombined and button.totalCount > 1) or (tonumber(record.stackCount) or 1) > 1) and tostring(button.totalCount) or "")

    local r, g, b = safeColorForQuality(record.quality)
    if (viewSettings and viewSettings.qualityGlowIntensity or 0) > 0 and record.quality ~= nil then
        local glowIntensity = viewSettings.qualityGlowIntensity
        button:SetBackdropBorderColor(r, g, b, 0.35 + (glowIntensity * 0.65))
        button.glow:SetColorTexture(r, g, b, 0.08 + (glowIntensity * 0.22))
        button.glow:Show()
    else
        button:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
        button.glow:Hide()
    end
    button:SetBackdropColor(0.08, 0.08, 0.08, 1)
    button:SetEnabled(true)

    if viewSettings and viewSettings.showItemLevel then
        local itemLevel = self:GetItemLevelForRecord(record)
        if itemLevel then
            button.itemLevel:SetText(tostring(itemLevel))
            button.itemLevel:SetTextColor(r, g, b, 1)
            button.itemLevel:Show()
        else
            button.itemLevel:SetText("")
            button.itemLevel:Hide()
        end
    else
        button.itemLevel:SetText("")
        button.itemLevel:Hide()
    end

    if self:ShouldShowNewItemGlow(record, isCurrentCharacter) then
        button.newGlow:SetAtlas(getNewItemGlowAtlas(record.quality), false)
        button.newGlow:Show()
        if not button.newGlowAnim:IsPlaying() then
            button.newGlowAnim:Play()
        end
    else
        button.newGlow:Hide()
        if button.newGlowAnim:IsPlaying() then
            button.newGlowAnim:Stop()
        end
    end

    button:SetScript("OnEnter", function(selfButton)
        self:ConfigureTooltip(selfButton)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(selfButton, mouseButton)
        self:HandleItemClick(selfButton, mouseButton)
    end)
    button:SetScript("OnDragStart", function(selfButton)
        if not selfButton.isCombined and selfButton.isCurrentCharacter and not InCombatLockdown() and C_Container and C_Container.PickupContainerItem then
            C_Container.PickupContainerItem(selfButton.bagID, selfButton.slotID)
        end
    end)
    button:SetScript("OnReceiveDrag", function(selfButton)
        if not selfButton.isCombined and selfButton.isCurrentCharacter and not InCombatLockdown() and C_Container and C_Container.PickupContainerItem then
            C_Container.PickupContainerItem(selfButton.bagID, selfButton.slotID)
        end
    end)
    self:ApplySearchDimState(button, record, self:GetSearchTokens())
    button:Show()
end

function BagsWindow:ConfigureSummaryButton(button, summaryEntry, viewSettings)
    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local countFontSize = math.max(8, math.min(20, tonumber(viewSettings and viewSettings.stackCountFontSize) or 11))

    button:SetSize(itemIconSize, itemIconSize)
    button.summaryLabel = summaryEntry.label
    button.summaryCount = tonumber(summaryEntry.count) or 0
    button.icon:SetTexture(summaryEntry.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.count:SetText(tostring(button.summaryCount))
    button.count:SetTextColor(0.95, 0.95, 0.95, 1)
    VesperGuild:ApplyConfiguredFont(button.count, countFontSize, "OUTLINE")
    button:SetScript("OnEnter", function(selfButton)
        self:ConfigureSummaryTooltip(selfButton)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:Show()
end

function BagsWindow:RefreshWindow()
    if not self.frame then
        return
    end

    self:CleanupLegacyScrollArtifacts()
    wipe(self.newItemGlowKeysSeen)
    local viewSettings = self:GetViewSettings()
    self:UpdateBagSlotsButtonVisual(self.bagSlotsMenu and self.bagSlotsMenu:IsShown())
    self:UpdateCombineStacksButtonVisual(viewSettings.combineStacks)

    local store = self:GetStore()
    if not store then
        return
    end

    local selectedCharacter = self:ResolveSelectedCharacter()
    self:HideAllReusableFrames()

    if not selectedCharacter then
        self.currentDisplayCharacter = nil
        self.currentSnapshot = nil
        self:HideCharacterMenu()
        self:HideBagSlotsMenu()
        if self.characterDropdown then
            if self.characterDropdownText then
                self.characterDropdownText:SetText(L["BAGS_EMPTY"])
            end
            self:SetCharacterDropdownEnabled(false)
        end
        self:UpdateCleanupButtonVisual(false)
        self.modeText:SetText("")
        self.emptyText:SetText(L["BAGS_EMPTY"])
        self.emptyText:Show()
        self.frame:SetSize(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT)
        self.emptyText:SetWidth(MIN_WINDOW_WIDTH - 60)
        self.content:SetSize(MIN_WINDOW_WIDTH - 32, 40)
        self:SaveWindowState()
        return
    end

    if self.characterDropdown then
        if self.characterDropdownText then
            self.characterDropdownText:SetText(selectedCharacter.fullName)
        end
        self:SetCharacterDropdownEnabled(true)
    end
    self:UpdateCharacterDropdownVisual()
    self:UpdateCleanupButtonVisual(selectedCharacter.isCurrent)
    self.modeText:SetText(selectedCharacter.isCurrent and L["BAGS_LIVE"] or L["BAGS_READ_ONLY"])

    local snapshot = store:GetCharacterBagSnapshot(selectedCharacter.key)
    if not snapshot then
        self.currentDisplayCharacter = selectedCharacter
        self.currentSnapshot = nil
        self:HideBagSlotsMenu()
        self.emptyText:SetText(L["BAGS_EMPTY"])
        self.emptyText:Show()
        self.frame:SetSize(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT)
        self.emptyText:SetWidth(MIN_WINDOW_WIDTH - 60)
        self.content:SetSize(MIN_WINDOW_WIDTH - 32, 40)
        self:SaveWindowState()
        return
    end

    self.currentDisplayCharacter = selectedCharacter
    self.currentSnapshot = snapshot

    local categories = store:GetCharacterCategoryList(selectedCharacter.key)
    local emptySlotSummary = store.GetCharacterEmptySlotSummary and store:GetCharacterEmptySlotSummary(selectedCharacter.key) or {}
    local sectionIndex = 0
    local itemIndex = 0
    local summaryIndex = 0
    local groups, maxItemCount = self:BuildLayoutGroups(store, selectedCharacter.key, categories, viewSettings)
    local layout = self:ResolveAutoLayout(groups, maxItemCount, viewSettings)
    local contentWidth = layout.contentWidth
    local columns = layout.columns
    local slotPitch = viewSettings.itemIconSize + viewSettings.buttonGap
    self.frame:SetSize(layout.frameWidth, layout.frameHeight)
    self.emptyText:SetWidth(layout.frameWidth - 60)
    self:SaveWindowState()
    local yOffset = -8

    if self.bagSlotsMenu and self.bagSlotsMenu:IsShown() then
        if not self:RefreshBagSlotsMenu(selectedCharacter, snapshot, viewSettings) then
            self:HideBagSlotsMenu()
        else
            self:UpdateBagSlotsButtonVisual(true)
        end
    end

    if #groups == 0 then
        self.emptyText:SetText(L["BAGS_NO_ITEMS"])
        self.emptyText:ClearAllPoints()
        self.emptyText:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, yOffset)
        self.emptyText:Show()
        yOffset = yOffset - 28 - SUMMARY_GAP
    else
        self.emptyText:Hide()
    end

    for i = 1, #groups do
        local category = groups[i].category
        local items = groups[i].items
        if #items > 0 then
            sectionIndex = sectionIndex + 1
            local section = self.sectionFrames[sectionIndex] or self:AcquireSectionFrame()
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, yOffset)
            section:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -8, yOffset)
            if groups[i].hidden then
                section.title:SetText(string.format("%s (%d) (%s)", category.label, category.count, L["BAGS_HIDDEN"]))
                section.title:SetTextColor(0.8, 0.8, 0.8, 1)
                section.divider:SetColorTexture(1, 1, 1, 0.05)
            else
                section.title:SetText(string.format("%s (%d)", category.label, category.count))
                section.title:SetTextColor(1, 1, 1, 1)
                section.divider:SetColorTexture(1, 1, 1, 0.08)
            end
            section:SetScript("OnMouseUp", function(_, mouseButton)
                if mouseButton == "LeftButton" then
                    self:ToggleCategoryCollapsed(selectedCharacter.key, category.key)
                end
            end)
            section:Show()

            yOffset = yOffset - HEADER_HEIGHT
            if not groups[i].hidden then
                local row = 0
                local column = 0
                for itemPosition = 1, #items do
                    itemIndex = itemIndex + 1
                    local button = self.itemButtons[itemIndex] or self:AcquireItemButton()
                    local x = CONTENT_SIDE_PADDING + (column * slotPitch)
                    local y = yOffset - (row * slotPitch)
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
                    self:ConfigureItemButton(button, items[itemPosition], selectedCharacter.isCurrent, selectedCharacter.fullName, viewSettings)

                    column = column + 1
                    if column >= columns then
                        column = 0
                        row = row + 1
                    end
                end

                if column > 0 then
                    row = row + 1
                end

                yOffset = yOffset - (row * slotPitch) - SECTION_GAP
            else
                yOffset = yOffset - SECTION_GAP
            end
        end
    end

    if #groups > 0 then
        yOffset = yOffset + (SECTION_GAP - SUMMARY_GAP)
    end

    for i = 1, #emptySlotSummary do
        summaryIndex = summaryIndex + 1
        local button = self.summaryButtons[summaryIndex] or self:AcquireSummaryButton()
        local x = CONTENT_SIDE_PADDING + ((i - 1) * slotPitch)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, yOffset)
        self:ConfigureSummaryButton(button, emptySlotSummary[i], viewSettings)
    end

    self.content:SetSize(contentWidth, layout.contentHeight)
end
