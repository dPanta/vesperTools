local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local BagsWindow = vesperTools:NewModule("BagsWindow", "AceEvent-3.0")
local L = vesperTools.L
local ITEM_CLASS = Enum and Enum.ItemClass or {}

-- BagsWindow renders the carried-bag replacement UI.
-- It owns character switching, local/guild search, live item overlays, and bag-slot controls.
local MIN_WINDOW_WIDTH = 480
local MIN_WINDOW_HEIGHT = 220
local DEFAULT_BUTTON_SIZE = 38
local BUTTON_GAP = 6
local SECTION_GAP = 12
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
local TITLEBAR_SEARCH_GROUP_OFFSET_X = -14
local GUILD_LOOKUP_BUTTON_SIZE = 22
local GUILD_LOOKUP_BUTTON_GAP = 6
local TITLEBAR_BUTTON_GAP = 4
local LAYOUT_EDIT_BUTTON_SIZE = 20
local CATEGORY_TOGGLE_BUTTON_SIZE = 14
local CHARACTER_DROPDOWN_ARROW_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\DropdownArrow-50"
local GUILD_LOOKUP_ICON_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\GuildLookupChest-64"
local GUILD_LOOKUP_ICON_DISABLED_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\GuildLookupChest-64-Disabled"
local LAYOUT_EDIT_ICON_TEXTURE = "Interface\\AddOns\\vesperTools\\Media\\Cogwheel-64"
local GUILD_LOOKUP_RESULT_ROW_HEIGHT = 22
local GUILD_LOOKUP_RESULT_MAX_VISIBLE_ROWS = 8
local SECTION_TITLE_GAP = 4
local SECTION_TITLE_RIGHT_PADDING = 8
local CURRENCY_BAR_SIDE_PADDING = 8
local CURRENCY_BAR_VERTICAL_PADDING = 8
local CURRENCY_BAR_BUTTON_HEIGHT = 20
local CURRENCY_BAR_BUTTON_GAP = 6
local CURRENCY_BAR_BUTTON_PADDING = 6
local CURRENCY_BAR_BUTTON_MIN_WIDTH = 46
local CURRENCY_BAR_BUTTON_MAX_WIDTH = 96
local CURRENCY_BAR_ICON_SIZE = 16
local CURRENCY_BAR_ICON_GAP = 6
local LAYOUT_EDIT_SECTION_BACKGROUND_ALPHA = 0.14
local LAYOUT_EDIT_SECTION_BORDER_ALPHA = 0.32
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

local function applyConfiguredFontIfPresent(fontString, size, flags)
    if fontString then
        vesperTools:ApplyConfiguredFont(fontString, size, flags)
    end
end

local function formatCurrencyQuantity(quantity)
    local numericQuantity = math.max(0, math.floor((tonumber(quantity) or 0) + 0.5))
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(numericQuantity)
    end
    return tostring(numericQuantity)
end

local function formatGoldQuantity(copperAmount)
    local copper = math.max(0, math.floor((tonumber(copperAmount) or 0) + 0.5))
    local gold = math.floor(copper / (COPPER_PER_GOLD or 10000))
    return string.format("%sg", formatCurrencyQuantity(gold))
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

