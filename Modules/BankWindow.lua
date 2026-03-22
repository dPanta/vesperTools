local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local BankWindow = vesperTools:NewModule("BankWindow", "AceEvent-3.0")
local L = vesperTools.L
local ITEM_CLASS = Enum and Enum.ItemClass or {}

local MIN_WINDOW_WIDTH = 480
local MIN_WINDOW_HEIGHT = 220
local DEFAULT_BUTTON_SIZE = 38
local BUTTON_GAP = 6
local SECTION_GAP = 10
local HEADER_HEIGHT = 28
local SUMMARY_GAP = 14
local CONTENT_SIDE_PADDING = 8
local WINDOW_SCREEN_MARGIN = 48
local WINDOW_CHROME_HEIGHT = 96
local VIEW_DROPDOWN_WIDTH = 180
local VIEW_DROPDOWN_HEIGHT = 22
local CHARACTER_DROPDOWN_WIDTH = 220
local VIEW_MENU_ROW_HEIGHT = 24
local VIEW_MENU_PADDING = 4
local VIEW_MENU_GAP = 4
local CHARACTER_MENU_ROW_HEIGHT = 24
local CHARACTER_MENU_PADDING = 4
local CHARACTER_MENU_GAP = 4
local HEADER_ACTION_BUTTON_HEIGHT = 22
local HEADER_ACTION_BUTTON_GAP = 6
local DEPOSIT_BUTTON_WIDTH = 72
local COMBINE_BUTTON_WIDTH = 76
local TITLEBAR_SEARCH_WIDTH = 220
local TITLEBAR_SEARCH_HEIGHT = 22
local TITLEBAR_SEARCH_CLEAR_BUTTON_SIZE = 14
local CATEGORY_TOGGLE_BUTTON_SIZE = 14
local VIEW_DROPDOWN_ARROW_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\DropdownArrow-50"
local NAV_LEFT_INSET = 10
local NAV_RIGHT_INSET = 40

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

function BankWindow:OnInitialize()
    self.frame = nil
    self.titleText = nil
    self.modeText = nil
    self.searchBox = nil
    self.searchClearButton = nil
    self.searchPlaceholder = nil
    self.searchQuery = nil
    self.viewDropdown = nil
    self.viewDropdownText = nil
    self.viewDropdownArrow = nil
    self.characterDropdown = nil
    self.characterDropdownText = nil
    self.characterDropdownMatchText = nil
    self.characterDropdownArrow = nil
    self.viewMenu = nil
    self.viewMenuDismiss = nil
    self.viewMenuButtons = {}
    self.characterMenu = nil
    self.characterMenuDismiss = nil
    self.characterMenuButtons = {}
    self.depositButton = nil
    self.depositButtonText = nil
    self.combineStacksButton = nil
    self.combineStacksButtonText = nil
    self.combineStacksButtonGlow = nil
    self.content = nil
    self.emptyText = nil
    self.sectionFrames = {}
    self.itemButtons = {}
    self.summaryButtons = {}
    self.selectedViewType = "character"
    self.selectedCharacterKey = nil
    self.displayViews = {}
    self.displayCharacters = {}
    self.characterSearchMatchCounts = nil
end

function BankWindow:OnEnable()
    self:RegisterMessage("VESPERTOOLS_BANK_SNAPSHOT_UPDATED", "OnBankDataChanged")
    self:RegisterMessage("VESPERTOOLS_BANK_CHARACTER_UPDATED", "OnBankDataChanged")
    self:RegisterMessage("VESPERTOOLS_WARBAND_BANK_UPDATED", "OnBankDataChanged")
    self:RegisterMessage("VESPERTOOLS_CONFIG_CHANGED", "OnConfigChanged")
end

function BankWindow:GetStore()
    return vesperTools:GetModule("BankStore", true)
end

function BankWindow:OnBankDataChanged()
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function BankWindow:OnConfigChanged()
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function BankWindow:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
        return
    end

    self:ShowWindow()
end

function BankWindow:HandleCloseRequest()
    local bridge = vesperTools:GetModule("BagsBridge", true)
    local store = self:GetStore()
    local bankIsLive = store
        and ((type(store.IsCharacterBankLive) == "function" and store:IsCharacterBankLive())
        or (type(store.IsWarbandBankLive) == "function" and store:IsWarbandBankLive()))
        and true or false

    if bankIsLive and bridge and type(bridge.IsBankReplacementEnabled) == "function" and bridge:IsBankReplacementEnabled() then
        if type(bridge.CloseBankReplacementWindow) == "function" then
            bridge:CloseBankReplacementWindow()
            return
        end
    end

    if self.frame then
        self.frame:Hide()
    end
end

function BankWindow:ShowWindow(preferredViewKey)
    if not self.frame then
        self:CreateWindow()
    end

    self:SelectDefaultViewForOpen(preferredViewKey)
    self:RefreshWindow()
    self.frame:Show()
    self.frame:Raise()
end

function BankWindow:SelectDefaultViewForOpen(preferredViewKey)
    local store = self:GetStore()
    local bagsProfile = vesperTools:GetBagsProfile()
    local resolvedViewKey = preferredViewKey

    if store and type(store.CreateOrUpdateCurrentCharacter) == "function" then
        store:CreateOrUpdateCurrentCharacter()
    end

    if resolvedViewKey ~= "character" and resolvedViewKey ~= "warband" then
        resolvedViewKey = bagsProfile and bagsProfile.lastViewedBankView or "warband"
    end
    if resolvedViewKey ~= "character" and resolvedViewKey ~= "warband" then
        resolvedViewKey = "warband"
    end

    local displayCharacters = store and type(store.GetDisplayCharacters) == "function" and store:GetDisplayCharacters() or {}
    local hasCharacterData = false
    for i = 1, #displayCharacters do
        if displayCharacters[i].hasSnapshot or displayCharacters[i].isLive then
            hasCharacterData = true
            break
        end
    end

    local warbandSnapshot = store and type(store.GetWarbandBankSnapshot) == "function" and store:GetWarbandBankSnapshot() or nil
    local warbandIsLive = store and type(store.IsWarbandBankLive) == "function" and store:IsWarbandBankLive() or false
    local warbandHasData = type(warbandSnapshot) == "table" and (tonumber(warbandSnapshot.lastSeen) or 0) > 0
    local hasWarbandData = warbandIsLive or warbandHasData

    if resolvedViewKey == "warband" and not hasWarbandData and hasCharacterData then
        resolvedViewKey = "character"
    elseif resolvedViewKey == "character" and not hasCharacterData and hasWarbandData then
        resolvedViewKey = "warband"
    elseif not hasWarbandData and not hasCharacterData then
        resolvedViewKey = "character"
    end

    self.displayCharacters = displayCharacters
    self.selectedViewType = resolvedViewKey == "warband" and "warband" or "character"
    if bagsProfile then
        bagsProfile.lastViewedBankView = self.selectedViewType
    end
end

function BankWindow:ResolveSelectedView()
    self.displayViews = {
        { key = "character", label = L["BANK_SWITCH_CHARACTER"] },
        { key = "warband", label = L["BANK_SWITCH_WARBAND"] },
    }

    local selectedKey = self.selectedViewType
    for i = 1, #self.displayViews do
        if self.displayViews[i].key == selectedKey then
            return self.displayViews[i]
        end
    end

    self.selectedViewType = "character"
    return self.displayViews[1]
end

function BankWindow:ResolveSelectedCharacter()
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
    local currentCharacterKey = store.GetCurrentCharacterKey and store:GetCurrentCharacterKey() or nil
    local selectedKey = self.selectedCharacterKey or (bagsProfile and bagsProfile.lastViewedBankCharacterGUID) or currentCharacterKey

    for i = 1, #self.displayCharacters do
        if self.displayCharacters[i].key == selectedKey then
            self.selectedCharacterKey = selectedKey
            return self.displayCharacters[i]
        end
    end

    for i = 1, #self.displayCharacters do
        if self.displayCharacters[i].isCurrent then
            self.selectedCharacterKey = self.displayCharacters[i].key
            if bagsProfile then
                bagsProfile.lastViewedBankCharacterGUID = self.selectedCharacterKey
            end
            return self.displayCharacters[i]
        end
    end

    self.selectedCharacterKey = self.displayCharacters[1].key
    if bagsProfile then
        bagsProfile.lastViewedBankCharacterGUID = self.selectedCharacterKey
    end
    return self.displayCharacters[1]
end

function BankWindow:SetCharacterDropdownEnabled(isEnabled)
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

function BankWindow:UpdateCharacterDropdownVisual()
    if not self.characterDropdown then
        return
    end

    local isOpen = self.characterMenu and self.characterMenu:IsShown()
    local backdropAlpha = isOpen and 0.98 or 0.92
    self.characterDropdown:SetBackdropColor(0.08, 0.08, 0.1, backdropAlpha)
    if self.characterDropdownArrow then
        self.characterDropdownArrow:SetTexture(VIEW_DROPDOWN_ARROW_TEXTURE)
        self.characterDropdownArrow:SetRotation(isOpen and math.pi or 0)
    end
end

function BankWindow:SetSelectedCharacter(characterKey)
    if type(characterKey) ~= "string" or characterKey == "" then
        return
    end

    self.selectedCharacterKey = characterKey
    local bagsProfile = vesperTools:GetBagsProfile()
    if bagsProfile then
        bagsProfile.lastViewedBankCharacterGUID = characterKey
    end
    self:RefreshWindow()
end

function BankWindow:SetViewDropdownEnabled(isEnabled)
    if not self.viewDropdown then
        return
    end

    if isEnabled then
        self.viewDropdown:Enable()
        self.viewDropdown:SetAlpha(1)
    else
        self.viewDropdown:Disable()
        self.viewDropdown:SetAlpha(0.5)
    end
end

function BankWindow:UpdateViewDropdownVisual()
    if not self.viewDropdown then
        return
    end

    local isOpen = self.viewMenu and self.viewMenu:IsShown()
    local backdropAlpha = isOpen and 0.98 or 0.92
    self.viewDropdown:SetBackdropColor(0.08, 0.08, 0.1, backdropAlpha)
    if self.viewDropdownArrow then
        self.viewDropdownArrow:SetTexture(VIEW_DROPDOWN_ARROW_TEXTURE)
        self.viewDropdownArrow:SetRotation(isOpen and math.pi or 0)
    end
end

function BankWindow:SetSelectedView(viewKey)
    if viewKey ~= "character" and viewKey ~= "warband" then
        return
    end

    self.selectedViewType = viewKey
    if viewKey ~= "character" then
        self:HideCharacterMenu()
    end
    local bagsProfile = vesperTools:GetBagsProfile()
    if bagsProfile then
        bagsProfile.lastViewedBankView = viewKey
    end

    self:RefreshWindow()
end

function BankWindow:HideViewMenu()
    if self.viewMenu then
        self.viewMenu:Hide()
    end

    if self.viewMenuDismiss then
        self.viewMenuDismiss:Hide()
    end

    self:UpdateViewDropdownVisual()
end

function BankWindow:HideCharacterMenu()
    if self.characterMenu then
        self.characterMenu:Hide()
    end

    if self.characterMenuDismiss then
        self.characterMenuDismiss:Hide()
    end

    self:UpdateCharacterDropdownVisual()
end

function BankWindow:GetViewMenuFrames()
    if not self.viewMenuDismiss then
        local dismiss = CreateFrame("Button", nil, UIParent)
        dismiss:SetAllPoints(UIParent)
        dismiss:SetFrameStrata("TOOLTIP")
        dismiss:SetToplevel(true)
        dismiss:EnableMouse(true)
        dismiss:SetScript("OnClick", function()
            self:HideViewMenu()
        end)
        dismiss:Hide()
        self.viewMenuDismiss = dismiss
    end

    if not self.viewMenu then
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
        self.viewMenu = menu
    end

    local baseLevel = math.max(90, (self.frame and self.frame:GetFrameLevel() or 0) + 60)
    self.viewMenuDismiss:SetFrameLevel(baseLevel - 1)
    self.viewMenu:SetFrameLevel(baseLevel)

    return self.viewMenu, self.viewMenuDismiss