local function suppressNativeOverlayVisuals(overlay)
    if not overlay then
        return
    end

    overlay:SetAlpha(0)

    local normalTexture = overlay.GetNormalTexture and overlay:GetNormalTexture() or nil
    if normalTexture then
        normalTexture:SetAlpha(0)
        normalTexture:Hide()
    end

    local pushedTexture = overlay.GetPushedTexture and overlay:GetPushedTexture() or nil
    if pushedTexture then
        pushedTexture:SetAlpha(0)
        pushedTexture:Hide()
    end

    local highlightTexture = overlay.GetHighlightTexture and overlay:GetHighlightTexture() or nil
    if highlightTexture then
        highlightTexture:SetAlpha(0)
        highlightTexture:Hide()
    end

    local checkedTexture = overlay.GetCheckedTexture and overlay:GetCheckedTexture() or nil
    if checkedTexture then
        checkedTexture:SetAlpha(0)
        checkedTexture:Hide()
    end

    local regions = { overlay:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.SetAlpha then
            region:SetAlpha(0)
        end
        if region and region.Hide then
            region:Hide()
        end
    end

    local children = { overlay:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and child.SetAlpha then
            child:SetAlpha(0)
        end
        if child and child.Hide then
            child:Hide()
        end
    end
end

-- Module lifecycle and refresh entry points.
function BagsWindow:OnInitialize()
    self.frame = nil
    self.itemInteraction = nil
    self.titleText = nil
    self.modeText = nil
    self.searchBox = nil
    self.searchClearButton = nil
    self.searchPlaceholder = nil
    self.searchQuery = nil
    self.guildLookupButton = nil
    self.guildLookupButtonGlow = nil
    self.guildLookupButtonIcon = nil
    self.guildLookupResultsFrame = nil
    self.guildLookupResultsTitle = nil
    self.guildLookupResultsStatus = nil
    self.guildLookupResultsDivider = nil
    self.guildLookupResultsHeaders = nil
    self.guildLookupResultsScrollFrame = nil
    self.guildLookupResultsContent = nil
    self.guildLookupResultRows = {}
    self.layoutEditButton = nil
    self.layoutEditMode = false
    self.layoutPreviewFrame = nil
    self.layoutPreviewTitle = nil
    self.layoutGhostFrame = nil
    self.layoutGhostTitle = nil
    self.layoutDragDriver = nil
    self.layoutDragState = nil
    self.characterDropdown = nil
    self.characterDropdownText = nil
    self.characterDropdownMatchText = nil
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
    self.currencyBar = nil
    self.currencyBarDivider = nil
    self.emptyText = nil
    self.sectionFrames = {}
    self.itemButtons = {}
    self.equippedBagButtons = {}
    self.summaryButtons = {}
    self.currencyButtons = {}
    self.selectedCharacterKey = nil
    self.displayCharacters = {}
    self.characterSearchMatchCounts = nil
    self.currentDisplayCharacter = nil
    self.currentSnapshot = nil
    self.currentLayoutGroups = nil
    self.currentSectionLayout = nil
    self.currentSectionLayoutByKey = {}
    self.currentLayoutColumns = nil
    self.currentContentWidth = nil
    self.currentViewSettings = nil
    self.visibleSectionFramesByCategoryKey = {}
    self.newItemGlowKeysSeen = {}
    self.pendingSecureItemRefresh = false
end

function BagsWindow:OnEnable()
    self:RegisterMessage("VESPERTOOLS_BAGS_SNAPSHOT_UPDATED", "OnBagDataChanged")
    self:RegisterMessage("VESPERTOOLS_BAGS_CHARACTER_UPDATED", "OnBagDataChanged")
    self:RegisterMessage("VESPERTOOLS_BAGS_INDEX_UPDATED", "OnBagDataChanged")
    self:RegisterMessage("VESPERTOOLS_CONFIG_CHANGED", "OnConfigChanged")
    self:RegisterMessage("VESPERTOOLS_GUILD_LOOKUP_UPDATED", "OnGuildLookupUpdated")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnCurrencyDataChanged")
end

function BagsWindow:GetStore()
    return vesperTools:GetModule("BagsStore", true)
end

function BagsWindow:GetItemInteraction()
    if self.itemInteraction then
        return self.itemInteraction
    end

    if type(vesperTools.CreateContainerItemController) ~= "function" then
        return nil
    end

    self.itemInteraction = vesperTools:CreateContainerItemController(self, {
        assignContextToButton = function(_, button, context)
            button.isCurrentCharacter = context and context.isCurrentCharacter and true or false
        end,
        afterConfigureButton = function(window, button, record, context)
            local isCurrentCharacter = context and context.isCurrentCharacter and true or false

            if window:ShouldShowNewItemGlow(record, isCurrentCharacter) then
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

            window:ApplySearchDimState(button, record, window:GetSearchTokens())
        end,
    })

    return self.itemInteraction
end

function BagsWindow:GetGuildLookup()
    return vesperTools:GetModule("GuildLookup", true)
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

function BagsWindow:OnGuildLookupUpdated()
    self:RefreshGuildLookupPresentation()
end

function BagsWindow:OnCurrencyDataChanged()
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function BagsWindow:PLAYER_REGEN_ENABLED()
    if self.pendingSecureItemRefresh and self.frame and self.frame:IsShown() then
        self.pendingSecureItemRefresh = false
        self:RefreshWindow()
    end
end

function BagsWindow:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUI)
    if not isInitialLogin or isReloadingUI then
        return
    end

    C_Timer.After(0, function()
        if self:IsEnabled() then
            self:ClearCurrentCharacterNewItemMarkers(false)
        end
    end)
end

-- Window open/selection flow.
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

    local legacyFrame = _G["vesperToolsBagsWindowScrollFrame"]
    if legacyFrame then
        legacyFrame:Hide()
        legacyFrame:SetParent(nil)
    end

    local legacyBar = _G["vesperToolsBagsWindowScrollFrameScrollBar"] or _G["vesperToolsBagsWindowScrollBar"]
    if legacyBar then
        legacyBar:Hide()
        legacyBar:SetParent(nil)
    end
end

function BagsWindow:Toggle()
    if self.frame and self.frame:IsShown() then
        self:HandleCloseRequest()
        return
    end

    self:ShowWindow()
end

function BagsWindow:HandleCloseRequest()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    self:HideCharacterMenu()
    self:HideBagSlotsMenu()
    self.frame:Hide()
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

    local bagsProfile = vesperTools:GetBagsProfile()
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

    local bagsProfile = vesperTools:GetBagsProfile()
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
    local bagsProfile = vesperTools:GetBagsProfile()
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
        vesperTools:ApplyRoundedWindowBackdrop(menu)
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
        vesperTools:ApplyRoundedWindowBackdrop(menu)
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

function BagsWindow:UpdateSelectedCharacterDropdownMatch(characterKey)
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
    vesperTools:ApplyConfiguredFont(count, 11, "OUTLINE")
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

-- Persisted view state and per-character category collapse state.
function BagsWindow:SaveWindowState()
    if not self.frame then
        return
    end

    local bagsProfile = vesperTools:GetBagsProfile()
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
    local bagsProfile = vesperTools:GetBagsProfile()
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

    local bagsProfile = vesperTools:GetBagsProfile()
    if bagsProfile and bagsProfile.collapsedCategories then
        bagsProfile.collapsedCategories[characterKey] = nil
    end
end

function BagsWindow:ToggleCategoryCollapsed(characterKey, categoryKey)
    self:SetCategoryCollapsed(characterKey, categoryKey, not self:IsCategoryCollapsed(characterKey, categoryKey))
    self:RefreshWindow()
end

function BagsWindow:GetCategoryLayoutTable(create)
    local bagsProfile = vesperTools:GetBagsProfile()
    if not bagsProfile then
        return nil
    end

    bagsProfile.display = bagsProfile.display or {}
    if create and type(bagsProfile.display.categoryLayout) ~= "table" then
        bagsProfile.display.categoryLayout = {}
    end

    return type(bagsProfile.display.categoryLayout) == "table" and bagsProfile.display.categoryLayout or nil
end

function BagsWindow:GetCategoryLayoutEntry(categoryKey, create)
    if type(categoryKey) ~= "string" or categoryKey == "" then
        return nil
    end

    local layoutTable = self:GetCategoryLayoutTable(create)
    if not layoutTable then
        return nil
    end

    local entry = layoutTable[categoryKey]
    if create and type(entry) ~= "table" then
        entry = {}
        layoutTable[categoryKey] = entry
    elseif type(entry) ~= "table" then
        return nil
    end

    if entry.order ~= nil then
        local order = math.floor((tonumber(entry.order) or 0) + 0.5)
        entry.order = order > 0 and order or nil
    end

    if entry.span ~= nil then
        local span = math.floor((tonumber(entry.span) or 0) + 0.5)
        entry.span = span > 0 and span or nil
    end

    return entry
end

function BagsWindow:HasCustomCategoryLayout(groups)
    local layoutTable = self:GetCategoryLayoutTable(false)
    if type(layoutTable) ~= "table" then
        return false
    end

    if type(groups) == "table" and #groups > 0 then
        for i = 1, #groups do
            local category = groups[i].category
            if category and type(layoutTable[category.key]) == "table" then
                return true
            end
        end
        return false
    end

    return next(layoutTable) ~= nil
end

function BagsWindow:ResetCategoryLayout()
    local layoutTable = self:GetCategoryLayoutTable(false)
    if layoutTable then
        wipe(layoutTable)
    end

    self.layoutEditMode = false
    self:StopCategoryDrag(false)
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    else
        self:UpdateLayoutEditButtonVisual(false)
    end
end

function BagsWindow:SetLayoutEditMode(isActive)
    local active = isActive and true or false
    if self.layoutEditMode == active then
        self:UpdateLayoutEditButtonVisual(active)
        return
    end

    if not active then
        self:StopCategoryDrag(false)
    end

    self.layoutEditMode = active
    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    else
        self:UpdateLayoutEditButtonVisual(active)
    end
end

function BagsWindow:ToggleLayoutEditMode()
    self:SetLayoutEditMode(not self.layoutEditMode)
end

function BagsWindow:UpdateLayoutEditButtonVisual(isActive)
    if not self.layoutEditButton then
        return
    end

    local active = isActive and true or false
    self.layoutEditButton:SetBackdropColor(0.08, 0.08, 0.1, active and 0.98 or 0.92)
    self.layoutEditButton:SetBackdropBorderColor(active and 0.55 or 1, active and 0.84 or 1, active and 1 or 1, active and 0.42 or 0.12)
    if self.layoutEditButton.vgIconTexture then
        self.layoutEditButton.vgIconTexture:SetVertexColor(active and 0.94 or 1, active and 0.98 or 1, active and 1 or 1, active and 1 or 0.92)
    end
end

function BagsWindow:ConfigureLayoutEditButtonTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText("Arrange Categories", 1, 1, 1)
    GameTooltip:AddLine(self.layoutEditMode and "Layout edit mode is active." or "Left-click to edit the bag category layout.", 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine("Drag a category header to move it. Dropping into a tighter spot will resize it to fit.", 0.62, 0.84, 1, true)
    GameTooltip:AddLine("Shift-right-click resets the custom layout.", 0.85, 0.82, 0.52, true)
    GameTooltip:Show()
end

function BagsWindow:GetViewSettings()
    local bagsProfile = vesperTools:GetBagsProfile()
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

function BagsWindow:GetCurrencyBarEntries(selectedCharacter)
    local entries = {}
    local bagsProfile = vesperTools:GetBagsProfile()
    if not selectedCharacter
        or not selectedCharacter.isCurrent
        or not bagsProfile
        or not bagsProfile.display
        or not bagsProfile.display.showCurrencyBar
    then
        return entries
    end

    local goldEntry = vesperTools.GetGoldCurrencyBarEntry and vesperTools:GetGoldCurrencyBarEntry() or nil
    if goldEntry then
        entries[#entries + 1] = goldEntry
    end

    local selectedIDs = vesperTools:GetConfiguredBagCurrencyIDs()

    if #selectedIDs > 0 then
        for i = 1, #selectedIDs do
            local info = vesperTools:GetCurrencyInfoByID(selectedIDs[i])
            if info then
                entries[#entries + 1] = info
            end
        end
        return entries
    end

    local trackedOptions = vesperTools:GetTrackedBagCurrencyOptions()
    for i = 1, #trackedOptions do
        if trackedOptions[i] then
            entries[#entries + 1] = trackedOptions[i]
        end
    end

    return entries
end

function BagsWindow:GetCurrencyBarMeasureText()
    if self.currencyBarMeasureText then
        return self.currencyBarMeasureText
    end

    local parent = self.currencyBar or self.frame or UIParent
    local measureText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    measureText:SetWordWrap(false)
    measureText:Hide()
    self.currencyBarMeasureText = measureText
    return measureText
end

function BagsWindow:GetCurrencyBarButtonText(entry)
    if not entry then
        return "0"
    end

    if entry.isGold then
        return formatGoldQuantity(entry.quantity)
    end

    return formatCurrencyQuantity(entry.quantity)
end

function BagsWindow:GetCurrencyBarLayout(availableWidth, entries)
    local layout = {
        rows = 0,
        height = 0,
        buttons = {},
    }

    local count = type(entries) == "table" and #entries or 0
    if count <= 0 then
        return layout
    end

    local width = math.max(CURRENCY_BAR_BUTTON_MIN_WIDTH, math.floor((tonumber(availableWidth) or 0) + 0.5))
    local innerWidth = math.max(CURRENCY_BAR_BUTTON_MIN_WIDTH, width - (CURRENCY_BAR_SIDE_PADDING * 2))
    local measureText = self:GetCurrencyBarMeasureText()
    local row = 0
    local xOffset = 0

    vesperTools:ApplyConfiguredFont(measureText, 11, "")

    for index = 1, count do
        local buttonText = self:GetCurrencyBarButtonText(entries[index])
        measureText:SetText(buttonText)

        local buttonWidth = math.ceil(measureText:GetStringWidth() or 0)
            + (CURRENCY_BAR_BUTTON_PADDING * 2)
            + CURRENCY_BAR_ICON_SIZE
            + CURRENCY_BAR_ICON_GAP
        buttonWidth = clamp(buttonWidth, CURRENCY_BAR_BUTTON_MIN_WIDTH, math.min(CURRENCY_BAR_BUTTON_MAX_WIDTH, innerWidth))

        if xOffset > 0 and (xOffset + buttonWidth) > innerWidth then
            row = row + 1
            xOffset = 0
        end

        layout.buttons[index] = {
            row = row,
            xOffset = xOffset,
            width = buttonWidth,
            text = buttonText,
        }

        xOffset = xOffset + buttonWidth + CURRENCY_BAR_BUTTON_GAP
    end

    local rows = row + 1
    local height = CURRENCY_BAR_VERTICAL_PADDING
        + 1
        + CURRENCY_BAR_VERTICAL_PADDING
        + (rows * CURRENCY_BAR_BUTTON_HEIGHT)
        + (math.max(0, rows - 1) * CURRENCY_BAR_BUTTON_GAP)
        + CURRENCY_BAR_VERTICAL_PADDING

    layout.rows = rows
    layout.height = height
    return layout
end

function BagsWindow:ApplyConfiguredFonts()
    local titleFontSize = vesperTools:GetConfiguredFontSize("roster", 12, 8, 24) + 4

    applyConfiguredFontIfPresent(self.titleText, titleFontSize, "")
    applyConfiguredFontIfPresent(self.modeText, 12, "")
    applyConfiguredFontIfPresent(self.searchBox, 12, "")
    applyConfiguredFontIfPresent(self.searchPlaceholder, 12, "")
    applyConfiguredFontIfPresent(self.bagSlotsButtonText, 11, "")
    applyConfiguredFontIfPresent(self.cleanupButtonText, 11, "")
    applyConfiguredFontIfPresent(self.combineStacksButtonText, 11, "")
    applyConfiguredFontIfPresent(self.characterDropdownText, 12, "")
    applyConfiguredFontIfPresent(self.characterDropdownMatchText, 11, "")
    applyConfiguredFontIfPresent(self.emptyText, 12, "")
    applyConfiguredFontIfPresent(self.guildLookupResultsTitle, 12, "")
    applyConfiguredFontIfPresent(self.guildLookupResultsStatus, 11, "")
    applyConfiguredFontIfPresent(self.sectionTitleMeasureText, 14, "")
    applyConfiguredFontIfPresent(self.currencyBarMeasureText, 11, "")
    applyConfiguredFontIfPresent(self.layoutPreviewTitle, 14, "")
    applyConfiguredFontIfPresent(self.layoutGhostTitle, 14, "")

    if self.guildLookupResultsHeaders then
        applyConfiguredFontIfPresent(self.guildLookupResultsHeaders.item, 11, "")
        applyConfiguredFontIfPresent(self.guildLookupResultsHeaders.player, 11, "")
        applyConfiguredFontIfPresent(self.guildLookupResultsHeaders.count, 11, "")
    end

    for i = 1, #self.characterMenuButtons do
        local button = self.characterMenuButtons[i]
        if button then
            applyConfiguredFontIfPresent(button.text, 12, "")
            applyConfiguredFontIfPresent(button.matchText, 11, "")
        end
    end

    for i = 1, #self.bagSlotsMenuButtons do
        local button = self.bagSlotsMenuButtons[i]
        if button then
            applyConfiguredFontIfPresent(button.count, 11, "OUTLINE")
        end
    end

    for i = 1, #self.guildLookupResultRows do
        local row = self.guildLookupResultRows[i]
        if row then
            applyConfiguredFontIfPresent(row.itemText, 11, "")
            applyConfiguredFontIfPresent(row.countText, 11, "")
            applyConfiguredFontIfPresent(row.playerText, 11, "")
        end
    end

    for i = 1, #self.sectionFrames do
        local section = self.sectionFrames[i]
        if section then
            applyConfiguredFontIfPresent(section.title, 14, "")
        end
    end

    for i = 1, #self.currencyButtons do
        local button = self.currencyButtons[i]
        if button then
            applyConfiguredFontIfPresent(button.count, 11, "")
        end
    end
end

function BagsWindow:ToggleBagSlots()
    if not self.bagSlotsButton then
        return
    end

    self:OpenBagSlotsMenu(self.bagSlotsButton)
end

function BagsWindow:ToggleCombineStacks()
    local bagsProfile = vesperTools:GetBagsProfile()
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

-- Guild lookup controls and results rendering.
function BagsWindow:UpdateGuildLookupButtonVisual(isActive)
    if not self.guildLookupButton then
        return
    end

    local active = isActive and true or false
    self.guildLookupButton:SetBackdropColor(0.08, 0.08, 0.1, active and 0.98 or 0.92)
    self.guildLookupButton:SetBackdropBorderColor(active and 0.55 or 1, active and 0.84 or 1, active and 1 or 1, active and 0.42 or 0.12)
    if self.guildLookupButtonIcon then
        self.guildLookupButtonIcon:SetTexture(active and GUILD_LOOKUP_ICON_TEXTURE or GUILD_LOOKUP_ICON_DISABLED_TEXTURE)
    end
    if self.guildLookupButtonGlow then
        if active then
            self.guildLookupButtonGlow:Show()
            self.guildLookupButtonGlow:SetAlpha(0.2)
        else
            self.guildLookupButtonGlow:SetAlpha(0)
            self.guildLookupButtonGlow:Hide()
        end
    end
end

function BagsWindow:ConfigureGuildLookupButtonTooltip(button)
    local guildLookup = self:GetGuildLookup()
    local isActive = guildLookup and guildLookup:IsActive() or false
    local remainingCooldown = guildLookup and guildLookup:GetRemainingCooldown() or 0

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["BAGS_GUILD_LOOKUP"], 1, 1, 1)
    GameTooltip:AddLine(isActive and L["BAGS_GUILD_LOOKUP_ON"] or L["BAGS_GUILD_LOOKUP_OFF"], 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine(string.format(L["BAGS_GUILD_LOOKUP_MIN_CHARS_FMT"], guildLookup and guildLookup:GetMinimumQueryLength() or 4), 0.62, 0.84, 1, true)
    if not IsInGuild() then
        GameTooltip:AddLine(L["BAGS_GUILD_LOOKUP_RESULTS_UNAVAILABLE"], 1, 0.82, 0, true)
    elseif remainingCooldown > 0 then
        GameTooltip:AddLine(string.format(L["BAGS_GUILD_LOOKUP_COOLDOWN_FMT"], remainingCooldown), 1, 0.82, 0, true)
    else
        GameTooltip:AddLine(L["BAGS_GUILD_LOOKUP_ENTER_HINT"], 0.42, 0.94, 0.52, true)
    end
    GameTooltip:Show()
end

function BagsWindow:ToggleGuildLookup()
    local guildLookup = self:GetGuildLookup()
    if not guildLookup then
        return
    end

    guildLookup:ToggleActive()
end

function BagsWindow:CommitSearchInput()
    local text = self.searchBox and self.searchBox:GetText() or ""
    self:SetSearchQuery(text)

    local guildLookup = self:GetGuildLookup()
    if guildLookup and guildLookup:IsActive() then
        guildLookup:StartLookup(text)
    end
end

function BagsWindow:GetGuildLookupResultsFrame()
    if self.guildLookupResultsFrame then
        if self.frame and self.frame.GetFrameLevel then
            self.guildLookupResultsFrame:SetFrameLevel(math.max(90, (self.frame:GetFrameLevel() or 0) + 30))
        end
        return self.guildLookupResultsFrame
    end

    local resultsFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    resultsFrame:SetClampedToScreen(true)
    vesperTools:ApplyAddonWindowLayer(resultsFrame, self.frame and (self.frame:GetFrameLevel() or 0) + 30 or nil)
    vesperTools:ApplyRoundedWindowBackdrop(resultsFrame)
    resultsFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    resultsFrame:SetBackdropBorderColor(0.55, 0.84, 1, 0.24)
    resultsFrame:Hide()

    local title = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 10, -10)
    title:SetJustifyH("LEFT")
    title:SetText(L["BAGS_GUILD_LOOKUP_RESULTS_TITLE"])
    vesperTools:ApplyConfiguredFont(title, 12, "")
    self.guildLookupResultsTitle = title

    local status = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", -10, -11)
    status:SetWidth(280)
    status:SetJustifyH("RIGHT")
    status:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(status, 11, "")
    self.guildLookupResultsStatus = status

    local divider = resultsFrame:CreateTexture(nil, "BACKGROUND")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 8, -30)
    divider:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", -8, -30)
    divider:SetColorTexture(1, 1, 1, 0.08)
    self.guildLookupResultsDivider = divider

    local itemHeader = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemHeader:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 12, -41)
    itemHeader:SetJustifyH("LEFT")
    itemHeader:SetText(L["BAGS_GUILD_LOOKUP_ITEM"])
    vesperTools:ApplyConfiguredFont(itemHeader, 11, "")

    local countHeader = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countHeader:SetPoint("TOPRIGHT", resultsFrame, "TOPRIGHT", -38, -41)
    countHeader:SetWidth(44)
    countHeader:SetJustifyH("RIGHT")
    countHeader:SetText(L["BAGS_GUILD_LOOKUP_COUNT"])
    vesperTools:ApplyConfiguredFont(countHeader, 11, "")

    local playerHeader = resultsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    playerHeader:SetPoint("RIGHT", countHeader, "LEFT", -8, 0)
    playerHeader:SetWidth(160)
    playerHeader:SetJustifyH("LEFT")
    playerHeader:SetText(L["BAGS_GUILD_LOOKUP_PLAYER"])
    vesperTools:ApplyConfiguredFont(playerHeader, 11, "")

    self.guildLookupResultsHeaders = {
        item = itemHeader,
        player = playerHeader,
        count = countHeader,
    }

    local scrollFrame = CreateFrame("ScrollFrame", "vesperToolsGuildLookupResultsScrollFrame", resultsFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 8, -52)
    scrollFrame:SetPoint("BOTTOMRIGHT", resultsFrame, "BOTTOMRIGHT", -27, 8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(selfFrame, delta)
        local current = selfFrame:GetVerticalScroll() or 0
        local maximum = math.max(0, (selfFrame.contentHeight or 0) - (selfFrame:GetHeight() or 0))
        local step = GUILD_LOOKUP_RESULT_ROW_HEIGHT * 2
        local nextValue = math.max(0, math.min(maximum, current - (delta * step)))
        selfFrame:SetVerticalScroll(nextValue)
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame.child = scrollChild
    self.guildLookupResultsScrollFrame = scrollFrame
    self.guildLookupResultsContent = scrollChild

    self.guildLookupResultsFrame = resultsFrame
    return resultsFrame
end

function BagsWindow:AcquireGuildLookupResultRow()
    local parent = self.guildLookupResultsContent
    if not parent then
        return nil
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(GUILD_LOOKUP_RESULT_ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    row:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.18)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    icon:SetSize(16, 16)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local itemText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    itemText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    itemText:SetJustifyH("LEFT")
    itemText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(itemText, 11, "")
    row.itemText = itemText

    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    countText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    countText:SetWidth(44)
    countText:SetJustifyH("RIGHT")
    countText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(countText, 11, "")
    row.countText = countText

    local playerText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    playerText:SetPoint("RIGHT", countText, "LEFT", -8, 0)
    playerText:SetWidth(160)
    playerText:SetJustifyH("LEFT")
    playerText:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(playerText, 11, "")
    row.playerText = playerText

    itemText:SetPoint("RIGHT", playerText, "LEFT", -8, 0)

    self.guildLookupResultRows[#self.guildLookupResultRows + 1] = row
    return row
end

function BagsWindow:ConfigureGuildLookupResultRowTooltip(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if type(row.hyperlink) == "string" and row.hyperlink ~= "" then
        GameTooltip:SetHyperlink(row.hyperlink)
    else
        GameTooltip:SetText(row.itemName or buildFallbackItemName(row.itemID), 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L["BAGS_GUILD_LOOKUP_PLAYER"], row.playerName or UNKNOWN, 0.85, 0.85, 0.85, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["BAGS_GUILD_LOOKUP_COUNT"], tostring(row.itemCount or 0), 0.85, 0.85, 0.85, 1, 1, 1)
    GameTooltip:Show()
end

function BagsWindow:ConfigureGuildLookupResultRow(row, entry, availableWidth)
    local playerColumnWidth = math.max(120, math.floor((availableWidth or 420) * 0.3))
    row:SetSize(availableWidth, GUILD_LOOKUP_RESULT_ROW_HEIGHT)
    row.itemID = entry.itemID
    row.itemName = entry.itemName
    row.hyperlink = entry.hyperlink
    row.playerName = entry.sender
    row.itemCount = tonumber(entry.count) or 0
    row.icon:SetTexture(entry.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.itemText:SetText(entry.itemName or buildFallbackItemName(entry.itemID))
    row.playerText:SetWidth(playerColumnWidth)
    row.playerText:SetText(entry.sender or UNKNOWN)
    row.countText:SetText(tostring(row.itemCount))

    row:SetScript("OnEnter", function(selfRow)
        self:ConfigureGuildLookupResultRowTooltip(selfRow)
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(selfRow)
        if type(selfRow.hyperlink) == "string" and selfRow.hyperlink ~= "" and HandleModifiedItemClick then
            HandleModifiedItemClick(selfRow.hyperlink)
        end
    end)
    row:Show()
end

function BagsWindow:RefreshGuildLookupResultsFrame()
    local guildLookup = self:GetGuildLookup()
    local resultsFrame = self.guildLookupResultsFrame
    if not guildLookup or not self.frame or not self.frame:IsShown() then
        if resultsFrame then
            resultsFrame:Hide()
        end
        return
    end

    local state = guildLookup:GetDisplayState()
    if not (guildLookup:IsActive() and state and state.visible) then
        if resultsFrame then
            resultsFrame:Hide()
        end
        return
    end

    resultsFrame = self:GetGuildLookupResultsFrame()
    local results = state.results or {}
    local resultCount = #results
    local queryLabel = state.displayQueryText or state.queryText or ""
    local statusText = ""

    if state.status == "searching" then
        statusText = string.format(L["BAGS_GUILD_LOOKUP_SEARCHING_FMT"], queryLabel)
    elseif state.status == "too_short" then
        statusText = string.format(L["BAGS_GUILD_LOOKUP_MIN_CHARS_FMT"], guildLookup:GetMinimumQueryLength())
    elseif state.status == "cooldown" then
        statusText = string.format(L["BAGS_GUILD_LOOKUP_COOLDOWN_FMT"], guildLookup:GetRemainingCooldown() > 0 and guildLookup:GetRemainingCooldown() or (tonumber(state.cooldownRemaining) or 0))
    elseif state.status == "not_in_guild" then
        statusText = L["BAGS_GUILD_LOOKUP_RESULTS_UNAVAILABLE"]
    elseif state.status == "no_results" then
        statusText = string.format(L["BAGS_GUILD_LOOKUP_RESULTS_NONE_FMT"], queryLabel)
    else
        statusText = string.format(L["BAGS_GUILD_LOOKUP_RESULTS_COUNT_FMT"], resultCount, queryLabel)
    end

    if state.truncated then
        statusText = statusText .. " " .. L["BAGS_GUILD_LOOKUP_RESULTS_TRUNCATED"]
    end

    resultsFrame:ClearAllPoints()
    resultsFrame:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 10, 6)
    resultsFrame:SetPoint("BOTTOMRIGHT", self.frame, "TOPRIGHT", -10, 6)
    resultsFrame:SetFrameLevel(math.max(90, (self.frame:GetFrameLevel() or 0) + 30))

    local showRows = resultCount > 0
    local visibleRows = math.max(1, math.min(resultCount, GUILD_LOOKUP_RESULT_MAX_VISIBLE_ROWS))
    if showRows then
        resultsFrame:SetHeight(64 + (visibleRows * GUILD_LOOKUP_RESULT_ROW_HEIGHT))
    else
        resultsFrame:SetHeight(56)
    end

    if self.guildLookupResultsTitle then
        self.guildLookupResultsTitle:SetText(L["BAGS_GUILD_LOOKUP_RESULTS_TITLE"])
    end
    if self.guildLookupResultsStatus then
        self.guildLookupResultsStatus:SetWidth(math.max(180, math.floor((resultsFrame:GetWidth() or 420) * 0.58)))
        self.guildLookupResultsStatus:SetText(statusText)
    end

    if self.guildLookupResultsDivider then
        self.guildLookupResultsDivider:SetShown(showRows)
    end

    if self.guildLookupResultsHeaders then
        self.guildLookupResultsHeaders.item:SetShown(showRows)
        self.guildLookupResultsHeaders.player:SetShown(showRows)
        self.guildLookupResultsHeaders.count:SetShown(showRows)

        local usableWidth = math.max(240, math.floor((resultsFrame:GetWidth() or 420) - 30))
        self.guildLookupResultsHeaders.player:SetWidth(math.max(120, math.floor(usableWidth * 0.3)))
    end

    if self.guildLookupResultsScrollFrame and self.guildLookupResultsContent then
        if showRows then
            local contentWidth = math.max(240, math.floor((resultsFrame:GetWidth() or 420) - 42))
            self.guildLookupResultsScrollFrame:Show()
            self.guildLookupResultsContent:SetWidth(contentWidth)
            self.guildLookupResultsContent:SetHeight(math.max(1, resultCount * GUILD_LOOKUP_RESULT_ROW_HEIGHT))
            self.guildLookupResultsScrollFrame.contentHeight = resultCount * GUILD_LOOKUP_RESULT_ROW_HEIGHT
            local scrollKey = string.format("%s:%s", tostring(state.queryText or ""), tostring(state.requestSentAt or 0))
            if resultsFrame.lastScrollKey ~= scrollKey then
                self.guildLookupResultsScrollFrame:SetVerticalScroll(0)
                resultsFrame.lastScrollKey = scrollKey
            end

            for index = 1, resultCount do
                local row = self.guildLookupResultRows[index] or self:AcquireGuildLookupResultRow()
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self.guildLookupResultsContent, "TOPLEFT", 0, -((index - 1) * GUILD_LOOKUP_RESULT_ROW_HEIGHT))
                self:ConfigureGuildLookupResultRow(row, results[index], contentWidth)
            end

            for index = resultCount + 1, #self.guildLookupResultRows do
                self.guildLookupResultRows[index]:Hide()
            end
        else
            self.guildLookupResultsScrollFrame:SetVerticalScroll(0)
            self.guildLookupResultsScrollFrame.contentHeight = 0
            self.guildLookupResultsScrollFrame:Hide()
            resultsFrame.lastScrollKey = nil
            for index = 1, #self.guildLookupResultRows do
                self.guildLookupResultRows[index]:Hide()
            end
        end
    end

    resultsFrame:Show()
    resultsFrame:Raise()
end

function BagsWindow:RefreshGuildLookupPresentation()
    local guildLookup = self:GetGuildLookup()
    local isActive = guildLookup and guildLookup:IsActive() or false

    self:UpdateGuildLookupButtonVisual(isActive)

    if self.frame and self.frame:IsShown() then
        self:RefreshGuildLookupResultsFrame()
    elseif self.guildLookupResultsFrame then
        self.guildLookupResultsFrame:Hide()
    end
end

-- New-item marker ownership and cleanup.
function BagsWindow:CanClearCurrentCharacterNewItems()
    if not (C_NewItems and (C_NewItems.RemoveNewItem or C_NewItems.ClearAll)) then
        return false
    end

    local store = self:GetStore()
    if not store or not store.GetCurrentCharacterKey or not store.GetTrackedBagIDs then
        return false
    end

    local currentCharacterKey = store:GetCurrentCharacterKey()
    return type(currentCharacterKey) == "string"
        and currentCharacterKey ~= ""
end

function BagsWindow:CanClearNewItemsForSelectedCharacter()
    if not self:CanClearCurrentCharacterNewItems() then
        return false
    end

    local store = self:GetStore()
    local currentCharacterKey = store and store.GetCurrentCharacterKey and store:GetCurrentCharacterKey() or nil
    return currentCharacterKey == self.selectedCharacterKey
end

function BagsWindow:ClearCurrentCharacterNewItemMarkers(shouldRefreshWindow)
    if not self:CanClearCurrentCharacterNewItems() then
        return false
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
    if shouldRefreshWindow and self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end

    return true
end

function BagsWindow:ClearNewItemMarkers()
    if not self:CanClearNewItemsForSelectedCharacter() then
        return
    end

    self:ClearCurrentCharacterNewItemMarkers(true)
end

-- Search tokenization and local filtering.
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
    local guildLookup = self:GetGuildLookup()
    if guildLookup then
        guildLookup:ClearResults()
    end
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

function BagsWindow:GetSnapshotSearchMatchCount(snapshot, searchTokens)
    if not searchTokens or #searchTokens == 0 then
        return 0
    end

    local carried = type(snapshot) == "table" and snapshot.carried or nil
    local bags = type(carried) == "table" and carried.bags or nil
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

function BagsWindow:BuildCharacterSearchMatchCounts(searchTokens)
    if not searchTokens or #searchTokens == 0 then
        return nil
    end

    local store = self:GetStore()
    if not store or type(store.GetCharacterBagSnapshot) ~= "function" then
        return nil
    end

    local matchCounts = {}
    for i = 1, #self.displayCharacters do
        local character = self.displayCharacters[i]
        local snapshot = store:GetCharacterBagSnapshot(character.key)
        local matchCount = self:GetSnapshotSearchMatchCount(snapshot, searchTokens)
        if matchCount > 0 then
            matchCounts[character.key] = matchCount
        end
    end

    return matchCounts
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

-- Main frame construction and reusable widget pools.
function BagsWindow:CreateWindow()
    local bagsProfile = vesperTools:GetBagsProfile()
    local width = bagsProfile and bagsProfile.window.width or 900
    local height = bagsProfile and bagsProfile.window.height or 560

    local frame = CreateFrame("Frame", "vesperToolsBagsWindow", UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    vesperTools:ApplyAddonWindowLayer(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(false)
    frame:SetClampedToScreen(true)
    vesperTools:ApplyRoundedWindowBackdrop(frame)
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
    vesperTools:ApplyConfiguredFont(titleText, vesperTools:GetConfiguredFontSize("roster", 12, 8, 24) + 4, "")
    self.titleText = titleText

    local modeText = titlebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modeText:SetPoint("LEFT", titleText, "RIGHT", 10, 0)
    vesperTools:ApplyConfiguredFont(modeText, 12, "")
    self.modeText = modeText

    local searchBox = CreateFrame("EditBox", nil, titlebar, "BackdropTemplate")
    searchBox:SetPoint("CENTER", titlebar, "CENTER", TITLEBAR_SEARCH_GROUP_OFFSET_X, 0)
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
            local guildLookup = self:GetGuildLookup()
            if not (guildLookup and guildLookup:IsActive()) then
                self:SetSearchQuery(selfBox:GetText())
            end
        end
    end)
    searchBox:SetScript("OnEditFocusGained", function()
        self:UpdateSearchPlaceholder()
    end)
    searchBox:SetScript("OnEditFocusLost", function()
        self:UpdateSearchPlaceholder()
    end)
    searchBox:SetScript("OnEnterPressed", function(selfBox)
        local guildLookup = self:GetGuildLookup()
        if guildLookup and guildLookup:IsActive() then
            self:CommitSearchInput()
        end
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

    local guildLookupButton = CreateFrame("Button", nil, titlebar, "BackdropTemplate")
    guildLookupButton:SetPoint("LEFT", searchBox, "RIGHT", GUILD_LOOKUP_BUTTON_GAP, 0)
    guildLookupButton:SetSize(GUILD_LOOKUP_BUTTON_SIZE, GUILD_LOOKUP_BUTTON_SIZE)
    guildLookupButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    guildLookupButton:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    guildLookupButton:SetBackdropBorderColor(1, 1, 1, 0.12)
    guildLookupButton:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    guildLookupButton:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    guildLookupButton:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    guildLookupButton:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)
    guildLookupButton:SetScript("OnClick", function()
        self:ToggleGuildLookup()
    end)
    guildLookupButton:SetScript("OnEnter", function(selfButton)
        self:ConfigureGuildLookupButtonTooltip(selfButton)
    end)
    guildLookupButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.guildLookupButton = guildLookupButton

    local guildLookupButtonGlow = guildLookupButton:CreateTexture(nil, "BACKGROUND")
    guildLookupButtonGlow:SetPoint("TOPLEFT", guildLookupButton, "TOPLEFT", 1, -1)
    guildLookupButtonGlow:SetPoint("BOTTOMRIGHT", guildLookupButton, "BOTTOMRIGHT", -1, 1)
    guildLookupButtonGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    guildLookupButtonGlow:SetVertexColor(0.36, 0.66, 1, 1)
    guildLookupButtonGlow:SetBlendMode("ADD")
    guildLookupButtonGlow:SetAlpha(0)
    guildLookupButtonGlow:Hide()
    self.guildLookupButtonGlow = guildLookupButtonGlow

    local guildLookupButtonIcon = guildLookupButton:CreateTexture(nil, "ARTWORK")
    guildLookupButtonIcon:SetPoint("TOPLEFT", guildLookupButton, "TOPLEFT", 3, -3)
    guildLookupButtonIcon:SetPoint("BOTTOMRIGHT", guildLookupButton, "BOTTOMRIGHT", -3, 3)
    guildLookupButtonIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    guildLookupButtonIcon:SetTexture(GUILD_LOOKUP_ICON_DISABLED_TEXTURE)
    self.guildLookupButtonIcon = guildLookupButtonIcon

    local searchPlaceholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    searchPlaceholder:SetPoint("RIGHT", searchClearButton, "LEFT", -4, 0)
    searchPlaceholder:SetJustifyH("LEFT")
    searchPlaceholder:SetJustifyV("MIDDLE")
    searchPlaceholder:SetWordWrap(false)
    searchPlaceholder:SetText(L["BAGS_SEARCH_PLACEHOLDER"])
    vesperTools:ApplyConfiguredFont(searchPlaceholder, 12, "")
    self.searchPlaceholder = searchPlaceholder

    local closeButton = vesperTools:CreateModernCloseButton(titlebar, function()
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

    local layoutEditButton = vesperTools:CreateModernCloseButton(titlebar, function(_, mouseButton)
        if mouseButton == "RightButton" and IsShiftKeyDown and IsShiftKeyDown() then
            self:ResetCategoryLayout()
            return
        end

        self:ToggleLayoutEditMode()
    end, {
        size = LAYOUT_EDIT_BUTTON_SIZE,
        iconScale = 0.7,
        backgroundAlpha = 0.04,
        borderAlpha = 0.08,
        hoverAlpha = 0.12,
        pressedAlpha = 0.18,
        iconTexture = LAYOUT_EDIT_ICON_TEXTURE,
        clicks = { "LeftButtonUp", "RightButtonUp" },
    })
    layoutEditButton:SetPoint("RIGHT", closeButton, "LEFT", -TITLEBAR_BUTTON_GAP, 0)
    layoutEditButton:HookScript("OnEnter", function(selfButton)
        self:ConfigureLayoutEditButtonTooltip(selfButton)
    end)
    layoutEditButton:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.layoutEditButton = layoutEditButton
    self:UpdateLayoutEditButtonVisual(false)

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
    vesperTools:ApplyConfiguredFont(bagSlotsButtonText, 11, "")
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
    vesperTools:ApplyConfiguredFont(cleanupButtonText, 11, "")
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
        local bagsProfile = vesperTools:GetBagsProfile()
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
    vesperTools:ApplyConfiguredFont(combineStacksButtonText, 11, "")
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
    vesperTools:ApplyConfiguredFont(characterDropdownText, 12, "")
    self.characterDropdownText = characterDropdownText

    local characterDropdownArrow = characterDropdown:CreateTexture(nil, "ARTWORK")
    characterDropdownArrow:SetPoint("RIGHT", characterDropdown, "RIGHT", -8, 0)
    characterDropdownArrow:SetSize(10, 10)
    characterDropdownArrow:SetTexture(CHARACTER_DROPDOWN_ARROW_TEXTURE)
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
    emptyText:SetText(L["BAGS_EMPTY"])
    vesperTools:ApplyConfiguredFont(emptyText, 12, "")
    emptyText:Hide()
    self.emptyText = emptyText

    local currencyBar = CreateFrame("Frame", nil, frame)
    currencyBar:SetPoint("LEFT", frame, "LEFT", 10, 0)
    currencyBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    currencyBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
    currencyBar:SetHeight(1)
    currencyBar:Hide()
    self.currencyBar = currencyBar

    local currencyBarDivider = currencyBar:CreateTexture(nil, "BACKGROUND")
    currencyBarDivider:SetPoint("TOPLEFT", currencyBar, "TOPLEFT", 0, 0)
    currencyBarDivider:SetPoint("TOPRIGHT", currencyBar, "TOPRIGHT", 0, 0)
    currencyBarDivider:SetHeight(1)
    currencyBarDivider:SetColorTexture(1, 1, 1, 0.08)
    self.currencyBarDivider = currencyBarDivider

    self.frame = frame
    vesperTools:RegisterEscapeFrame(frame, function()
        self:HandleCloseRequest()
    end)
    frame:SetScript("OnHide", function()
        self.layoutEditMode = false
        self:StopCategoryDrag(false)
        self:HideCharacterMenu()
        self:HideBagSlotsMenu()
        self:ClearSearch()
        self:UpdateLayoutEditButtonVisual(false)
        self:RefreshGuildLookupPresentation()
    end)
    self:UpdateSearchPlaceholder()
    self:RefreshGuildLookupPresentation()
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

function BagsWindow:GetSlotPitch(viewSettings)
    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local buttonGap = viewSettings and viewSettings.buttonGap or BUTTON_GAP
    return itemIconSize + buttonGap
end

function BagsWindow:GetSectionTitleMeasureText()
    if self.sectionTitleMeasureText then
        return self.sectionTitleMeasureText
    end

    local parent = self.frame or UIParent
    local measureText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    measureText:SetWordWrap(false)
    measureText:Hide()
    self.sectionTitleMeasureText = measureText
    return measureText
end

function BagsWindow:GetSectionTitleText(group)
    local category = group and group.category
    if not category then
        return ""
    end

    if group.hidden then
        return string.format("%s (%d) (%s)", category.label, category.count, L["BAGS_HIDDEN"])
    end

    return string.format("%s (%d)", category.label, category.count)
end

function BagsWindow:GetSectionTitleContentWidth(group)
    if type(group) ~= "table" then
        return 0
    end

    local measureText = self:GetSectionTitleMeasureText()
    vesperTools:ApplyConfiguredFont(measureText, 14, "")
    measureText:SetText(self:GetSectionTitleText(group))

    return CATEGORY_TOGGLE_BUTTON_SIZE
        + SECTION_TITLE_GAP
        + math.ceil(measureText:GetStringWidth() or 0)
        + SECTION_TITLE_RIGHT_PADDING
end

function BagsWindow:GetMinimumSectionSpan(group, columns, viewSettings)
    local buttonGap = viewSettings and viewSettings.buttonGap or BUTTON_GAP
    local slotPitch = self:GetSlotPitch(viewSettings)
    local minimumSpan = math.max(1, math.ceil((self:GetSectionTitleContentWidth(group) + buttonGap) / slotPitch))
    return clamp(minimumSpan, 1, math.max(1, columns or 1))
end

function BagsWindow:GetDefaultSectionSpan(group, columns, viewSettings, minimumSpan)
    local itemCount = type(group) == "table" and type(group.items) == "table" and #group.items or 0
    local naturalSpan = math.max(1, math.min(columns or 1, itemCount > 0 and itemCount or 1))
    return clamp(math.max(minimumSpan or 1, naturalSpan), 1, math.max(1, columns or 1))
end

function BagsWindow:PrepareLayoutGroups(groups, columns, viewSettings)
    if type(groups) ~= "table" or #groups == 0 then
        return groups or {}
    end

    for i = 1, #groups do
        local group = groups[i]
        group.sourceOrder = i

        local layoutEntry = group.category and self:GetCategoryLayoutEntry(group.category.key, false) or nil
        local minimumSpan = self:GetMinimumSectionSpan(group, columns, viewSettings)
        group.minSpan = minimumSpan
        group.defaultSpan = self:GetDefaultSectionSpan(group, columns, viewSettings, minimumSpan)

        local savedOrder = layoutEntry and math.floor((tonumber(layoutEntry.order) or 0) + 0.5) or nil
        local savedSpan = layoutEntry and math.floor((tonumber(layoutEntry.span) or 0) + 0.5) or nil
        group.layoutOrder = savedOrder and savedOrder > 0 and savedOrder or nil
        group.savedSpan = savedSpan and savedSpan > 0 and savedSpan or nil
    end

    table.sort(groups, function(a, b)
        local aOrder = a.layoutOrder or (100000 + (a.sourceOrder or 0))
        local bOrder = b.layoutOrder or (100000 + (b.sourceOrder or 0))
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end

        return (a.sourceOrder or 0) < (b.sourceOrder or 0)
    end)

    for i = 1, #groups do
        local group = groups[i]
        group.span = clamp(group.savedSpan or group.defaultSpan or 1, group.minSpan or 1, math.max(1, columns or 1))
    end

    return groups
end

function BagsWindow:GetSectionFrameWidth(group, viewSettings)
    if type(group) ~= "table" then
        return 0
    end

    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local buttonGap = viewSettings and viewSettings.buttonGap or BUTTON_GAP
    local span = math.max(1, math.floor((tonumber(group.span) or 1) + 0.5))
    return (span * itemIconSize) + (math.max(0, span - 1) * buttonGap)
end

function BagsWindow:GetMinimumSectionContentWidth(groups, viewSettings)
    if type(groups) ~= "table" or #groups == 0 then
        return 0
    end

    local widestSectionWidth = 0
    for i = 1, #groups do
        widestSectionWidth = math.max(widestSectionWidth, self:GetSectionFrameWidth(groups[i], viewSettings))
    end

    return (CONTENT_SIDE_PADDING * 2) + widestSectionWidth
end

function BagsWindow:BuildSectionLayout(groups, contentWidth, columns, viewSettings)
    if type(groups) ~= "table" or #groups == 0 then
        return {}, 0
    end

    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local buttonGap = viewSettings and viewSettings.buttonGap or BUTTON_GAP
    local slotPitch = self:GetSlotPitch(viewSettings)
    local placements = {}
    local rowColumn = 0
    local rowTop = 8
    local rowHeight = 0

    for i = 1, #groups do
        local group = groups[i]
        local span = clamp(math.max(1, tonumber(group.span) or 1), 1, math.max(1, columns or 1))
        group.span = span

        local rows = not group.hidden and math.max(1, math.ceil(#group.items / span)) or 0
        local itemHeight = rows > 0 and ((rows * itemIconSize) + (math.max(0, rows - 1) * buttonGap)) or 0
        local sectionWidth = self:GetSectionFrameWidth(group, viewSettings)
        local sectionHeight = HEADER_HEIGHT + itemHeight

        if rowColumn > 0 and (rowColumn + span) > columns then
            rowTop = rowTop + rowHeight + SECTION_GAP
            rowColumn = 0
            rowHeight = 0
        end

        placements[i] = {
            x = CONTENT_SIDE_PADDING + (rowColumn * slotPitch),
            y = -rowTop,
            width = sectionWidth,
            height = sectionHeight,
            columns = span,
            startColumn = rowColumn + 1,
            endColumn = rowColumn + span,
        }

        rowColumn = rowColumn + span
        rowHeight = math.max(rowHeight, sectionHeight)
    end

    return placements, rowTop + rowHeight
end

function BagsWindow:MeasureContentHeight(groups, sectionsHeight, viewSettings, hasSummary)
    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local height

    if type(groups) ~= "table" or #groups == 0 then
        height = 8 + 28
    else
        height = sectionsHeight or 0
    end

    if hasSummary then
        height = height + itemIconSize + SUMMARY_GAP
    end

    return height + 12
end

function BagsWindow:ResolveAutoLayout(groups, maxItemCount, viewSettings, currencyEntries)
    local screenWidth = UIParent:GetWidth() or 1920
    local maxFrameWidth = math.max(MIN_WINDOW_WIDTH, math.floor(screenWidth - WINDOW_SCREEN_MARGIN))
    local maxContentWidth = math.max(MIN_WINDOW_WIDTH - 32, maxFrameWidth - 32)
    local itemIconSize = viewSettings and viewSettings.itemIconSize or DEFAULT_BUTTON_SIZE
    local buttonGap = viewSettings and viewSettings.buttonGap or BUTTON_GAP
    local configuredColumns = viewSettings and viewSettings.columns or 10
    local maxColumns = math.max(1, math.floor((maxContentWidth - (CONTENT_SIDE_PADDING * 2) + buttonGap) / (itemIconSize + buttonGap)))
    local columns = clamp(configuredColumns, 1, maxColumns)
    local preparedGroups = self:PrepareLayoutGroups(groups, columns, viewSettings)

    local gridWidth = (CONTENT_SIDE_PADDING * 2) + (columns * itemIconSize) + (math.max(0, columns - 1) * buttonGap)
    local summaryWidth = (CONTENT_SIDE_PADDING * 2) + (itemIconSize * 2) + buttonGap
    local sectionWidth = self:GetMinimumSectionContentWidth(preparedGroups, viewSettings)
    local contentWidth = math.max(gridWidth, summaryWidth, sectionWidth)
    local desiredWidth = math.max(MIN_WINDOW_WIDTH, contentWidth + 20)
    local frameWidth = clamp(desiredWidth, MIN_WINDOW_WIDTH, maxFrameWidth)
    contentWidth = math.max(contentWidth, frameWidth - 32)
    local sectionLayout, sectionsHeight = self:BuildSectionLayout(preparedGroups, contentWidth, columns, viewSettings)
    local contentHeight = self:MeasureContentHeight(preparedGroups, sectionsHeight, viewSettings, true)
    local desiredHeight = WINDOW_CHROME_HEIGHT + contentHeight
    local currencyBarLayout = self:GetCurrencyBarLayout(frameWidth - 20, currencyEntries)
    local frameHeight = math.max(MIN_WINDOW_HEIGHT, desiredHeight + currencyBarLayout.height)

    return {
        groups = preparedGroups,
        columns = columns,
        contentWidth = contentWidth,
        contentHeight = contentHeight,
        frameWidth = frameWidth,
        frameHeight = frameHeight,
        sectionLayout = sectionLayout,
        sectionsHeight = sectionsHeight,
        currencyBarLayout = currencyBarLayout,
    }
end

function BagsWindow:AcquireSectionFrame()
    local index = #self.sectionFrames + 1
    local section = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
    section:SetHeight(HEADER_HEIGHT)
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    section:SetBackdropColor(0.12, 0.18, 0.26, 0)
    section:SetBackdropBorderColor(0.55, 0.84, 1, 0)

    local toggleButton = CreateFrame("Button", nil, section)
    toggleButton:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -2)
    toggleButton:SetSize(CATEGORY_TOGGLE_BUTTON_SIZE, CATEGORY_TOGGLE_BUTTON_SIZE)
    toggleButton:RegisterForClicks("LeftButtonUp")
    toggleButton:SetHitRectInsets(-3, -3, -3, -3)
    toggleButton:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    toggleButton:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)

    local toggleIcon = toggleButton:CreateTexture(nil, "ARTWORK")
    toggleIcon:SetAllPoints()
    toggleIcon:SetTexture(CHARACTER_DROPDOWN_ARROW_TEXTURE)
    toggleIcon:SetVertexColor(1, 1, 1, 0.98)
    toggleButton.icon = toggleIcon
    section.toggleButton = toggleButton

    local dragOverlay = CreateFrame("Button", nil, section)
    dragOverlay:SetPoint("TOPLEFT", toggleButton, "TOPRIGHT", 2, 0)
    dragOverlay:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
    dragOverlay:SetHeight(HEADER_HEIGHT)
    dragOverlay:RegisterForDrag("LeftButton")
    dragOverlay:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    dragOverlay:GetHighlightTexture():SetVertexColor(0.36, 0.66, 1, 0.12)
    dragOverlay.window = self
    dragOverlay:EnableMouse(false)
    dragOverlay:SetScript("OnDragStart", function(selfButton)
        local window = selfButton.window
        local parentSection = selfButton:GetParent()
        if window and window.layoutEditMode and parentSection and parentSection.categoryKey then
            window:StartCategoryDrag(parentSection.categoryKey)
        end
    end)
    section.dragOverlay = dragOverlay

    local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", toggleButton, "TOPRIGHT", 4, 1)
    title:SetPoint("RIGHT", section, "RIGHT", 0, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(title, 14, "")
    section.title = title

    self.sectionFrames[index] = section
    return section
end

function BagsWindow:EnsureLayoutDragFrames()
    if self.layoutPreviewFrame and self.layoutGhostFrame and self.layoutDragDriver then
        return
    end

    local previewFrame = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
    previewFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    previewFrame:SetBackdropColor(0.16, 0.26, 0.38, 0.18)
    previewFrame:SetBackdropBorderColor(0.55, 0.84, 1, 0.5)
    previewFrame:SetFrameLevel((self.content:GetFrameLevel() or 0) + 24)
    previewFrame:Hide()
    self.layoutPreviewFrame = previewFrame

    local previewTitle = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    previewTitle:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", CATEGORY_TOGGLE_BUTTON_SIZE + SECTION_TITLE_GAP + 4, -4)
    previewTitle:SetPoint("RIGHT", previewFrame, "RIGHT", -6, 0)
    previewTitle:SetJustifyH("LEFT")
    previewTitle:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(previewTitle, 14, "")
    self.layoutPreviewTitle = previewTitle

    local ghostFrame = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
    ghostFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    ghostFrame:SetBackdropColor(0.14, 0.22, 0.3, 0.72)
    ghostFrame:SetBackdropBorderColor(0.55, 0.84, 1, 0.42)
    ghostFrame:SetFrameLevel((self.content:GetFrameLevel() or 0) + 26)
    ghostFrame:Hide()
    self.layoutGhostFrame = ghostFrame

    local ghostTitle = ghostFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ghostTitle:SetPoint("TOPLEFT", ghostFrame, "TOPLEFT", CATEGORY_TOGGLE_BUTTON_SIZE + SECTION_TITLE_GAP + 4, -4)
    ghostTitle:SetPoint("RIGHT", ghostFrame, "RIGHT", -6, 0)
    ghostTitle:SetJustifyH("LEFT")
    ghostTitle:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(ghostTitle, 14, "")
    self.layoutGhostTitle = ghostTitle

    local dragDriver = CreateFrame("Frame", nil, self.frame)
    dragDriver:SetAllPoints(self.frame)
    dragDriver:Hide()
    dragDriver:SetScript("OnUpdate", function()
        self:UpdateCategoryDrag()
    end)
    self.layoutDragDriver = dragDriver
end

function BagsWindow:CloneLayoutGroup(group)
    if type(group) ~= "table" then
        return nil
    end

    local clone = {}
    for key, value in pairs(group) do
        clone[key] = value
    end
    return clone
end

function BagsWindow:BuildCandidateGroupList(baseGroups, draggedGroup, insertIndex, span)
    local candidateGroups = {}

    for i = 1, (#baseGroups + 1) do
        if i == insertIndex then
            local inserted = self:CloneLayoutGroup(draggedGroup)
            inserted.span = span
            candidateGroups[#candidateGroups + 1] = inserted
        end

        local source = baseGroups[i > insertIndex and (i - 1) or i]
        if source then
            candidateGroups[#candidateGroups + 1] = self:CloneLayoutGroup(source)
        end
    end

    return candidateGroups
end

function BagsWindow:GetCursorPositionInContent()
    if not self.content then
        return nil
    end

    local left = self.content:GetLeft()
    local top = self.content:GetTop()
    local scale = self.content:GetEffectiveScale()
    if not left or not top or not scale or scale == 0 then
        return nil
    end

    local cursorX, cursorY = GetCursorPosition()
    cursorX = cursorX / scale
    cursorY = cursorY / scale
    return cursorX - left, top - cursorY
end

function BagsWindow:GetLayoutCandidateScore(placement, cursorX, cursorY)
    if type(placement) ~= "table" then
        return math.huge
    end

    local left = placement.x or 0
    local right = left + (placement.width or 0)
    local top = -(placement.y or 0)
    local bottom = top + (placement.height or 0)

    local outsideX = 0
    if cursorX < left then
        outsideX = left - cursorX
    elseif cursorX > right then
        outsideX = cursorX - right
    end

    local outsideY = 0
    if cursorY < top then
        outsideY = top - cursorY
    elseif cursorY > bottom then
        outsideY = cursorY - bottom
    end

    local centerX = left + ((placement.width or 0) * 0.5)
    local centerY = top + ((placement.height or 0) * 0.5)
    local centerDistance = ((centerX - cursorX) * (centerX - cursorX)) + ((centerY - cursorY) * (centerY - cursorY))
    local outsideDistance = ((outsideX * outsideX) + (outsideY * outsideY)) * 10000
    return outsideDistance + centerDistance
end

function BagsWindow:BuildBestLayoutDropCandidate(cursorX, cursorY)
    local dragState = self.layoutDragState
    local groups = self.currentLayoutGroups
    local columns = self.currentLayoutColumns
    local viewSettings = self.currentViewSettings
    if not dragState or type(groups) ~= "table" or not columns or not viewSettings then
        return nil
    end

    local draggedGroup = nil
    local baseGroups = {}
    for i = 1, #groups do
        local group = groups[i]
        if group.category and group.category.key == dragState.categoryKey then
            draggedGroup = self:CloneLayoutGroup(group)
        else
            baseGroups[#baseGroups + 1] = self:CloneLayoutGroup(group)
        end
    end

    if not draggedGroup then
        return nil
    end

    local minimumSpan = math.max(1, draggedGroup.minSpan or 1)
    local bestCandidate = nil
    local bestScore = nil

    for insertIndex = 1, (#baseGroups + 1) do
        for span = minimumSpan, columns do
            local candidateGroups = self:BuildCandidateGroupList(baseGroups, draggedGroup, insertIndex, span)
            local sectionLayout, sectionsHeight = self:BuildSectionLayout(candidateGroups, self.currentContentWidth, columns, viewSettings)
            local placement = sectionLayout[insertIndex]
            local score = self:GetLayoutCandidateScore(placement, cursorX, cursorY)
            if not bestScore or score < bestScore then
                bestScore = score
                bestCandidate = {
                    groups = candidateGroups,
                    placement = placement,
                    sectionsHeight = sectionsHeight,
                    span = span,
                    insertIndex = insertIndex,
                    columns = columns,
                }
            end
        end
    end

    return bestCandidate
end

function BagsWindow:ApplyCategoryLayoutCandidate(candidate)
    if type(candidate) ~= "table" or type(candidate.groups) ~= "table" then
        return
    end

    local columns = math.max(1, math.floor((tonumber(candidate.columns) or 1) + 0.5))
    for i = 1, #candidate.groups do
        local group = candidate.groups[i]
        if group and group.category and group.category.key then
            local entry = self:GetCategoryLayoutEntry(group.category.key, true)
            if entry then
                entry.order = i
                entry.span = clamp(math.floor((tonumber(group.span) or 1) + 0.5), math.max(1, group.minSpan or 1), columns)
            end
        end
    end

    if self.frame and self.frame:IsShown() then
        self:RefreshWindow()
    end
end

function BagsWindow:StartCategoryDrag(categoryKey)
    if not self.layoutEditMode or type(categoryKey) ~= "string" or categoryKey == "" then
        return
    end

    local sourcePlacement = self.currentSectionLayoutByKey and self.currentSectionLayoutByKey[categoryKey] or nil
    local sourceSection = self.visibleSectionFramesByCategoryKey and self.visibleSectionFramesByCategoryKey[categoryKey] or nil
    local sourceGroup = nil
    if type(self.currentLayoutGroups) == "table" then
        for i = 1, #self.currentLayoutGroups do
            local group = self.currentLayoutGroups[i]
            if group.category and group.category.key == categoryKey then
                sourceGroup = group
                break
            end
        end
    end

    if not sourcePlacement or not sourceGroup then
        return
    end

    self:EnsureLayoutDragFrames()

    local cursorX, cursorY = self:GetCursorPositionInContent()
    if not cursorX or not cursorY then
        return
    end

    self.layoutDragState = {
        categoryKey = categoryKey,
        sourcePlacement = sourcePlacement,
        sourceGroup = self:CloneLayoutGroup(sourceGroup),
        sourceSection = sourceSection,
        grabOffsetX = cursorX - (sourcePlacement.x or 0),
        grabOffsetY = cursorY - (-(sourcePlacement.y or 0)),
        candidate = nil,
    }

    if self.layoutGhostFrame then
        self.layoutGhostFrame:SetSize(sourcePlacement.width or 1, sourcePlacement.height or HEADER_HEIGHT)
        self.layoutGhostTitle:SetText(self:GetSectionTitleText(sourceGroup))
        self.layoutGhostFrame:Show()
    end

    if self.layoutPreviewTitle then
        self.layoutPreviewTitle:SetText(self:GetSectionTitleText(sourceGroup))
    end

    if self.layoutDragDriver then
        self.layoutDragDriver:Show()
    end

    self:UpdateCategoryDrag()
end

function BagsWindow:UpdateCategoryDrag()
    local dragState = self.layoutDragState
    if not dragState then
        return
    end

    if not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
        self:StopCategoryDrag(true)
        return
    end

    local cursorX, cursorY = self:GetCursorPositionInContent()
    if not cursorX or not cursorY then
        return
    end

    local candidate = self:BuildBestLayoutDropCandidate(cursorX, cursorY)
    dragState.candidate = candidate

    if self.layoutGhostFrame then
        self.layoutGhostFrame:ClearAllPoints()
        self.layoutGhostFrame:SetPoint(
            "TOPLEFT",
            self.content,
            "TOPLEFT",
            cursorX - (dragState.grabOffsetX or 0),
            -(cursorY - (dragState.grabOffsetY or 0))
        )
        self.layoutGhostFrame:Show()
    end

    if self.layoutPreviewFrame and candidate and candidate.placement then
        self.layoutPreviewFrame:ClearAllPoints()
        self.layoutPreviewFrame:SetPoint("TOPLEFT", self.content, "TOPLEFT", candidate.placement.x or CONTENT_SIDE_PADDING, candidate.placement.y or -8)
        self.layoutPreviewFrame:SetSize(candidate.placement.width or 1, candidate.placement.height or HEADER_HEIGHT)
        self.layoutPreviewTitle:SetText(self:GetSectionTitleText(dragState.sourceGroup))
        self.layoutPreviewFrame:Show()
    elseif self.layoutPreviewFrame then
        self.layoutPreviewFrame:Hide()
    end
end

function BagsWindow:StopCategoryDrag(applyDrop)
    local dragState = self.layoutDragState
    if not dragState then
        return
    end

    self.layoutDragState = nil

    if self.layoutDragDriver then
        self.layoutDragDriver:Hide()
    end
    if self.layoutGhostFrame then
        self.layoutGhostFrame:Hide()
    end
    if self.layoutPreviewFrame then
        self.layoutPreviewFrame:Hide()
    end

    if applyDrop and dragState.candidate then
        self:ApplyCategoryLayoutCandidate(dragState.candidate)
    end
end

function BagsWindow:AcquireItemButton()
    local button = vesperTools:CreateContainerItemButton(self, self.content, {
        defaultSize = DEFAULT_BUTTON_SIZE,
        includeNewItemGlow = true,
        onEnter = function(window, selfButton)
            window:HandleItemEnter(selfButton)
        end,
        onClick = function(window, selfButton, mouseButton)
            window:HandleItemClick(selfButton, mouseButton)
        end,
        onDragStart = function(window, selfButton)
            window:HandleItemDrag(selfButton)
        end,
        onReceiveDrag = function(window, selfButton)
            window:HandleItemDrag(selfButton)
        end,
    })

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
    vesperTools:ApplyConfiguredFont(count, 13, "OUTLINE")
    button.count = count

    self.summaryButtons[#self.summaryButtons + 1] = button
    return button
end

function BagsWindow:AcquireCurrencyButton()
    local parent = self.currencyBar or self.frame
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(CURRENCY_BAR_BUTTON_MIN_WIDTH, CURRENCY_BAR_BUTTON_HEIGHT)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    button:SetBackdropBorderColor(1, 1, 1, 0.08)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    button:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(CURRENCY_BAR_ICON_SIZE, CURRENCY_BAR_ICON_SIZE)
    icon:SetPoint("LEFT", button, "LEFT", CURRENCY_BAR_BUTTON_PADDING, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("LEFT", icon, "RIGHT", CURRENCY_BAR_ICON_GAP, 0)
    count:SetPoint("RIGHT", button, "RIGHT", -CURRENCY_BAR_BUTTON_PADDING, 0)
    count:SetJustifyH("RIGHT")
    count:SetJustifyV("MIDDLE")
    count:SetWordWrap(false)
    vesperTools:ApplyConfiguredFont(count, 11, "")
    button.count = count

    self.currencyButtons[#self.currencyButtons + 1] = button
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
    vesperTools:ApplyConfiguredFont(count, 11, "OUTLINE")
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
    for i = 1, #self.currencyButtons do
        self.currencyButtons[i]:Hide()
    end
    if self.currencyBar then
        self.currencyBar:Hide()
    end
    if self.layoutPreviewFrame then
        self.layoutPreviewFrame:Hide()
    end
    if self.layoutGhostFrame then
        self.layoutGhostFrame:Hide()
    end
end

-- Equipped-bag row and item interaction helpers.
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
    vesperTools:ApplyConfiguredFont(button.count, countFontSize, "OUTLINE")
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
    local itemInteraction = self:GetItemInteraction()
    if itemInteraction then
        itemInteraction:ConfigureTooltip(button)
    end
end

function BagsWindow:HandleItemEnter(button)
    self:ConfigureTooltip(button)
end

function BagsWindow:HandleItemDrag(button)
    if self.layoutEditMode then
        return
    end

    local itemInteraction = self:GetItemInteraction()
    if itemInteraction then
        itemInteraction:HandleItemDrag(button)
    end
end

function BagsWindow:AcquireNativeContainerOverlay(button)
    local itemInteraction = self:GetItemInteraction()
    return itemInteraction and itemInteraction:AcquireNativeContainerOverlay(button) or nil
end

function BagsWindow:UpdateNativeContainerOverlay(button)
    local itemInteraction = self:GetItemInteraction()
    if itemInteraction then
        itemInteraction:UpdateNativeContainerOverlay(button)
    end
end

function BagsWindow:ConfigureSummaryTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.summaryLabel or UNKNOWN, 1, 1, 1)
    GameTooltip:AddLine(tostring(button.summaryCount or 0), 0.85, 0.85, 0.85)
    GameTooltip:Show()
end

function BagsWindow:HandleItemClick(button, mouseButton)
    if self.layoutEditMode then
        return
    end

    local itemInteraction = self:GetItemInteraction()
    if itemInteraction then
        itemInteraction:HandleItemClick(button, mouseButton)
    end
end

function BagsWindow:ConfigureCurrencyTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")

    if button.isGold then
        GameTooltip:SetText(button.currencyName or (MONEY or "Gold"), 1, 1, 1)
        if GetMoneyString then
            GameTooltip:AddLine(GetMoneyString(button.quantity or 0), 1, 0.82, 0.12)
        else
            GameTooltip:AddLine(formatGoldQuantity(button.quantity or 0), 1, 0.82, 0.12)
        end
        GameTooltip:Show()
        return
    end

    if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyLink) == "function" and GameTooltip.SetHyperlink then
        local ok, currencyLink = pcall(C_CurrencyInfo.GetCurrencyLink, button.currencyID)
        if ok and type(currencyLink) == "string" and currencyLink ~= "" then
            GameTooltip:SetHyperlink(currencyLink)
            return
        end
    end

    GameTooltip:SetText(button.currencyName or UNKNOWN, 1, 1, 1)
    GameTooltip:AddLine(formatCurrencyQuantity(button.quantity or 0), 0.85, 0.85, 0.85)
    if button.maxQuantity and button.maxQuantity > 0 then
        GameTooltip:AddLine(string.format("%s / %s", formatCurrencyQuantity(button.quantity or 0), formatCurrencyQuantity(button.maxQuantity)), 0.62, 0.84, 1)
    end
    GameTooltip:Show()
end

function BagsWindow:ConfigureCurrencyButton(button, entry, layoutInfo)
    button.isGold = entry.isGold and true or false
    button.currencyID = entry.currencyID
    button.currencyName = entry.name
    button.quantity = entry.quantity
    button.maxQuantity = entry.maxQuantity
    button:SetWidth(layoutInfo and layoutInfo.width or CURRENCY_BAR_BUTTON_MIN_WIDTH)
    button.icon:SetTexture(entry.iconFileID or "Interface\\Icons\\INV_Misc_Coin_01")
    button.count:SetText(layoutInfo and layoutInfo.text or self:GetCurrencyBarButtonText(entry))
    button:SetScript("OnEnter", function(selfButton)
        self:ConfigureCurrencyTooltip(selfButton)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:Show()
end

-- Item presentation and final window refresh pass.
function BagsWindow:CanDisplayItemLevel(record)
    local itemInteraction = self:GetItemInteraction()
    return itemInteraction and itemInteraction:CanDisplayItemLevel(record) or false
end

function BagsWindow:GetItemLevelForRecord(record)
    local itemInteraction = self:GetItemInteraction()
    return itemInteraction and itemInteraction:GetItemLevelForRecord(record) or nil
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

function BagsWindow:ConfigureItemButton(button, record, context, viewSettings)
    local itemInteraction = self:GetItemInteraction()
    if itemInteraction then
        itemInteraction:ConfigureItemButton(button, record, context, viewSettings)
    end
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
    vesperTools:ApplyConfiguredFont(button.count, countFontSize, "OUTLINE")
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

    if self.layoutDragState then
        self:StopCategoryDrag(false)
    end

    self:CleanupLegacyScrollArtifacts()
    self:ApplyConfiguredFonts()
    wipe(self.newItemGlowKeysSeen)
    self.currentLayoutGroups = nil
    self.currentSectionLayout = nil
    self.currentSectionLayoutByKey = {}
    self.visibleSectionFramesByCategoryKey = {}
    local viewSettings = self:GetViewSettings()
    self:UpdateBagSlotsButtonVisual(self.bagSlotsMenu and self.bagSlotsMenu:IsShown())
    self:UpdateCombineStacksButtonVisual(viewSettings.combineStacks)
    self:UpdateLayoutEditButtonVisual(self.layoutEditMode)
    self:RefreshGuildLookupPresentation()
    self:HideAllReusableFrames()

    local store = self:GetStore()
    if not store then
        self.characterSearchMatchCounts = nil
        self.currentLayoutColumns = nil
        self.currentContentWidth = nil
        self.currentViewSettings = nil
        return
    end

    local selectedCharacter = self:ResolveSelectedCharacter()

    if not selectedCharacter then
        self.characterSearchMatchCounts = nil
        self.currentDisplayCharacter = nil
        self.currentSnapshot = nil
        self:HideCharacterMenu()
        self:HideBagSlotsMenu()
        if self.characterDropdown then
            if self.characterDropdownText then
                self.characterDropdownText:SetText(L["BAGS_EMPTY"])
            end
            self:UpdateSelectedCharacterDropdownMatch(nil)
            self:SetCharacterDropdownEnabled(false)
        end
        self:UpdateCleanupButtonVisual(false)
        self.modeText:SetText("")
        self.emptyText:SetText(L["BAGS_EMPTY"])
        self.emptyText:Show()
        self.frame:SetSize(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT)
        self.emptyText:SetWidth(MIN_WINDOW_WIDTH - 60)
        self.content:SetSize(MIN_WINDOW_WIDTH - 32, 40)
        self.currentLayoutColumns = nil
        self.currentContentWidth = nil
        self.currentViewSettings = nil
        self:RefreshGuildLookupPresentation()
        self:SaveWindowState()
        return
    end

    self.characterSearchMatchCounts = self:BuildCharacterSearchMatchCounts(self:GetSearchTokens())

    if self.characterDropdown then
        if self.characterDropdownText then
            self.characterDropdownText:SetText(selectedCharacter.fullName)
        end
        self:UpdateSelectedCharacterDropdownMatch(selectedCharacter.key)
        self:SetCharacterDropdownEnabled(true)
    end
    self:UpdateCharacterDropdownVisual()
    if self.characterMenu and self.characterMenu:IsShown() then
        self:RefreshCharacterMenu()
    end
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
        self.currentLayoutColumns = nil
        self.currentContentWidth = nil
        self.currentViewSettings = nil
        self:RefreshGuildLookupPresentation()
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
    local currencyIndex = 0
    local groups, maxItemCount = self:BuildLayoutGroups(store, selectedCharacter.key, categories, viewSettings)
    local currencyEntries = self:GetCurrencyBarEntries(selectedCharacter)
    local layout = self:ResolveAutoLayout(groups, maxItemCount, viewSettings, currencyEntries)
    groups = layout.groups or groups
    local contentWidth = layout.contentWidth
    local columns = layout.columns
    local sectionLayout = layout.sectionLayout or {}
    local slotPitch = self:GetSlotPitch(viewSettings)
    local itemContext = {
        ownerName = selectedCharacter.fullName,
        isInteractive = selectedCharacter.isCurrent and true or false,
        isCurrentCharacter = selectedCharacter.isCurrent and true or false,
    }
    self.currentLayoutGroups = groups
    self.currentSectionLayout = sectionLayout
    self.currentLayoutColumns = columns
    self.currentContentWidth = contentWidth
    self.currentViewSettings = viewSettings
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
        local placement = sectionLayout[i] or {}
        if #items > 0 then
            sectionIndex = sectionIndex + 1
            local section = self.sectionFrames[sectionIndex] or self:AcquireSectionFrame()
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", self.content, "TOPLEFT", placement.x or CONTENT_SIDE_PADDING, placement.y or -8)
            section:SetSize(placement.width or math.max(1, contentWidth - (CONTENT_SIDE_PADDING * 2)), placement.height or HEADER_HEIGHT)
            section.categoryKey = category.key
            self.currentSectionLayoutByKey[category.key] = placement
            self.visibleSectionFramesByCategoryKey[category.key] = section
            if groups[i].hidden then
                section.title:SetText(string.format("%s (%d) (%s)", category.label, category.count, L["BAGS_HIDDEN"]))
                section.title:SetTextColor(0.8, 0.8, 0.8, 1)
                section.toggleButton.icon:SetRotation(math.pi)
                section.toggleButton.icon:SetVertexColor(0.8, 0.8, 0.8, 0.98)
            else
                section.title:SetText(string.format("%s (%d)", category.label, category.count))
                section.title:SetTextColor(1, 1, 1, 1)
                section.toggleButton.icon:SetRotation(0)
                section.toggleButton.icon:SetVertexColor(1, 1, 1, 0.98)
            end
            section.toggleButton:SetScript("OnClick", function()
                self:ToggleCategoryCollapsed(selectedCharacter.key, category.key)
            end)
            if section.dragOverlay then
                section.dragOverlay:EnableMouse(self.layoutEditMode)
                section.dragOverlay:SetShown(self.layoutEditMode)
            end
            if self.layoutEditMode then
                section:SetBackdropColor(0.12, 0.18, 0.26, LAYOUT_EDIT_SECTION_BACKGROUND_ALPHA)
                section:SetBackdropBorderColor(0.55, 0.84, 1, LAYOUT_EDIT_SECTION_BORDER_ALPHA)
            else
                section:SetBackdropColor(0.12, 0.18, 0.26, 0)
                section:SetBackdropBorderColor(0.55, 0.84, 1, 0)
            end
            section:Show()

            if not groups[i].hidden then
                local row = 0
                local column = 0
                local sectionColumns = math.max(1, placement.columns or math.min(columns, #items))
                for itemPosition = 1, #items do
                    itemIndex = itemIndex + 1
                    local button = self.itemButtons[itemIndex] or self:AcquireItemButton()
                    local x = column * slotPitch
                    local y = -HEADER_HEIGHT - (row * slotPitch)
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", section, "TOPLEFT", x, y)
                    self:ConfigureItemButton(button, items[itemPosition], itemContext, viewSettings)

                    column = column + 1
                    if column >= sectionColumns then
                        column = 0
                        row = row + 1
                    end
                end
            end
        end
    end

    if #groups > 0 then
        yOffset = -(layout.sectionsHeight + SUMMARY_GAP)
    end

    for i = 1, #emptySlotSummary do
        summaryIndex = summaryIndex + 1
        local button = self.summaryButtons[summaryIndex] or self:AcquireSummaryButton()
        local x = CONTENT_SIDE_PADDING + ((i - 1) * slotPitch)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, yOffset)
        self:ConfigureSummaryButton(button, emptySlotSummary[i], viewSettings)
    end

    local currencyBarLayout = layout.currencyBarLayout or self:GetCurrencyBarLayout(layout.frameWidth - 20, currencyEntries)
    if #currencyEntries > 0 and self.currencyBar and currencyBarLayout.height > 0 then
        self.currencyBar:SetHeight(currencyBarLayout.height)
        self.currencyBar:Show()

        local buttonStartY = -((CURRENCY_BAR_VERTICAL_PADDING * 2) + 1)
        local buttonPitch = CURRENCY_BAR_BUTTON_HEIGHT + CURRENCY_BAR_BUTTON_GAP

        for i = 1, #currencyEntries do
            currencyIndex = currencyIndex + 1
            local button = self.currencyButtons[currencyIndex] or self:AcquireCurrencyButton()
            local buttonLayout = currencyBarLayout.buttons[i] or {}
            button:ClearAllPoints()
            button:SetPoint(
                "TOPLEFT",
                self.currencyBar,
                "TOPLEFT",
                CURRENCY_BAR_SIDE_PADDING + (buttonLayout.xOffset or 0),
                buttonStartY - ((buttonLayout.row or 0) * buttonPitch)
            )
            self:ConfigureCurrencyButton(button, currencyEntries[i], buttonLayout)
        end
    end

    self.content:SetSize(contentWidth, layout.contentHeight)
    self:RefreshGuildLookupPresentation()
end