end

function BankWindow:GetCharacterMenuFrames()
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

function BankWindow:AcquireViewMenuButton(menu)
    local index = #self.viewMenuButtons + 1
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
        self:HideViewMenu()
        if selfButton.viewKey then
            self:SetSelectedView(selfButton.viewKey)
        end
    end)

    self.viewMenuButtons[index] = button
    return button
end

function BankWindow:AcquireCharacterMenuButton(menu)
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

    local matchText = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    matchText:SetPoint("LEFT", button, "CENTER", 8, 0)
    matchText:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    matchText:SetJustifyH("RIGHT")
    matchText:SetJustifyV("MIDDLE")
    matchText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(matchText, 11, "")
    matchText:Hide()
    button.matchText = matchText

    text:ClearAllPoints()
    text:SetPoint("LEFT", button, "LEFT", 10, 0)
    text:SetPoint("RIGHT", matchText, "LEFT", -8, 0)

    button:SetScript("OnClick", function(selfButton)
        self:HideCharacterMenu()
        if selfButton.characterKey then
            self:SetSelectedCharacter(selfButton.characterKey)
        end
    end)

    self.characterMenuButtons[index] = button
    return button
end

function BankWindow:RefreshViewMenu()
    local menu = self.viewMenu
    if not menu then
        return
    end

    local menuWidth = math.max(VIEW_DROPDOWN_WIDTH, self.viewDropdown and math.floor((self.viewDropdown:GetWidth() or VIEW_DROPDOWN_WIDTH) + 0.5) or VIEW_DROPDOWN_WIDTH)
    local innerWidth = menuWidth - (VIEW_MENU_PADDING * 2)

    for i = 1, #self.displayViews do
        local view = self.displayViews[i]
        local button = self.viewMenuButtons[i] or self:AcquireViewMenuButton(menu)
        button.viewKey = view.key
        button:SetSize(innerWidth, VIEW_MENU_ROW_HEIGHT)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", VIEW_MENU_PADDING, -VIEW_MENU_PADDING - ((i - 1) * VIEW_MENU_ROW_HEIGHT))
        button.text:SetText(view.label)
        if view.key == self.selectedViewType then
            button.selectedBackground:Show()
            button.text:SetTextColor(0.92, 0.97, 1, 1)
        else
            button.selectedBackground:Hide()
            button.text:SetTextColor(0.82, 0.86, 0.92, 1)
        end
        button:Show()
    end

    for i = #self.displayViews + 1, #self.viewMenuButtons do
        self.viewMenuButtons[i]:Hide()
    end

    menu:SetSize(menuWidth, (VIEW_MENU_PADDING * 2) + (#self.displayViews * VIEW_MENU_ROW_HEIGHT))
end

function BankWindow:RefreshCharacterMenu()
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
        local matchCount = self.characterSearchMatchCounts and tonumber(self.characterSearchMatchCounts[character.key]) or 0
        if matchCount > 0 then
            button.matchText:SetText(string.format(L["SEARCH_FOUND_FMT"], matchCount))
            button.matchText:SetTextColor(0.42, 0.94, 0.52, 1)
            button.matchText:Show()
        else
            button.matchText:SetText("")
            button.matchText:Hide()
        end
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

function BankWindow:UpdateSelectedCharacterDropdownMatch(characterKey)
    if not self.characterDropdownText or not self.characterDropdownArrow then
        return
    end

    local matchCount = self.characterSearchMatchCounts and characterKey and tonumber(self.characterSearchMatchCounts[characterKey]) or 0

    self.characterDropdownText:ClearAllPoints()
    self.characterDropdownText:SetPoint("LEFT", self.characterDropdown, "LEFT", 8, 0)

    if self.characterDropdownMatchText and matchCount > 0 then
        self.characterDropdownMatchText:SetText(string.format(L["SEARCH_FOUND_FMT"], matchCount))
        self.characterDropdownMatchText:SetTextColor(0.42, 0.94, 0.52, 1)
        self.characterDropdownMatchText:Show()
        self.characterDropdownText:SetPoint("RIGHT", self.characterDropdownMatchText, "LEFT", -8, 0)
    else
        if self.characterDropdownMatchText then
            self.characterDropdownMatchText:SetText("")
            self.characterDropdownMatchText:Hide()
        end
        self.characterDropdownText:SetPoint("RIGHT", self.characterDropdownArrow, "LEFT", -6, 0)
    end
end

function BankWindow:OpenViewMenu(button)
    if not button then
        return
    end

    local menu, dismiss = self:GetViewMenuFrames()
    if menu:IsShown() then
        self:HideViewMenu()
        return
    end

    self:ResolveSelectedView()
    self:HideCharacterMenu()
    self:RefreshViewMenu()

    dismiss:Show()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -VIEW_MENU_GAP)
    menu:Show()
    menu:Raise()
    self:UpdateViewDropdownVisual()
end

function BankWindow:OpenCharacterMenu(button)
    if not button or #self.displayCharacters == 0 then
        return
    end

    local menu, dismiss = self:GetCharacterMenuFrames()
    if menu:IsShown() then
        self:HideCharacterMenu()
        return
    end

    self:HideViewMenu()
    self:RefreshCharacterMenu()

    dismiss:Show()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -CHARACTER_MENU_GAP)
    menu:Show()
    menu:Raise()
    self:UpdateCharacterDropdownVisual()
end

function BankWindow:SaveWindowState()
    if not self.frame then
        return
    end

    local bagsProfile = vesperTools:GetBagsProfile()
    if not bagsProfile then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = self.frame:GetPoint()
    bagsProfile.bankWindow.point = point
    bagsProfile.bankWindow.relativePoint = relativePoint
    bagsProfile.bankWindow.xOfs = xOfs
    bagsProfile.bankWindow.yOfs = yOfs
    bagsProfile.bankWindow.width = math.floor((self.frame:GetWidth() or MIN_WINDOW_WIDTH) + 0.5)
    bagsProfile.bankWindow.height = math.floor((self.frame:GetHeight() or MIN_WINDOW_HEIGHT) + 0.5)
end

function BankWindow:GetCollapsedCategoryTable(viewKey, create)
    local bagsProfile = vesperTools:GetBagsProfile()
    if not bagsProfile or type(viewKey) ~= "string" or viewKey == "" then
        return nil
    end

    bagsProfile.collapsedBankCategories = bagsProfile.collapsedBankCategories or {}
    if create and type(bagsProfile.collapsedBankCategories[viewKey]) ~= "table" then
        bagsProfile.collapsedBankCategories[viewKey] = {}
    end

    return bagsProfile.collapsedBankCategories[viewKey]
end

function BankWindow:IsCategoryCollapsed(viewKey, categoryKey)
    local collapsed = self:GetCollapsedCategoryTable(viewKey, false)
    return collapsed and collapsed[categoryKey] and true or false
end

function BankWindow:SetCategoryCollapsed(viewKey, categoryKey, isCollapsed)
    if type(viewKey) ~= "string" or viewKey == "" or type(categoryKey) ~= "string" or categoryKey == "" then
        return
    end

    local collapsed = self:GetCollapsedCategoryTable(viewKey, isCollapsed)
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

    local bagsProfile = vesperTools:GetBagsProfile()
    if bagsProfile and bagsProfile.collapsedBankCategories then
        bagsProfile.collapsedBankCategories[viewKey] = nil
    end
end

function BankWindow:ToggleCategoryCollapsed(viewKey, categoryKey)
    self:SetCategoryCollapsed(viewKey, categoryKey, not self:IsCategoryCollapsed(viewKey, categoryKey))
    self:RefreshWindow()
end

function BankWindow:GetViewSettings()
    local bagsProfile = vesperTools:GetBagsProfile()
    local display = bagsProfile and bagsProfile.bankDisplay or nil
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

function BankWindow:ToggleCombineStacks()
    local bagsProfile = vesperTools:GetBagsProfile()
    if not bagsProfile then
        return
    end

    bagsProfile.bankDisplay = bagsProfile.bankDisplay or {}
    bagsProfile.bankDisplay.combineStacks = not (bagsProfile.bankDisplay.combineStacks and true or false)
    self:RefreshWindow()
end

function BankWindow:UpdateCombineStacksButtonVisual(isActive)
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

function BankWindow:ConfigureCombineStacksButtonTooltip(button, isActive)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["BAGS_COMBINE_STACKS"], 1, 1, 1)
    GameTooltip:AddLine(isActive and L["BAGS_COMBINE_STACKS_ON"] or L["BAGS_COMBINE_STACKS_OFF"], 0.85, 0.85, 0.85)
    GameTooltip:Show()
end

function BankWindow:CanDepositWarboundItems()
    local store = self:GetStore()
    if InCombatLockdown() then
        return false
    end
    if not store or type(store.IsWarbandBankLive) ~= "function" or not store:IsWarbandBankLive() then
        return false
    end
    if not C_Bank or type(C_Bank.AutoDepositItemsIntoBank) ~= "function" then
        return false
    end
    return Enum and Enum.BankType and Enum.BankType.Account ~= nil
end

function BankWindow:UpdateDepositButtonState()
    if not self.depositButton then
        return
    end

    local enabled = self:CanDepositWarboundItems()
    self.depositButton:SetEnabled(enabled)
    self.depositButton:SetAlpha(enabled and 1 or 0.5)
    self.depositButton:SetBackdropColor(0.08, 0.08, 0.1, enabled and 0.92 or 0.72)
    self.depositButton:SetBackdropBorderColor(enabled and 1 or 0.7, enabled and 1 or 0.7, enabled and 1 or 0.7, enabled and 0.12 or 0.08)
    if self.depositButtonText then
        self.depositButtonText:SetTextColor(enabled and 0.86 or 0.56, enabled and 0.9 or 0.58, enabled and 0.94 or 0.62, 1)
    end
end

function BankWindow:ConfigureDepositButtonTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["BANK_DEPOSIT_BUTTON"], 1, 1, 1)
    GameTooltip:AddLine(L["BANK_DEPOSIT_WARBAND_HINT"], 0.85, 0.85, 0.85, true)
    if self:CanDepositWarboundItems() then
        GameTooltip:AddLine(L["BAGS_LIVE"], 0.65, 0.92, 0.72)
    else
        GameTooltip:AddLine(L["BANK_DEPOSIT_WARBAND_UNAVAILABLE"], 0.92, 0.72, 0.72, true)
    end
    GameTooltip:Show()
end

function BankWindow:HandleDepositWarboundItems()
    if not self:CanDepositWarboundItems() then
        return
    end

    self:SetSelectedView("warband")
    C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Account)
end

function BankWindow:UpdateSearchPlaceholder()
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

function BankWindow:UpdateSearchClearButton(hasText)
    if not self.searchClearButton then
        return
    end

    local enabled = hasText and true or false
    self.searchClearButton:SetEnabled(enabled)
    self.searchClearButton:SetAlpha(enabled and 1 or 0.42)
end

function BankWindow:SetSearchQuery(text)
    self.searchQuery = normalizeSearchText(text)
    self:UpdateSearchPlaceholder()
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function BankWindow:ClearSearch()
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

function BankWindow:GetSearchTokens()
    if not self.searchQuery then
        return nil
    end

    local tokens = {}
    for token in self.searchQuery:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end

    return #tokens > 0 and tokens or nil
end

function BankWindow:RecordMatchesSearch(record, searchTokens)
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

function BankWindow:ApplySearchDimState(button, record, searchTokens)
    local matchesSearch = self:RecordMatchesSearch(record, searchTokens)
    button.searchMatched = matchesSearch
    button.icon:SetDesaturated((record.isLocked or not matchesSearch) and true or false)
    button:SetAlpha(matchesSearch and 1 or 0.24)
end

function BankWindow:GetSnapshotSearchMatchCount(snapshot, searchTokens)
    if not searchTokens or #searchTokens == 0 then
        return 0
    end

    local bank = type(snapshot) == "table" and snapshot.bank or nil
    local bags = type(bank) == "table" and bank.bags or nil
    if type(bags) ~= "table" then
        return 0
    end

    local matchCount = 0
    for _, bag in pairs(bags) do
        if type(bag) == "table" and type(bag.slots) == "table" then
            for slotID = 1, tonumber(bag.size) or 0 do
                local record = bag.slots[slotID]
                if type(record) == "table" and self:RecordMatchesSearch(record, searchTokens) then
                    matchCount = matchCount + 1
                end
            end
        end
    end

    return matchCount
end

function BankWindow:BuildCharacterSearchMatchCounts(searchTokens)
    if not searchTokens or #searchTokens == 0 then
        return nil
    end

    local store = self:GetStore()
    if not store or type(store.GetCharacterBankSnapshot) ~= "function" then
        return nil
    end

    local matchCounts = {}
    for i = 1, #self.displayCharacters do
        local character = self.displayCharacters[i]
        local snapshot = store:GetCharacterBankSnapshot(character.key)
        local matchCount = self:GetSnapshotSearchMatchCount(snapshot, searchTokens)
        if matchCount > 0 then
            matchCounts[character.key] = matchCount
        end
    end

    return matchCounts
end

function BankWindow:GetCombineRecordKey(record)
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

function BankWindow:BuildDisplayItems(items, viewSettings)
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

function BankWindow:CreateWindow()
    local bagsProfile = vesperTools:GetBagsProfile()
    local width = bagsProfile and bagsProfile.bankWindow.width or 900
    local height = bagsProfile and bagsProfile.bankWindow.height or 560

    local frame = CreateFrame("Frame", "vesperToolsBankWindow", UIParent, "BackdropTemplate")
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
    frame:SetBackdropColor(0.07, 0.07, 0.07, 0.95)

    local _, englishClass = UnitClass("player")
    local classColor = C_ClassColor.GetClassColor(englishClass)
    frame:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)

    if bagsProfile and bagsProfile.bankWindow then
        frame:SetPoint(
            bagsProfile.bankWindow.point,
            UIParent,
            bagsProfile.bankWindow.relativePoint,
            bagsProfile.bankWindow.xOfs,
            bagsProfile.bankWindow.yOfs
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
    titleText:SetText(L["BANK_TITLE"])
    vesperTools:ApplyConfiguredFont(titleText, vesperTools:GetConfiguredFontSize("roster", 12, 8, 24) + 4, "")
    self.titleText = titleText

    local modeText = titlebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modeText:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
    vesperTools:ApplyConfiguredFont(modeText, 12, "")
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
    vesperTools:ApplyConfiguredFont(searchBox, 12, "")
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

    local searchClearButton = vesperTools:CreateModernCloseButton(searchBox, function()
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
    searchPlaceholder:SetText(L["BANK_SEARCH_PLACEHOLDER"])
    vesperTools:ApplyConfiguredFont(searchPlaceholder, 12, "")
    self.searchPlaceholder = searchPlaceholder

    local closeButton = vesperTools:CreateModernCloseButton(titlebar, function()
        self:HideViewMenu()
        self:HideCharacterMenu()
        self:HandleCloseRequest()
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
        local bagsProfile = vesperTools:GetBagsProfile()
        local isActive = bagsProfile and bagsProfile.bankDisplay and bagsProfile.bankDisplay.combineStacks and true or false
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
    vesperTools:ApplyConfiguredFont(combineStacksButtonText, 11, "")
    self.combineStacksButtonText = combineStacksButtonText

    local depositButton = CreateFrame("Button", nil, navFrame, "BackdropTemplate")
    depositButton:SetPoint("RIGHT", combineStacksButton, "LEFT", -HEADER_ACTION_BUTTON_GAP, 0)
    depositButton:SetSize(DEPOSIT_BUTTON_WIDTH, HEADER_ACTION_BUTTON_HEIGHT)
    depositButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    depositButton:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    depositButton:SetBackdropBorderColor(1, 1, 1, 0.12)
    depositButton:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    depositButton:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    depositButton:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    depositButton:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)
    depositButton:SetScript("OnClick", function()
        self:HandleDepositWarboundItems()
    end)
    depositButton:SetScript("OnEnter", function(selfButton)
        self:ConfigureDepositButtonTooltip(selfButton)
    end)
    depositButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.depositButton = depositButton

    local depositButtonText = depositButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    depositButtonText:SetPoint("CENTER", 0, 0)
    depositButtonText:SetText(L["BANK_DEPOSIT_BUTTON"])
    vesperTools:ApplyConfiguredFont(depositButtonText, 11, "")
    self.depositButtonText = depositButtonText

    local viewDropdown = CreateFrame("Button", nil, navFrame, "BackdropTemplate")
    viewDropdown:SetPoint("LEFT", navFrame, "LEFT", 0, 0)
    viewDropdown:SetSize(VIEW_DROPDOWN_WIDTH, VIEW_DROPDOWN_HEIGHT)
    viewDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    viewDropdown:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    viewDropdown:SetBackdropBorderColor(1, 1, 1, 0.12)
    viewDropdown:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    viewDropdown:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    viewDropdown:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    viewDropdown:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)
    viewDropdown:SetScript("OnClick", function(selfButton)
        self:OpenViewMenu(selfButton)
    end)
    self.viewDropdown = viewDropdown

    local viewDropdownText = viewDropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    viewDropdownText:SetPoint("LEFT", viewDropdown, "LEFT", 8, 0)
    viewDropdownText:SetPoint("RIGHT", viewDropdown, "RIGHT", -24, 0)
    viewDropdownText:SetJustifyH("LEFT")
    viewDropdownText:SetJustifyV("MIDDLE")
    viewDropdownText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(viewDropdownText, 12, "")
    self.viewDropdownText = viewDropdownText

    local viewDropdownArrow = viewDropdown:CreateTexture(nil, "ARTWORK")
    viewDropdownArrow:SetPoint("RIGHT", viewDropdown, "RIGHT", -8, 0)
    viewDropdownArrow:SetSize(10, 10)
    viewDropdownArrow:SetTexture(VIEW_DROPDOWN_ARROW_TEXTURE)
    viewDropdownArrow:SetVertexColor(1, 1, 1, 0.98)
    self.viewDropdownArrow = viewDropdownArrow

    local characterDropdown = CreateFrame("Button", nil, navFrame, "BackdropTemplate")
    characterDropdown:SetPoint("LEFT", viewDropdown, "RIGHT", HEADER_ACTION_BUTTON_GAP, 0)
    characterDropdown:SetSize(CHARACTER_DROPDOWN_WIDTH, VIEW_DROPDOWN_HEIGHT)
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
    characterDropdownArrow:SetTexture(VIEW_DROPDOWN_ARROW_TEXTURE)
    characterDropdownArrow:SetVertexColor(1, 1, 1, 0.98)
    self.characterDropdownArrow = characterDropdownArrow

    local characterDropdownMatchText = characterDropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    characterDropdownMatchText:SetPoint("RIGHT", characterDropdownArrow, "LEFT", -4, 0)
    characterDropdownMatchText:SetJustifyH("RIGHT")
    characterDropdownMatchText:SetJustifyV("MIDDLE")
    characterDropdownMatchText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(characterDropdownMatchText, 11, "")
    characterDropdownMatchText:Hide()
    self.characterDropdownMatchText = characterDropdownMatchText

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", navFrame, "BOTTOMLEFT", 0, -10)
    content:SetSize(1, 1)
    self.content = content

    local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("TOPLEFT", 8, -8)
    emptyText:SetWidth(math.max(620, width - 60))
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText(L["BANK_EMPTY"])
    vesperTools:ApplyConfiguredFont(emptyText, 12, "")
    emptyText:Hide()
    self.emptyText = emptyText

    self.frame = frame
    frame:SetScript("OnHide", function()
        self:HideViewMenu()
        self:HideCharacterMenu()
        self:ClearSearch()
    end)
    self:UpdateSearchPlaceholder()
end

function BankWindow:BuildLayoutGroups(store, context, viewSettings)
    local groups = {}
    local maxItemCount = 0

    for i = 1, #context.categories do
        local category = context.categories[i]
        local items
        if context.viewKey == "warband" then
            items = store:GetWarbandCategoryItems(category.key)
        else
            items = store:GetCharacterBankCategoryItems(context.characterKey, category.key)
        end

        if #items > 0 then
            local displayItems = self:BuildDisplayItems(items, viewSettings)
            local hidden = self:IsCategoryCollapsed(context.collapseKey, category.key)
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

function BankWindow:MeasureContentHeight(groups, columns, viewSettings, hasSummary)
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

function BankWindow:GetHeaderMinimumFrameWidth(viewKey)
    local leftWidth = VIEW_DROPDOWN_WIDTH
    if viewKey == "character" then
        leftWidth = leftWidth + HEADER_ACTION_BUTTON_GAP + CHARACTER_DROPDOWN_WIDTH
    end

    local rightWidth = COMBINE_BUTTON_WIDTH
    if viewKey == "warband" then
        rightWidth = rightWidth + HEADER_ACTION_BUTTON_GAP + DEPOSIT_BUTTON_WIDTH
    end

    local requiredWidth = NAV_LEFT_INSET + leftWidth + rightWidth + NAV_RIGHT_INSET + HEADER_ACTION_BUTTON_GAP
    return math.max(MIN_WINDOW_WIDTH, requiredWidth)
end

function BankWindow:ResolveAutoLayout(groups, maxItemCount, viewSettings, viewKey)
    local screenWidth = UIParent:GetWidth() or 1920
    local minFrameWidth = self:GetHeaderMinimumFrameWidth(viewKey)
    local maxFrameWidth = math.max(minFrameWidth, math.floor(screenWidth - WINDOW_SCREEN_MARGIN))
    local maxContentWidth = math.max(minFrameWidth - 32, maxFrameWidth - 32)
    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local buttonGap = viewSettings and viewSettings.buttonGap or BUTTON_GAP
    local configuredColumns = viewSettings and viewSettings.columns or 10
    local maxColumns = math.max(1, math.floor((maxContentWidth - (CONTENT_SIDE_PADDING * 2) + buttonGap) / (itemIconSize + buttonGap)))
    local desiredColumns = maxItemCount > 0 and math.min(configuredColumns, maxItemCount) or 1
    local columns = clamp(desiredColumns, 1, maxColumns)

    local gridWidth = (CONTENT_SIDE_PADDING * 2) + (columns * itemIconSize) + (math.max(0, columns - 1) * buttonGap)
    local summaryWidth = (CONTENT_SIDE_PADDING * 2) + itemIconSize
    local contentWidth = math.max(gridWidth, summaryWidth)
    local contentHeight = self:MeasureContentHeight(groups, columns, viewSettings, true)
    local desiredWidth = math.max(minFrameWidth, contentWidth + 20)
    local desiredHeight = WINDOW_CHROME_HEIGHT + contentHeight
    local frameWidth = clamp(desiredWidth, minFrameWidth, maxFrameWidth)
    local frameHeight = math.max(MIN_WINDOW_HEIGHT, desiredHeight)
    contentWidth = math.max(contentWidth, frameWidth - 32)

    return {
        columns = columns,
        contentWidth = contentWidth,
        contentHeight = contentHeight,
        frameWidth = frameWidth,
        frameHeight = frameHeight,
    }
end

function BankWindow:AcquireSectionFrame()
    local index = #self.sectionFrames + 1
    local section = CreateFrame("Frame", nil, self.content)
    section:SetHeight(HEADER_HEIGHT)

    local toggleButton = CreateFrame("Button", nil, section)
    toggleButton:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -2)
    toggleButton:SetSize(CATEGORY_TOGGLE_BUTTON_SIZE, CATEGORY_TOGGLE_BUTTON_SIZE)
    toggleButton:RegisterForClicks("LeftButtonUp")
    toggleButton:SetHitRectInsets(-3, -3, -3, -3)
    toggleButton:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    toggleButton:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)

    local toggleIcon = toggleButton:CreateTexture(nil, "ARTWORK")
    toggleIcon:SetAllPoints()
    toggleIcon:SetTexture(VIEW_DROPDOWN_ARROW_TEXTURE)
    toggleIcon:SetVertexColor(1, 1, 1, 0.98)
    toggleButton.icon = toggleIcon
    section.toggleButton = toggleButton

    local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", toggleButton, "TOPRIGHT", 4, 1)
    title:SetPoint("RIGHT", section, "RIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(title, 14, "")
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

function BankWindow:AcquireItemButton()
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

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    vesperTools:ApplyConfiguredFont(count, 11, "OUTLINE")
    button.count = count

    local itemLevel = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemLevel:SetPoint("TOPLEFT", 3, -2)
    itemLevel:SetJustifyH("LEFT")
    vesperTools:ApplyConfiguredFont(itemLevel, 9, "OUTLINE")
    itemLevel:Hide()
    button.itemLevel = itemLevel

    self.itemButtons[#self.itemButtons + 1] = button
    return button
end

function BankWindow:AcquireSummaryButton()
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
    vesperTools:ApplyConfiguredFont(count, 13, "OUTLINE")
    button.count = count

    self.summaryButtons[#self.summaryButtons + 1] = button
    return button
end

function BankWindow:HideAllReusableFrames()
    for i = 1, #self.sectionFrames do
        self.sectionFrames[i]:Hide()
    end
    for i = 1, #self.itemButtons do
        self.itemButtons[i]:Hide()
    end
    for i = 1, #self.summaryButtons do
        self.summaryButtons[i]:Hide()
    end
end

function BankWindow:CanDisplayItemLevel(record)
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

function BankWindow:GetItemLevelForRecord(record)
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

function BankWindow:ConfigureTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.isLive and not button.isCombined and button.bagID and button.slotID then
        GameTooltip:SetBagItem(button.bagID, button.slotID)
    else
        if type(button.hyperlink) == "string" and button.hyperlink ~= "" then
            GameTooltip:SetHyperlink(button.hyperlink)
        else
            GameTooltip:SetText(button.itemName or buildFallbackItemName(button.itemID), 1, 1, 1)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format("%s: %s", button.isLive and L["BAGS_LIVE"] or L["BAGS_READ_ONLY"], button.ownerName or UNKNOWN), 0.85, 0.85, 0.85)
    if button.isCombined then
        GameTooltip:AddLine(string.format(L["BAGS_COMBINED_FROM_FMT"], tonumber(button.combinedStacks) or 1), 0.85, 0.85, 0.85)
        GameTooltip:AddLine(string.format(L["BAGS_TOTAL_ITEMS_FMT"], tonumber(button.totalCount) or tonumber(button.stackCount) or 0), 0.85, 0.85, 0.85)
    end
    GameTooltip:Show()
end

function BankWindow:ConfigureSummaryTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.summaryLabel or UNKNOWN, 1, 1, 1)
    GameTooltip:AddLine(tostring(button.summaryCount or 0), 0.85, 0.85, 0.85)
    GameTooltip:Show()
end

function BankWindow:HandleItemClick(button, mouseButton)
    if type(button.hyperlink) == "string" and button.hyperlink ~= "" and HandleModifiedItemClick and HandleModifiedItemClick(button.hyperlink) then
        return
    end

    if button.isCombined or not button.isLive or InCombatLockdown() then
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

function BankWindow:ConfigureItemButton(button, record, context, viewSettings)
    button.itemID = record.itemID
    button.itemName = record.itemName
    button.itemDescription = record.itemDescription
    button.searchText = record.searchText
    button.hyperlink = record.hyperlink
    button.isCombined = record.isCombined and true or false
    button.bagID = button.isCombined and nil or record.bagID
    button.slotID = button.isCombined and nil or record.slotID
    button.ownerName = context.ownerName
    button.isLive = context.isLive and true or false
    button.combinedStacks = tonumber(record.combinedStacks) or 1
    button.totalCount = tonumber(record.stackCount) or 1

    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local countFontSize = math.max(8, math.min(20, tonumber(viewSettings and viewSettings.stackCountFontSize) or 11))
    local itemLevelFontSize = math.max(8, math.min(18, tonumber(viewSettings and viewSettings.itemLevelFontSize) or 9))

    button:SetSize(itemIconSize, itemIconSize)
    vesperTools:ApplyConfiguredFont(button.count, countFontSize, "OUTLINE")
    vesperTools:ApplyConfiguredFont(button.itemLevel, itemLevelFontSize, "OUTLINE")

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
        if not selfButton.isCombined and selfButton.isLive and not InCombatLockdown() and C_Container and C_Container.PickupContainerItem then
            C_Container.PickupContainerItem(selfButton.bagID, selfButton.slotID)
        end
    end)
    button:SetScript("OnReceiveDrag", function(selfButton)
        if not selfButton.isCombined and selfButton.isLive and not InCombatLockdown() and C_Container and C_Container.PickupContainerItem then
            C_Container.PickupContainerItem(selfButton.bagID, selfButton.slotID)
        end
    end)
    self:ApplySearchDimState(button, record, self:GetSearchTokens())
    button:Show()
end

function BankWindow:ConfigureSummaryButton(button, summaryEntry, viewSettings)
    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local countFontSize = math.max(8, math.min(20, tonumber(viewSettings and viewSettings.stackCountFontSize) or 11))

    button:SetSize(itemIconSize, itemIconSize)
    button.summaryLabel = summaryEntry.label
    button.summaryCount = tonumber(summaryEntry.count) or 0
    button.icon:SetTexture(summaryEntry.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.count:SetText(tostring(button.summaryCount))
    button.count:SetTextColor(0.95, 0.95, 0.95, 1)
    vesperTools:ApplyConfiguredFont(button.count, countFontSize, "OUTLINE")
    button:SetScript("OnEnter", function(selfButton)
        self:ConfigureSummaryTooltip(selfButton)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:Show()
end

function BankWindow:ResolveViewContext(viewKey, selectedCharacter)
    local store = self:GetStore()
    if not store then
        return nil
    end

    if viewKey == "warband" then
        local snapshot = store:GetWarbandBankSnapshot()
        local hasSnapshot = type(snapshot) == "table" and (tonumber(snapshot.lastSeen) or 0) > 0
        local isLive = store:IsWarbandBankLive()
        if not isLive and not hasSnapshot then
            snapshot = nil
        end
        return {
            viewKey = "warband",
            collapseKey = "warband",
            label = L["BANK_SWITCH_WARBAND"],
            ownerName = L["BANK_SWITCH_WARBAND"],
            snapshot = snapshot,
            categories = snapshot and store:GetWarbandCategoryList() or {},
            emptySummary = snapshot and store:GetWarbandEmptySlotSummary() or {},
            isLive = isLive,
        }
    end

    local characterKey = selectedCharacter and selectedCharacter.key or nil
    local record = characterKey and store:GetCharacterBankSnapshot(characterKey) or nil
    local snapshot = record and record.bank or nil
    local isLive = selectedCharacter and selectedCharacter.isLive and true or false
    local hasSnapshot = type(snapshot) == "table" and (tonumber(snapshot.lastSeen) or 0) > 0
    if not isLive and not hasSnapshot then
        snapshot = nil
    end

    return {
        viewKey = "character",
        collapseKey = characterKey or "character",
        label = L["BANK_SWITCH_CHARACTER"],
        ownerName = selectedCharacter and selectedCharacter.fullName or (record and record.fullName) or vesperTools:GetCurrentCharacterFullName(),
        snapshot = snapshot,
        characterKey = characterKey,
        categories = snapshot and characterKey and store:GetCharacterBankCategoryList(characterKey) or {},
        emptySummary = snapshot and characterKey and store:GetCharacterBankEmptySlotSummary(characterKey) or {},
        isLive = isLive,
    }
end

function BankWindow:RefreshWindow()
    if not self.frame then
        return
    end

    local viewSettings = self:GetViewSettings()
    local selectedView = self:ResolveSelectedView()
    local selectedCharacter = selectedView and selectedView.key == "character" and self:ResolveSelectedCharacter() or nil
    self.characterSearchMatchCounts = selectedView and selectedView.key == "character" and self:BuildCharacterSearchMatchCounts(self:GetSearchTokens()) or nil

    self:UpdateCombineStacksButtonVisual(viewSettings.combineStacks)
    self:HideAllReusableFrames()

    if self.viewDropdown then
        if self.viewDropdownText then
            self.viewDropdownText:SetText(selectedView and selectedView.label or L["BANK_EMPTY"])
        end
        self:SetViewDropdownEnabled(selectedView ~= nil)
    end
    if self.characterDropdown then
        if selectedView and selectedView.key == "character" then
            self.characterDropdown:Show()
            if self.characterDropdownText then
                self.characterDropdownText:SetText(selectedCharacter and selectedCharacter.fullName or vesperTools:GetCurrentCharacterFullName())
            end
            self:UpdateSelectedCharacterDropdownMatch(selectedCharacter and selectedCharacter.key or nil)
            self:SetCharacterDropdownEnabled(selectedCharacter ~= nil and #self.displayCharacters > 1)
        else
            self:UpdateSelectedCharacterDropdownMatch(nil)
            self:HideCharacterMenu()
            self.characterDropdown:Hide()
        end
    end

    if self.depositButton then
        if selectedView and selectedView.key == "warband" then
            self.depositButton:Show()
            self:UpdateDepositButtonState()
        else
            GameTooltip:Hide()
            self.depositButton:Hide()
        end
    end

    self:UpdateViewDropdownVisual()
    self:UpdateCharacterDropdownVisual()
    if self.characterMenu and self.characterMenu:IsShown() then
        self:RefreshCharacterMenu()
    end

    local context = selectedView and self:ResolveViewContext(selectedView.key, selectedCharacter) or nil
    self.modeText:SetText(context and context.snapshot and (context.isLive and L["BAGS_LIVE"] or L["BAGS_READ_ONLY"]) or "")

    if not context or not context.snapshot then
        local minFrameWidth = self:GetHeaderMinimumFrameWidth(selectedView and selectedView.key or nil)
        self.emptyText:SetText(L["BANK_EMPTY"])
        self.emptyText:Show()
        self.frame:SetSize(minFrameWidth, MIN_WINDOW_HEIGHT)
        self.emptyText:SetWidth(minFrameWidth - 60)
        self.content:SetSize(minFrameWidth - 32, 40)
        self:SaveWindowState()
        return
    end

    local store = self:GetStore()
    local sectionIndex = 0
    local itemIndex = 0
    local summaryIndex = 0
    local groups, maxItemCount = self:BuildLayoutGroups(store, context, viewSettings)
    local layout = self:ResolveAutoLayout(groups, maxItemCount, viewSettings, selectedView and selectedView.key or nil)
    local contentWidth = layout.contentWidth
    local columns = layout.columns
    local slotPitch = viewSettings.itemIconSize + viewSettings.buttonGap
    self.frame:SetSize(layout.frameWidth, layout.frameHeight)
    self.emptyText:SetWidth(layout.frameWidth - 60)
    self:SaveWindowState()
    local yOffset = -8

    if #groups == 0 then
        self.emptyText:SetText(L["BANK_NO_ITEMS"])
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
                section.toggleButton.icon:SetRotation(math.pi)
                section.toggleButton.icon:SetVertexColor(0.8, 0.8, 0.8, 0.98)
            else
                section.title:SetText(string.format("%s (%d)", category.label, category.count))
                section.title:SetTextColor(1, 1, 1, 1)
                section.divider:SetColorTexture(1, 1, 1, 0.08)
                section.toggleButton.icon:SetRotation(0)
                section.toggleButton.icon:SetVertexColor(1, 1, 1, 0.98)
            end
            section.toggleButton:SetScript("OnClick", function()
                self:ToggleCategoryCollapsed(context.collapseKey, category.key)
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
                    self:ConfigureItemButton(button, items[itemPosition], context, viewSettings)

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

    for i = 1, #(context.emptySummary or {}) do
        summaryIndex = summaryIndex + 1
        local button = self.summaryButtons[summaryIndex] or self:AcquireSummaryButton()
        local x = CONTENT_SIDE_PADDING + ((i - 1) * slotPitch)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, yOffset)
        self:ConfigureSummaryButton(button, context.emptySummary[i], viewSettings)
    end

    self.content:SetSize(contentWidth, layout.contentHeight)
end
