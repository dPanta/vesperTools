local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local Configuration = vesperTools:NewModule("Configuration")
local L = vesperTools.L

-- Configuration module responsibilities:
-- 1) Build and manage the custom config window.
-- 2) Persist style options (font + frame opacities) into profile DB.
-- 3) Broadcast a single refresh message consumed by UI modules.
local WINDOW_WIDTH = 460
local WINDOW_HEIGHT = 660
local DEFAULT_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"
local FONT_MENU_ROW_HEIGHT = 26
local FONT_MENU_MAX_VISIBLE_ROWS = 12
local ROSTER_BLACKLIST_MENU_ROW_HEIGHT = 22
local ROSTER_BLACKLIST_MENU_MAX_VISIBLE_ROWS = 10
local TOY_MENU_ROW_HEIGHT = 22
local TOY_MENU_MAX_VISIBLE_ROWS = 10
local CURRENCY_MENU_ROW_HEIGHT = 22
local CURRENCY_MENU_MAX_VISIBLE_ROWS = 10

-- Clamp a number to the inclusive [min, max] interval.
local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

-- Round a numeric value to the nearest configured step size.
local function roundToStep(value, step)
    if not step or step <= 0 then
        return value
    end
    return math.floor((value / step) + 0.5) * step
end

-- Safely assign text to a FontString even when no font has been initialized yet.
local function setFontStringTextSafe(fontString, text, size, flags, fallbackObject)
    if not fontString then
        return
    end

    local resolvedSize = math.floor((tonumber(size) or 12) + 0.5)
    if resolvedSize < 6 then
        resolvedSize = 6
    end
    local resolvedFlags = type(flags) == "string" and flags or ""

    local hasFont = fontString.GetFont and fontString:GetFont()
    local applied = vesperTools:ApplyConfiguredFont(fontString, resolvedSize, resolvedFlags)
    if not applied and not hasFont then
        local fallback = fallbackObject or GameFontHighlightSmall or GameFontNormal or SystemFont_Shadow_Med1
        if fallback then
            pcall(fontString.SetFontObject, fontString, fallback)
        end

        if not (fontString.GetFont and fontString:GetFont()) then
            pcall(fontString.SetFont, fontString, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", resolvedSize, resolvedFlags)
        end
    end

    pcall(fontString.SetText, fontString, text or "")
end

local function setFontStringTextWithFontPathSafe(fontString, text, fontPath, size, flags, fallbackObject)
    if not fontString then
        return
    end

    local resolvedFontPath = vesperTools:NormalizeMediaPath(fontPath)
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

    local hasFont = fontString.GetFont and fontString:GetFont()
    local applied = trySet(resolvedFontPath, resolvedFlags)
        or (resolvedFlags ~= "" and trySet(resolvedFontPath, ""))
        or vesperTools:ApplyConfiguredFont(fontString, resolvedSize, resolvedFlags)

    if not applied and not hasFont then
        local fallback = fallbackObject or GameFontHighlightSmall or GameFontNormal or SystemFont_Shadow_Med1
        if fallback then
            pcall(fontString.SetFontObject, fontString, fallback)
        end

        if not (fontString.GetFont and fontString:GetFont()) then
            pcall(fontString.SetFont, fontString, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", resolvedSize, resolvedFlags)
        end
    end

    pcall(fontString.SetText, fontString, text or "")
end

local function applyConfiguredFontToWidgetObject(widget)
    if not widget or type(widget.GetFont) ~= "function" or type(widget.SetFont) ~= "function" then
        return
    end

    local _, size, flags = widget:GetFont()
    vesperTools:ApplyConfiguredFont(widget, size or 12, flags or "")
end

local function applyConfiguredFontRecursively(widget, visited)
    if not widget then
        return
    end

    visited = visited or {}
    if visited[widget] then
        return
    end
    visited[widget] = true

    applyConfiguredFontToWidgetObject(widget)

    if type(widget.GetRegions) == "function" then
        local regions = { widget:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region and type(region.GetObjectType) == "function" and region:GetObjectType() == "FontString" then
                applyConfiguredFontToWidgetObject(region)
            end
        end
    end

    if type(widget.GetChildren) == "function" then
        local children = { widget:GetChildren() }
        for i = 1, #children do
            applyConfiguredFontRecursively(children[i], visited)
        end
    end
end

-- Ensure the expected profile subtree exists before reading/writing config values.
-- This keeps runtime code robust even when old SavedVariables are missing fields.
local function ensureProfile()
    if not vesperTools.db then
        return nil
    end

    local profile = vesperTools.db.profile or {}
    vesperTools.db.profile = profile

    profile.style = profile.style or {}
    profile.style.fontPath = vesperTools:GetConfiguredFontPath()
    profile.style.fontName = vesperTools:GetConfiguredFontKey()

    profile.style.backgroundOpacity = profile.style.backgroundOpacity or {}
    if profile.style.backgroundOpacity.roster == nil then
        profile.style.backgroundOpacity.roster = 0.95
    end
    if profile.style.backgroundOpacity.portals == nil then
        profile.style.backgroundOpacity.portals = 0.95
    end
    if profile.style.backgroundOpacity.bestKeys == nil then
        profile.style.backgroundOpacity.bestKeys = 0.95
    end

    -- Frame-level typography controls:
    -- each window can scale independently while still sharing the same font family.
    profile.style.fontSize = profile.style.fontSize or {}
    profile.style.fontSize.roster = tonumber(profile.style.fontSize.roster) or 12
    profile.style.fontSize.portals = tonumber(profile.style.fontSize.portals) or 12
    profile.style.fontSize.bestKeys = tonumber(profile.style.fontSize.bestKeys) or 11

    profile.roster = profile.roster or {}
    if type(profile.roster.onlineCountBlacklist) ~= "table" then
        profile.roster.onlineCountBlacklist = {}
    end

    profile.portals = profile.portals or {}
    if profile.portals.primaryHearthstoneItemID ~= nil then
        profile.portals.primaryHearthstoneItemID = tonumber(profile.portals.primaryHearthstoneItemID) or 6948
    end
    local minButtonSize, maxButtonSize, defaultButtonSize = vesperTools:GetTopUtilityButtonSizeBounds()
    profile.portals.utilityButtonSize = clamp(
        math.floor((tonumber(profile.portals.utilityButtonSize) or defaultButtonSize) + 0.5),
        minButtonSize,
        maxButtonSize
    )
    if type(profile.portals.utilityToyWhitelist) ~= "table" then
        profile.portals.utilityToyWhitelist = {}
    else
        local sanitized = {}
        local seen = {}
        local whitelistLimit = vesperTools:GetToyWhitelistLimit()
        for i = 1, #profile.portals.utilityToyWhitelist do
            if #sanitized >= whitelistLimit then
                break
            end
            local itemID = tonumber(profile.portals.utilityToyWhitelist[i])
            if itemID and itemID > 0 and not seen[itemID] then
                sanitized[#sanitized + 1] = itemID
                seen[itemID] = true
            end
        end
        profile.portals.utilityToyWhitelist = sanitized
    end

    return profile
end

local function ensureBagsProfile()
    -- Bag and bank replacement settings live in the dedicated bags profile DB.
    return vesperTools:GetBagsProfile()
end

-- Module state bootstrap.
function Configuration:OnInitialize()
    self.panel = nil
    self.activeTab = "roster"
    self.tabButtons = {}
    self.tabFrames = {}
    self.contextMenuAnchor = nil
    self.fontDropdown = nil
    self.fontDropdownText = nil
    self.fontMenuFrame = nil
    self.rosterOnlineBlacklistDropdown = nil
    self.rosterOnlineBlacklistDropdownText = nil
    self.rosterOnlineBlacklistMenuFrame = nil
    self.rosterOnlineBlacklistHint = nil
    self.hearthstoneDropdown = nil
    self.hearthstoneDropdownText = nil
    self.toyWhitelistDropdown = nil
    self.toyWhitelistDropdownText = nil
    self.toyWhitelistMenuFrame = nil
    self.bagsCurrencyBarDropdown = nil
    self.bagsCurrencyBarDropdownText = nil
    self.bagsCurrencyMenuFrame = nil
    self.toyNameInput = nil
    self.toyNameAddButton = nil
    self.toyLookupStatusText = nil
    self.utilityButtonSizeSlider = nil
    self.bagsColumnsSlider = nil
    self.bagsIconSizeSlider = nil
    self.bagsStackCountFontSizeSlider = nil
    self.bagsItemLevelFontSizeSlider = nil
    self.bagsQualityGlowSlider = nil
    self.bagsAllowGuildLookupRequestsCheckbox = nil
    self.bagsReplaceBlizzardCheckbox = nil
    self.bagsShowItemLevelCheckbox = nil
    self.bagsShowCurrencyBarCheckbox = nil
    self.bagsCurrencyBarHint = nil
    self.bankColumnsSlider = nil
    self.bankIconSizeSlider = nil
    self.bankStackCountFontSizeSlider = nil
    self.bankItemLevelFontSizeSlider = nil
    self.bankQualityGlowSlider = nil
    self.bankShowItemLevelCheckbox = nil
    self.bankReplaceBlizzardCheckbox = nil
    self.opacitySliders = {}
    self.fontSizeSliders = {}
    self._isRefreshing = false
end

-- Broadcast a single "config changed" message consumed by UI modules.
function Configuration:NotifyConfigChanged()
    vesperTools:SendMessage("VESPERTOOLS_CONFIG_CHANGED")
end

function Configuration:RefreshPanelFonts()
    if self.panel then
        applyConfiguredFontRecursively(self.panel)
    end
    if self.toyWhitelistMenuFrame then
        applyConfiguredFontRecursively(self.toyWhitelistMenuFrame)
    end
    if self.rosterOnlineBlacklistMenuFrame then
        applyConfiguredFontRecursively(self.rosterOnlineBlacklistMenuFrame)
    end
    if self.bagsCurrencyMenuFrame then
        applyConfiguredFontRecursively(self.bagsCurrencyMenuFrame)
    end
end

-- Create a standardized opacity slider control for frame background alpha.
function Configuration:CreateOpacitySlider(name, parent, labelText, anchor, yOffset)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(290)
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    slider:SetMinMaxValues(0.10, 1.00)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)

    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    local text = _G[name .. "Text"]

    if low then
        setFontStringTextSafe(low, "10%", 10, "", GameFontNormalSmall)
    end
    if high then
        setFontStringTextSafe(high, "100%", 10, "", GameFontNormalSmall)
    end
    if text then
        -- Initialize the label with a valid font immediately; it is updated live later.
        setFontStringTextSafe(text, "", 12, "", GameFontNormal)
    end

    slider._baseLabel = labelText
    return slider
end

-- Create a standardized font-size slider for per-frame text scaling.
function Configuration:CreateFontSizeSlider(name, parent, labelText, anchor, yOffset)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(290)
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    slider:SetMinMaxValues(8, 24)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    local text = _G[name .. "Text"]

    if low then
        setFontStringTextSafe(low, "8", 10, "", GameFontNormalSmall)
    end
    if high then
        setFontStringTextSafe(high, "24", 10, "", GameFontNormalSmall)
    end
    if text then
        setFontStringTextSafe(text, "", 12, "", GameFontNormal)
    end

    slider._baseLabel = labelText
    return slider
end

-- Create a standardized slider for top utility (hearthstone/toy) button size.
function Configuration:CreateUtilityButtonSizeSlider(name, parent, labelText, anchor, yOffset, minSize, maxSize)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(290)
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    slider:SetMinMaxValues(minSize, maxSize)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    local text = _G[name .. "Text"]

    if low then
        setFontStringTextSafe(low, tostring(minSize), 10, "", GameFontNormalSmall)
    end
    if high then
        setFontStringTextSafe(high, tostring(maxSize), 10, "", GameFontNormalSmall)
    end
    if text then
        setFontStringTextSafe(text, "", 12, "", GameFontNormal)
    end

    slider._baseLabel = labelText
    return slider
end

-- Create a standardized integer slider with explicit min/max labels.
function Configuration:CreateIntegerSlider(name, parent, labelText, anchor, yOffset, minValue, maxValue)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(290)
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    local text = _G[name .. "Text"]

    if low then
        setFontStringTextSafe(low, tostring(minValue), 10, "", GameFontNormalSmall)
    end
    if high then
        setFontStringTextSafe(high, tostring(maxValue), 10, "", GameFontNormalSmall)
    end
    if text then
        setFontStringTextSafe(text, "", 12, "", GameFontNormal)
    end

    slider._baseLabel = labelText
    return slider
end

-- Create a percentage slider used for visual intensity controls.
function Configuration:CreatePercentSlider(name, parent, labelText, anchor, yOffset, minValue, maxValue, step)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(290)
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step or 0.05)
    slider:SetObeyStepOnDrag(true)

    local low = _G[name .. "Low"]
    local high = _G[name .. "High"]
    local text = _G[name .. "Text"]

    if low then
        setFontStringTextSafe(low, string.format("%d%%", math.floor(((minValue or 0) * 100) + 0.5)), 10, "", GameFontNormalSmall)
    end
    if high then
        setFontStringTextSafe(high, string.format("%d%%", math.floor(((maxValue or 1) * 100) + 0.5)), 10, "", GameFontNormalSmall)
    end
    if text then
        setFontStringTextSafe(text, "", 12, "", GameFontNormal)
    end

    slider._baseLabel = labelText
    return slider
end

-- Keep slider title in sync with current numeric value.
function Configuration:UpdateSliderLabel(slider)
    if not slider then
        return
    end

    local value = tonumber(slider:GetValue()) or 0.95
    local percent = math.floor((value * 100) + 0.5)
    local text = _G[slider:GetName() .. "Text"]
    if text then
        setFontStringTextSafe(
            text,
            string.format("%s: %d%%", slider._baseLabel or L["CONFIG_SLIDER_OPACITY"], percent),
            12,
            "",
            GameFontNormal
        )
    end
end

-- Keep font-size slider title in sync with the selected point size.
function Configuration:UpdateFontSizeSliderLabel(slider)
    if not slider then
        return
    end

    local value = math.floor((tonumber(slider:GetValue()) or 12) + 0.5)
    local text = _G[slider:GetName() .. "Text"]
    if text then
        setFontStringTextSafe(
            text,
            string.format("%s: %d", slider._baseLabel or L["CONFIG_SLIDER_FONT_SIZE"], value),
            12,
            "",
            GameFontNormal
        )
    end
end

-- Keep utility button-size slider title in sync with selected icon size.
function Configuration:UpdateUtilityButtonSizeSliderLabel(slider)
    if not slider then
        return
    end

    local value = math.floor((tonumber(slider:GetValue()) or 52) + 0.5)
    local text = _G[slider:GetName() .. "Text"]
    if text then
        setFontStringTextSafe(
            text,
            string.format("%s: %d", slider._baseLabel or L["CONFIG_SLIDER_UTILITY_BUTTON_SIZE"], value),
            12,
            "",
            GameFontNormal
        )
    end
end

-- Keep integer slider title in sync with its selected value.
function Configuration:UpdateIntegerSliderLabel(slider)
    if not slider then
        return
    end

    local value = math.floor((tonumber(slider:GetValue()) or 0) + 0.5)
    local text = _G[slider:GetName() .. "Text"]
    if text then
        setFontStringTextSafe(
            text,
            string.format("%s: %d", slider._baseLabel or "", value),
            12,
            "",
            GameFontNormal
        )
    end
end

-- Keep percentage slider title in sync with its selected value.
function Configuration:UpdatePercentSliderLabel(slider)
    if not slider then
        return
    end

    local value = tonumber(slider:GetValue()) or 0
    local percent = math.floor((value * 100) + 0.5)
    local text = _G[slider:GetName() .. "Text"]
    if text then
        setFontStringTextSafe(
            text,
            string.format("%s: %d%%", slider._baseLabel or "", percent),
            12,
            "",
            GameFontNormal
        )
    end
end

-- Create a reusable checkbox with an inline text label.
function Configuration:CreateCheckButton(name, parent, labelText, anchor, yOffset)
    local checkbox = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -4, yOffset)

    local text = checkbox.text or _G[name .. "Text"]
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", checkbox, "RIGHT", 4, 1)
        setFontStringTextSafe(text, labelText, 12, "", GameFontNormal)
    end

    return checkbox
end

-- Create a flat dropdown-like button reused by multiple controls.
function Configuration:CreateFlatDropdown(name, parent, anchor, yOffset, width, onClick)
    local dropdown = CreateFrame("Button", name, parent)
    dropdown:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    dropdown:SetSize(width or 280, 22)
    dropdown:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
    dropdown:GetNormalTexture():SetVertexColor(0.08, 0.08, 0.1, 0.92)
    dropdown:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    dropdown:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    dropdown:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    dropdown:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)

    local borderTop = dropdown:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT")
    borderTop:SetPoint("TOPRIGHT")
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(1, 1, 1, 0.12)

    local borderBottom = dropdown:CreateTexture(nil, "BORDER")
    borderBottom:SetPoint("BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT")
    borderBottom:SetHeight(1)
    borderBottom:SetColorTexture(1, 1, 1, 0.12)

    local borderLeft = dropdown:CreateTexture(nil, "BORDER")
    borderLeft:SetPoint("TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT")
    borderLeft:SetWidth(1)
    borderLeft:SetColorTexture(1, 1, 1, 0.12)

    local borderRight = dropdown:CreateTexture(nil, "BORDER")
    borderRight:SetPoint("TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT")
    borderRight:SetWidth(1)
    borderRight:SetColorTexture(1, 1, 1, 0.12)

    local text = dropdown:CreateFontString(nil, "ARTWORK")
    text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
    text:SetPoint("RIGHT", dropdown, "RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    vesperTools:ApplyConfiguredFont(text, 12, "")
    dropdown.Text = text

    local arrow = dropdown:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
    arrow:SetSize(12, 12)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetVertexColor(0.86, 0.9, 1, 0.95)

    if type(onClick) == "function" then
        dropdown:SetScript("OnClick", onClick)
    end

    return dropdown
end

-- Create a neutral top-level anchor so MenuUtil popups render above the config panel.
function Configuration:GetContextMenuAnchor(anchorButton)
    local anchorLevel = 80
    if self.panel and self.panel.GetFrameLevel then
        anchorLevel = math.max(anchorLevel, (self.panel:GetFrameLevel() or 0) + 40)
    end

    if not (self.contextMenuAnchor and self.contextMenuAnchor.GetName) then
        self.contextMenuAnchor = CreateFrame("Frame", "vesperToolsConfigContextMenuAnchor", UIParent)
        self.contextMenuAnchor:SetSize(2, 2)
        self.contextMenuAnchor:SetClampedToScreen(true)
    end

    local anchor = self.contextMenuAnchor
    anchor:SetFrameStrata("TOOLTIP")
    anchor:SetFrameLevel(anchorLevel)
    anchor:SetToplevel(true)
    anchor:Show()
    anchor:ClearAllPoints()

    local uiScale = UIParent:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    if uiScale > 0 and cursorX and cursorY and cursorX > 0 and cursorY > 0 then
        anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cursorX / uiScale, cursorY / uiScale)
        return anchor
    end

    if anchorButton and anchorButton.GetCenter then
        local centerX, centerY = anchorButton:GetCenter()
        if centerX and centerY then
            anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
            return anchor
        end
    end

    anchor:SetPoint("CENTER", UIParent, "CENTER")
    return anchor
end

-- Create a flat-styled single-line input field matching the custom config controls.
function Configuration:CreateFlatInput(name, parent, anchor, yOffset, width)
    local input = CreateFrame("EditBox", name, parent, "BackdropTemplate")
    input:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    input:SetSize(width or 280, 22)
    input:SetAutoFocus(false)
    input:SetMaxLetters(80)
    input:SetTextInsets(8, 8, 0, 0)
    input:SetCursorPosition(0)

    input:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    input:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    input:SetBackdropBorderColor(1, 1, 1, 0.12)

    local applied = vesperTools:ApplyConfiguredFont(input, 12, "")
    if not applied and ChatFontNormal then
        input:SetFontObject(ChatFontNormal)
    end
    input:SetTextColor(0.94, 0.96, 1, 1)

    input:SetScript("OnEscapePressed", function(selfInput)
        selfInput:ClearFocus()
    end)

    input:SetScript("OnEditFocusGained", function(selfInput)
        selfInput:SetBackdropBorderColor(0.34, 0.62, 0.95, 0.75)
    end)

    input:SetScript("OnEditFocusLost", function(selfInput)
        selfInput:SetBackdropBorderColor(1, 1, 1, 0.12)
    end)

    return input
end

-- Create a compact action button for custom panel actions.
function Configuration:CreateFlatActionButton(name, parent, text, anchor, relativePoint, xOffset, yOffset, width)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(width or 88, 22)
    button:SetPoint("TOPLEFT", anchor, relativePoint or "TOPRIGHT", xOffset or 6, yOffset or 0)
    button:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    button:SetPushedTexture("Interface\\Buttons\\WHITE8x8")

    button:GetNormalTexture():SetVertexColor(0.08, 0.08, 0.1, 0.92)
    button:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    button:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)

    local label = button:CreateFontString(nil, "ARTWORK")
    label:SetPoint("CENTER", 0, 0)
    setFontStringTextSafe(label, text or L["CONFIG_ADD_BUTTON"], 12, "", GameFontNormal)
    button.Label = label

    return button
end

-- Create one top tab button and register it in the tab-switch map.
function Configuration:CreateTabButton(parent, tabKey, label, anchor, xOffset, yOffset, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 120, 24)
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset or 0, yOffset or 0)
    button:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    button:SetPushedTexture("Interface\\Buttons\\WHITE8x8")

    local normal = button:GetNormalTexture()
    local highlight = button:GetHighlightTexture()
    local pushed = button:GetPushedTexture()
    normal:SetVertexColor(0.10, 0.10, 0.12, 0.95)
    highlight:SetVertexColor(0.2, 0.36, 0.58, 0.18)
    pushed:SetVertexColor(0.14, 0.22, 0.35, 0.42)

    local labelText = button:CreateFontString(nil, "ARTWORK")
    labelText:SetPoint("CENTER", 0, 0)
    setFontStringTextSafe(labelText, label, 12, "OUTLINE", GameFontNormal)
    button._labelText = labelText
    button._normalTexture = normal
    button._tabKey = tabKey

    button:SetScript("OnClick", function()
        self:SetActiveTab(tabKey)
    end)

    self.tabButtons[tabKey] = button
    return button
end

-- Switch visible configuration section and restyle tab buttons.
function Configuration:SetActiveTab(tabKey)
    if not tabKey or not self.tabFrames[tabKey] then
        tabKey = "roster"
    end

    self.activeTab = tabKey

    for key, frame in pairs(self.tabFrames) do
        frame:SetShown(key == tabKey)
    end

    for key, button in pairs(self.tabButtons) do
        local isActive = (key == tabKey)
        if button._normalTexture then
            if isActive then
                button._normalTexture:SetVertexColor(0.16, 0.28, 0.46, 0.95)
            else
                button._normalTexture:SetVertexColor(0.10, 0.10, 0.12, 0.95)
            end
        end
        if button._labelText then
            if isActive then
                button._labelText:SetTextColor(1, 1, 1, 1)
            else
                button._labelText:SetTextColor(0.78, 0.82, 0.9, 1)
            end
        end
    end
end

-- Refresh the selected-font caption in the dropdown.
function Configuration:RefreshFontDropdownText()
    if not self.fontDropdownText then
        return
    end

    local label = vesperTools:GetConfiguredFontLabel()
    setFontStringTextSafe(self.fontDropdownText, label, 12, "", GameFontHighlightSmall)
end

function Configuration:RefreshRosterOnlineBlacklistDropdownText()
    if not self.rosterOnlineBlacklistDropdown or not self.rosterOnlineBlacklistDropdownText then
        return
    end

    self.rosterOnlineBlacklistDropdown:Enable()
    self.rosterOnlineBlacklistDropdown:SetAlpha(1)

    local selectedCount = vesperTools:GetRosterOnlineCountBlacklistCount()
    if selectedCount <= 0 then
        setFontStringTextSafe(
            self.rosterOnlineBlacklistDropdownText,
            L["CONFIG_ROSTER_ONLINE_BLACKLIST_NONE"],
            12,
            "",
            GameFontHighlightSmall
        )
        return
    end

    setFontStringTextSafe(
        self.rosterOnlineBlacklistDropdownText,
        string.format(L["CONFIG_ROSTER_ONLINE_BLACKLIST_SELECTED_FMT"], selectedCount),
        12,
        "",
        GameFontHighlightSmall
    )
end

function Configuration:OpenFontPicker(anchorButton)
    local profile = ensureProfile()
    if not profile then
        return
    end

    local menu = self:EnsureFontMenuFrame(anchorButton)
    if not menu then
        return
    end

    if menu:IsShown() and menu._anchorButton == anchorButton then
        menu:Hide()
        return
    end

    menu._anchorButton = anchorButton
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -4)
    menu:SetWidth(anchorButton:GetWidth() or 420)
    menu:Show()
    menu:Raise()
    self:RefreshFontMenu()
end

-- Refresh the primary-hearthstone dropdown caption and enabled state.
function Configuration:RefreshHearthstoneDropdownText()
    if not self.hearthstoneDropdownText or not self.hearthstoneDropdown then
        return
    end

    local options = vesperTools:GetPrimaryHearthstoneSelectionOptions()
    if type(options) ~= "table" or #options == 0 then
        self.hearthstoneDropdown:Disable()
        self.hearthstoneDropdown:SetAlpha(0.55)
        setFontStringTextSafe(
            self.hearthstoneDropdownText,
            L["CONFIG_NO_HEARTHSTONES_AVAILABLE"],
            12,
            "",
            GameFontHighlightSmall
        )
        return
    end

    self.hearthstoneDropdown:Enable()
    self.hearthstoneDropdown:SetAlpha(1)

    local selectedID = vesperTools:ResolvePrimaryHearthstoneID()
    local selectedOption = nil
    for i = 1, #options do
        if options[i].itemID == selectedID then
            selectedOption = options[i]
            break
        end
    end
    if not selectedOption then
        selectedOption = options[1]
    end

    local icon = selectedOption.icon or DEFAULT_ICON_TEXTURE
    local label = string.format(
        "|T%s:14:14:0:0|t %s",
        icon,
        selectedOption.name or string.format(L["ITEM_FALLBACK_FMT"], tostring(selectedOption.itemID))
    )
    setFontStringTextSafe(self.hearthstoneDropdownText, label, 12, "", GameFontHighlightSmall)
end

-- Refresh toy-whitelist caption and enabled state.
function Configuration:RefreshToyWhitelistDropdownText()
    if not self.toyWhitelistDropdown or not self.toyWhitelistDropdownText then
        return
    end

    local ownedToyOptions = vesperTools:GetOwnedToyOptions()
    local ownedCount = type(ownedToyOptions) == "table" and #ownedToyOptions or 0
    if ownedCount == 0 then
        self.toyWhitelistDropdown:Disable()
        self.toyWhitelistDropdown:SetAlpha(0.55)
        setFontStringTextSafe(self.toyWhitelistDropdownText, L["CONFIG_NO_TOYS_AVAILABLE"], 12, "", GameFontHighlightSmall)
        return
    end

    self.toyWhitelistDropdown:Enable()
    self.toyWhitelistDropdown:SetAlpha(1)

    local whitelist = vesperTools:GetConfiguredToyWhitelist()
    local whitelistCount = #whitelist
    if whitelistCount == 0 then
        setFontStringTextSafe(self.toyWhitelistDropdownText, L["CONFIG_TOY_FLYOUT_WHITELIST_NONE"], 12, "", GameFontHighlightSmall)
        return
    end

    setFontStringTextSafe(
        self.toyWhitelistDropdownText,
        string.format(L["CONFIG_TOY_FLYOUT_WHITELIST_SELECTED_FMT"], whitelistCount),
        12,
        "",
        GameFontHighlightSmall
    )
end

function Configuration:SetBagsCurrencyBarStatus(text, r, g, b)
    if not self.bagsCurrencyBarHint then
        return
    end

    setFontStringTextSafe(self.bagsCurrencyBarHint, text or "", 11, "", GameFontHighlightSmall)
    self.bagsCurrencyBarHint:SetTextColor(r or 0.78, g or 0.82, b or 0.9, 1)
end

function Configuration:RefreshBagsCurrencyBarDropdownText()
    if not self.bagsCurrencyBarDropdown or not self.bagsCurrencyBarDropdownText then
        return
    end

    local options = vesperTools:GetCurrencyBarSelectionOptions()
    local hasOptions = type(options) == "table" and #options > 0
    if not hasOptions then
        self.bagsCurrencyBarDropdown:Enable()
        self.bagsCurrencyBarDropdown:SetAlpha(1)
        setFontStringTextSafe(
            self.bagsCurrencyBarDropdownText,
            L["CONFIG_BAGS_CURRENCY_BAR_NONE_AVAILABLE"],
            12,
            "",
            GameFontHighlightSmall
        )
        return
    end

    self.bagsCurrencyBarDropdown:Enable()
    self.bagsCurrencyBarDropdown:SetAlpha(1)

    local selectedIDs = vesperTools:GetConfiguredBagCurrencyIDs()
    if #selectedIDs == 0 then
        setFontStringTextSafe(
            self.bagsCurrencyBarDropdownText,
            L["CONFIG_BAGS_CURRENCY_BAR_TRACKED"],
            12,
            "",
            GameFontHighlightSmall
        )
        return
    end

    setFontStringTextSafe(
        self.bagsCurrencyBarDropdownText,
        string.format(L["CONFIG_BAGS_CURRENCY_BAR_SELECTED_FMT"], #selectedIDs),
        12,
        "",
        GameFontHighlightSmall
    )
end

-- Open selector for primary hearthstone with icon rows.
-- Fallback behavior cycles through available entries when MenuUtil is unavailable.
function Configuration:OpenHearthstonePicker(anchorButton)
    if not ensureProfile() then
        return
    end

    local options = vesperTools:GetPrimaryHearthstoneSelectionOptions()
    if type(options) ~= "table" or #options == 0 then
        return
    end

    local selectedID = vesperTools:ResolvePrimaryHearthstoneID() or vesperTools:GetConfiguredPrimaryHearthstoneID()

    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        local menuAnchor = self:GetContextMenuAnchor(anchorButton)
        MenuUtil.CreateContextMenu(menuAnchor, function(_, rootDescription)
            rootDescription:CreateTitle(L["CONFIG_PRIMARY_HEARTHSTONE_MENU_TITLE"])

            for i = 1, #options do
                local option = options[i]
                local icon = option.icon or DEFAULT_ICON_TEXTURE
                local optionLabel = string.format(
                    "|T%s:16:16:0:0|t %s",
                    icon,
                    option.name or string.format(L["ITEM_FALLBACK_FMT"], tostring(option.itemID))
                )
                if option.itemID == selectedID then
                    optionLabel = "|cff81c784" .. optionLabel .. "|r"
                end

                rootDescription:CreateButton(optionLabel, function()
                    vesperTools:SetConfiguredPrimaryHearthstoneID(option.itemID)
                    self:RefreshControls()
                    self:NotifyConfigChanged()
                end)
            end
        end)
        return
    end

    local currentIndex = 1
    for i = 1, #options do
        if options[i].itemID == selectedID then
            currentIndex = i
            break
        end
    end

    local nextIndex = currentIndex + 1
    if nextIndex > #options then
        nextIndex = 1
    end

    vesperTools:SetConfiguredPrimaryHearthstoneID(options[nextIndex].itemID)
    self:RefreshControls()
    self:NotifyConfigChanged()
end

-- Build one row widget used inside the scrollable whitelist dropdown.
function Configuration:CreateFontMenuRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(FONT_MENU_ROW_HEIGHT)
    row:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    row:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    row:GetNormalTexture():SetVertexColor(0.08, 0.08, 0.1, 0.92)
    row:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    row:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)

    local text = row:CreateFontString(nil, "ARTWORK")
    text:SetPoint("LEFT", row, "LEFT", 8, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    setFontStringTextSafe(text, "", 13, "", GameFontHighlightSmall)
    row.Text = text

    local check = row:CreateTexture(nil, "OVERLAY", nil, 2)
    check:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    check:SetSize(14, 14)
    check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    check:SetVertexColor(0.35, 1, 0.35, 1)
    check:Hide()
    row.Check = check

    return row
end

function Configuration:CreateRosterOnlineBlacklistMenuRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROSTER_BLACKLIST_MENU_ROW_HEIGHT)
    row:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    row:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    row:GetNormalTexture():SetVertexColor(0.08, 0.08, 0.1, 0.92)
    row:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    row:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)

    local text = row:CreateFontString(nil, "ARTWORK")
    text:SetPoint("LEFT", row, "LEFT", 8, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    setFontStringTextSafe(text, "", 12, "", GameFontHighlightSmall)
    row.Text = text

    local check = row:CreateTexture(nil, "OVERLAY", nil, 2)
    check:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    check:SetSize(14, 14)
    check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    check:SetVertexColor(0.35, 1, 0.35, 1)
    check:Hide()
    row.Check = check

    return row
end

function Configuration:CreateToyWhitelistMenuRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(TOY_MENU_ROW_HEIGHT)
    row:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    row:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    row:GetNormalTexture():SetVertexColor(0.08, 0.08, 0.1, 0.92)
    row:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    row:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)

    local icon = row:CreateTexture(nil, "OVERLAY", nil, 1)
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 6, 0)
    icon:SetDesaturated(false)
    icon:SetAlpha(1)
    icon:SetVertexColor(1, 1, 1, 1)
    row.Icon = icon

    local text = row:CreateFontString(nil, "ARTWORK")
    text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    setFontStringTextSafe(text, "", 12, "", GameFontHighlightSmall)
    row.Text = text

    -- Right-side whitelist indicator uses a dedicated texture (font-independent).
    local check = row:CreateTexture(nil, "OVERLAY", nil, 2)
    check:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    check:SetSize(14, 14)
    check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    check:SetVertexColor(0.35, 1, 0.35, 1)
    check:Hide()
    row.Check = check

    return row
end

function Configuration:CreateCurrencyBarMenuRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(CURRENCY_MENU_ROW_HEIGHT)
    row:SetNormalTexture("Interface\\Buttons\\WHITE8x8")
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    row:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    row:GetNormalTexture():SetVertexColor(0.08, 0.08, 0.1, 0.92)
    row:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    row:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)

    local icon = row:CreateTexture(nil, "OVERLAY", nil, 1)
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", row, "LEFT", 6, 0)
    icon:SetVertexColor(1, 1, 1, 1)
    row.Icon = icon

    local text = row:CreateFontString(nil, "ARTWORK")
    text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    setFontStringTextSafe(text, "", 12, "", GameFontHighlightSmall)
    row.Text = text

    local check = row:CreateTexture(nil, "OVERLAY", nil, 2)
    check:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    check:SetSize(14, 14)
    check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    check:SetVertexColor(0.35, 1, 0.35, 1)
    check:Hide()
    row.Check = check

    return row
end

function Configuration:EnsureFontMenuFrame(anchorButton)
    if self.fontMenuFrame then
        return self.fontMenuFrame
    end

    local width = (anchorButton and anchorButton.GetWidth and anchorButton:GetWidth()) or 420
    local height = (FONT_MENU_MAX_VISIBLE_ROWS * FONT_MENU_ROW_HEIGHT) + 20

    local menu = CreateFrame("Frame", "vesperToolsFontMenu", UIParent, "BackdropTemplate")
    menu:SetSize(width, height)
    vesperTools:ApplyAddonWindowLayer(menu, 80)
    menu:SetClampedToScreen(true)
    vesperTools:ApplyRoundedWindowBackdrop(menu)
    menu:SetBackdropColor(0.05, 0.05, 0.06, 0.98)
    menu:SetBackdropBorderColor(0.2, 0.2, 0.24, 1)
    menu:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -28, 6)
    menu.ScrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetPoint("TOPRIGHT", 0, 0)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    menu.Content = content
    menu.Rows = {}

    menu:EnableMouseWheel(true)
    menu:SetScript("OnMouseWheel", function(selfMenu, delta)
        local maxScroll = math.max(0, (selfMenu.Content:GetHeight() or 0) - selfMenu.ScrollFrame:GetHeight())
        local nextScroll = (selfMenu.ScrollFrame:GetVerticalScroll() or 0) - (delta * 24)
        if nextScroll < 0 then
            nextScroll = 0
        elseif nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        selfMenu.ScrollFrame:SetVerticalScroll(nextScroll)
    end)

    self.fontMenuFrame = menu
    return menu
end

function Configuration:EnsureRosterOnlineBlacklistMenuFrame(anchorButton)
    if self.rosterOnlineBlacklistMenuFrame then
        return self.rosterOnlineBlacklistMenuFrame
    end

    local width = (anchorButton and anchorButton.GetWidth and anchorButton:GetWidth()) or 396
    local visibleRows = ROSTER_BLACKLIST_MENU_MAX_VISIBLE_ROWS + 1
    local height = (visibleRows * ROSTER_BLACKLIST_MENU_ROW_HEIGHT) + 20

    local menu = CreateFrame("Frame", "vesperToolsRosterOnlineBlacklistMenu", UIParent, "BackdropTemplate")
    menu:SetSize(width, height)
    vesperTools:ApplyAddonWindowLayer(menu, 80)
    menu:SetClampedToScreen(true)
    vesperTools:ApplyRoundedWindowBackdrop(menu)
    menu:SetBackdropColor(0.05, 0.05, 0.06, 0.98)
    menu:SetBackdropBorderColor(0.2, 0.2, 0.24, 1)
    menu:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -28, 6)
    menu.ScrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetPoint("TOPRIGHT", 0, 0)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    menu.Content = content
    menu.Rows = {}

    menu:EnableMouseWheel(true)
    menu:SetScript("OnMouseWheel", function(selfMenu, delta)
        local maxScroll = math.max(0, (selfMenu.Content:GetHeight() or 0) - selfMenu.ScrollFrame:GetHeight())
        local nextScroll = (selfMenu.ScrollFrame:GetVerticalScroll() or 0) - (delta * 24)
        if nextScroll < 0 then
            nextScroll = 0
        elseif nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        selfMenu.ScrollFrame:SetVerticalScroll(nextScroll)
    end)

    self.rosterOnlineBlacklistMenuFrame = menu
    return menu
end

-- Create the scrollable toy-whitelist dropdown frame once and keep it reusable.
function Configuration:EnsureToyWhitelistMenuFrame(anchorButton)
    if self.toyWhitelistMenuFrame then
        return self.toyWhitelistMenuFrame
    end

    local width = (anchorButton and anchorButton.GetWidth and anchorButton:GetWidth()) or 396
    local visibleRows = TOY_MENU_MAX_VISIBLE_ROWS + 1
    local height = (visibleRows * TOY_MENU_ROW_HEIGHT) + 20

    local menu = CreateFrame("Frame", "vesperToolsToyWhitelistMenu", UIParent, "BackdropTemplate")
    menu:SetSize(width, height)
    vesperTools:ApplyAddonWindowLayer(menu, 80)
    menu:SetClampedToScreen(true)
    vesperTools:ApplyRoundedWindowBackdrop(menu)
    menu:SetBackdropColor(0.05, 0.05, 0.06, 0.98)
    menu:SetBackdropBorderColor(0.2, 0.2, 0.24, 1)
    menu:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -28, 6)
    menu.ScrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetPoint("TOPRIGHT", 0, 0)
    -- Keep width driven by TOPLEFT/TOPRIGHT anchors; only seed a minimal height.
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    menu.Content = content
    menu.Rows = {}

    menu:EnableMouseWheel(true)
    menu:SetScript("OnMouseWheel", function(selfMenu, delta)
        local maxScroll = math.max(0, (selfMenu.Content:GetHeight() or 0) - selfMenu.ScrollFrame:GetHeight())
        local nextScroll = (selfMenu.ScrollFrame:GetVerticalScroll() or 0) - (delta * 24)
        if nextScroll < 0 then
            nextScroll = 0
        elseif nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        selfMenu.ScrollFrame:SetVerticalScroll(nextScroll)
    end)

    self.toyWhitelistMenuFrame = menu
    return menu
end

function Configuration:EnsureCurrencyBarMenuFrame(anchorButton)
    if self.bagsCurrencyMenuFrame then
        return self.bagsCurrencyMenuFrame
    end

    local width = (anchorButton and anchorButton.GetWidth and anchorButton:GetWidth()) or 396
    local visibleRows = CURRENCY_MENU_MAX_VISIBLE_ROWS + 1
    local height = (visibleRows * CURRENCY_MENU_ROW_HEIGHT) + 20

    local menu = CreateFrame("Frame", "vesperToolsCurrencyBarMenu", UIParent, "BackdropTemplate")
    menu:SetSize(width, height)
    vesperTools:ApplyAddonWindowLayer(menu, 80)
    menu:SetClampedToScreen(true)
    vesperTools:ApplyRoundedWindowBackdrop(menu)
    menu:SetBackdropColor(0.05, 0.05, 0.06, 0.98)
    menu:SetBackdropBorderColor(0.2, 0.2, 0.24, 1)
    menu:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -28, 6)
    menu.ScrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetPoint("TOPRIGHT", 0, 0)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    menu.Content = content
    menu.Rows = {}

    menu:EnableMouseWheel(true)
    menu:SetScript("OnMouseWheel", function(selfMenu, delta)
        local maxScroll = math.max(0, (selfMenu.Content:GetHeight() or 0) - selfMenu.ScrollFrame:GetHeight())
        local nextScroll = (selfMenu.ScrollFrame:GetVerticalScroll() or 0) - (delta * 24)
        if nextScroll < 0 then
            nextScroll = 0
        elseif nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        selfMenu.ScrollFrame:SetVerticalScroll(nextScroll)
    end)

    self.bagsCurrencyMenuFrame = menu
    return menu
end

function Configuration:RefreshFontMenu()
    local menu = self.fontMenuFrame
    if not menu then
        return
    end

    local profile = ensureProfile()
    if not profile then
        return
    end

    local options = vesperTools:GetFontOptions()
    local hasOptions = type(options) == "table" and #options > 0
    local rowCount = hasOptions and #options or 1
    local visibleRows = math.min(rowCount, FONT_MENU_MAX_VISIBLE_ROWS)
    menu:SetHeight((visibleRows * FONT_MENU_ROW_HEIGHT) + 20)

    local contentWidth = math.floor((tonumber(menu.ScrollFrame:GetWidth()) or 0) + 0.5)
    if contentWidth <= 0 then
        contentWidth = math.floor((tonumber(menu:GetWidth()) or 420) - 34)
    end
    if contentWidth < 60 then
        contentWidth = 60
    end
    menu.Content:SetWidth(contentWidth)

    local selectedKey = vesperTools:GetConfiguredFontKey()
    local selectedIndex = 1

    for i = 1, rowCount do
        local row = menu.Rows[i]
        if not row then
            row = self:CreateFontMenuRow(menu.Content)
            menu.Rows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu.Content, "TOPLEFT", 0, -((i - 1) * FONT_MENU_ROW_HEIGHT))
        row:SetWidth(contentWidth)

        if not hasOptions then
            setFontStringTextSafe(row.Text, "No fonts available", 12, "", GameFontHighlightSmall)
            row.Text:SetTextColor(0.8, 0.8, 0.8, 1)
            row.Check:Hide()
            row:SetScript("OnClick", nil)
        else
            local option = options[i]
            local isSelected = option.key == selectedKey or option.path == profile.style.fontPath
            if isSelected then
                selectedIndex = i
            end

            setFontStringTextWithFontPathSafe(row.Text, option.label or "", option.path, 13, "", GameFontHighlightSmall)
            if isSelected then
                row.Text:SetTextColor(0.86, 1, 0.86, 1)
                row.Check:Show()
            else
                row.Text:SetTextColor(0.92, 0.94, 0.98, 1)
                row.Check:Hide()
            end

            row:SetScript("OnClick", function()
                profile.style.fontName = option.key or option.label
                profile.style.fontPath = option.path
                self:RefreshControls()
                self:NotifyConfigChanged()
                menu:Hide()
            end)
        end

        row:Show()
    end

    for i = rowCount + 1, #menu.Rows do
        menu.Rows[i]:Hide()
    end

    local totalHeight = rowCount * FONT_MENU_ROW_HEIGHT
    local frameHeight = menu.ScrollFrame:GetHeight() or 0
    local maxScroll = math.max(0, totalHeight - frameHeight)
    local desiredScroll = math.max(0, ((selectedIndex - 1) * FONT_MENU_ROW_HEIGHT) - math.floor((frameHeight - FONT_MENU_ROW_HEIGHT) * 0.5))

    menu.Content:SetHeight(math.max(frameHeight, totalHeight))
    menu.ScrollFrame:SetVerticalScroll(math.min(maxScroll, desiredScroll))
end

function Configuration:RefreshRosterOnlineBlacklistMenu()
    local menu = self.rosterOnlineBlacklistMenuFrame
    if not menu then
        return
    end

    local onlineMembers = vesperTools:GetOnlineGuildMembers(true)
    local blacklist = vesperTools:GetRosterOnlineCountBlacklist()
    local blacklistCount = vesperTools:GetRosterOnlineCountBlacklistCount()
    local hasOnlineMembers = type(onlineMembers) == "table" and #onlineMembers > 0
    local sortedMembers = {}

    if hasOnlineMembers then
        for i = 1, #onlineMembers do
            sortedMembers[i] = onlineMembers[i]
        end
        table.sort(sortedMembers, function(a, b)
            local aSelected = blacklist[a.fullName] and 1 or 0
            local bSelected = blacklist[b.fullName] and 1 or 0
            if aSelected ~= bSelected then
                return aSelected > bSelected
            end

            local aLabel = (Ambiguate and Ambiguate(a.fullName or a.name or "", "guild")) or a.name or a.fullName or ""
            local bLabel = (Ambiguate and Ambiguate(b.fullName or b.name or "", "guild")) or b.name or b.fullName or ""
            if aLabel ~= bLabel then
                return aLabel < bLabel
            end
            return (a.fullName or "") < (b.fullName or "")
        end)
    end

    local rowCount = 1
    if hasOnlineMembers then
        rowCount = #sortedMembers + 1
    elseif blacklistCount > 0 then
        rowCount = 2
    end

    local contentWidth = math.floor((tonumber(menu.ScrollFrame:GetWidth()) or 0) + 0.5)
    if contentWidth <= 0 then
        contentWidth = math.floor((tonumber(menu:GetWidth()) or 396) - 34)
    end
    if contentWidth < 40 then
        contentWidth = 40
    end
    menu.Content:SetWidth(contentWidth)

    for i = 1, rowCount do
        local row = menu.Rows[i]
        if not row then
            row = self:CreateRosterOnlineBlacklistMenuRow(menu.Content)
            menu.Rows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu.Content, "TOPLEFT", 0, -((i - 1) * ROSTER_BLACKLIST_MENU_ROW_HEIGHT))
        row:SetWidth(contentWidth)

        if i == 1 and (hasOnlineMembers or blacklistCount > 0) then
            setFontStringTextSafe(row.Text, L["CONFIG_CLEAR_BLACKLIST"], 12, "", GameFontHighlightSmall)
            row.Text:SetTextColor(1, 0.75, 0.75, 1)
            row.Check:Hide()
            row:SetScript("OnClick", function()
                vesperTools:ClearRosterOnlineCountBlacklist()
                self:RefreshControls()
                self:NotifyConfigChanged()
                self:RefreshRosterOnlineBlacklistMenu()
            end)
        elseif not hasOnlineMembers then
            setFontStringTextSafe(row.Text, L["CONFIG_ROSTER_ONLINE_BLACKLIST_NO_PLAYERS"], 12, "", GameFontHighlightSmall)
            row.Text:SetTextColor(0.8, 0.8, 0.8, 1)
            row.Check:Hide()
            row:SetScript("OnClick", nil)
        else
            local member = sortedMembers[i - 1]
            local isSelected = blacklist[member.fullName] and true or false
            local label = (Ambiguate and Ambiguate(member.fullName or member.name or "", "guild")) or member.name or member.fullName
            if type(member.zone) == "string" and member.zone ~= "" and member.zone ~= UNKNOWN then
                label = string.format("%s |cff8c98a4(%s)|r", label, member.zone)
            end

            setFontStringTextSafe(row.Text, label, 12, "", GameFontHighlightSmall)
            if isSelected then
                row.Text:SetTextColor(0.86, 1, 0.86, 1)
                row.Check:Show()
            else
                row.Text:SetTextColor(0.92, 0.95, 1, 1)
                row.Check:Hide()
            end
            row:SetScript("OnClick", function()
                vesperTools:SetRosterOnlineCountBlacklisted(member.fullName, not isSelected)
                self:RefreshControls()
                self:NotifyConfigChanged()
                self:RefreshRosterOnlineBlacklistMenu()
            end)
        end

        row:Show()
    end

    for i = rowCount + 1, #menu.Rows do
        menu.Rows[i]:Hide()
    end

    local totalHeight = rowCount * ROSTER_BLACKLIST_MENU_ROW_HEIGHT
    menu.Content:SetHeight(math.max(menu.ScrollFrame:GetHeight(), totalHeight))
    menu.ScrollFrame:SetVerticalScroll(0)
end

-- Fill the scrollable toy-whitelist dropdown with dynamic rows.
function Configuration:RefreshToyWhitelistMenu()
    local menu = self.toyWhitelistMenuFrame
    if not menu then
        return
    end

    local profile = ensureProfile()
    if not profile then
        return
    end

    local ownedToyOptions = vesperTools:GetOwnedToyOptions()
    local hasOwnedToys = type(ownedToyOptions) == "table" and #ownedToyOptions > 0

    -- Sort list so whitelisted entries are always first, then alphabetically by name.
    local sortedOptions = {}
    local whitelistMap = {}
    local whitelist = vesperTools:GetConfiguredToyWhitelist()
    local whitelistLimit = vesperTools:GetToyWhitelistLimit()
    local whitelistCount = #whitelist
    for i = 1, #whitelist do
        whitelistMap[whitelist[i]] = true
    end
    if hasOwnedToys then
        for i = 1, #ownedToyOptions do
            sortedOptions[i] = ownedToyOptions[i]
        end
        table.sort(sortedOptions, function(a, b)
            local aSelected = whitelistMap[a.itemID] and 1 or 0
            local bSelected = whitelistMap[b.itemID] and 1 or 0
            if aSelected ~= bSelected then
                return aSelected > bSelected
            end
            return (a.name or "") < (b.name or "")
        end)
    end

    local rowCount = hasOwnedToys and (#sortedOptions + 1) or 1

    -- Resolve a stable drawable width for scroll content/rows.
    local contentWidth = math.floor((tonumber(menu.ScrollFrame:GetWidth()) or 0) + 0.5)
    if contentWidth <= 0 then
        contentWidth = math.floor((tonumber(menu:GetWidth()) or 396) - 34)
    end
    if contentWidth < 40 then
        contentWidth = 40
    end
    menu.Content:SetWidth(contentWidth)

    for i = 1, rowCount do
        local row = menu.Rows[i]
        if not row then
            row = self:CreateToyWhitelistMenuRow(menu.Content)
            menu.Rows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu.Content, "TOPLEFT", 0, -((i - 1) * TOY_MENU_ROW_HEIGHT))
        row:SetWidth(contentWidth)

        if not hasOwnedToys then
            row.Icon:SetTexture(DEFAULT_ICON_TEXTURE)
            row.Icon:SetVertexColor(0.6, 0.6, 0.6, 1)
            row.Icon:SetDesaturated(false)
            row.Icon:SetAlpha(1)
            setFontStringTextSafe(row.Text, L["CONFIG_NO_OWNED_TOYS_AVAILABLE"], 12, "", GameFontHighlightSmall)
            row.Text:SetTextColor(0.8, 0.8, 0.8, 1)
            row.Check:Hide()
            row:SetScript("OnClick", nil)
        elseif i == 1 then
            row.Icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            row.Icon:SetVertexColor(1, 0.4, 0.4, 1)
            row.Icon:SetDesaturated(false)
            row.Icon:SetAlpha(1)
            setFontStringTextSafe(row.Text, L["CONFIG_CLEAR_WHITELIST"], 12, "", GameFontHighlightSmall)
            row.Text:SetTextColor(1, 0.75, 0.75, 1)
            row.Check:Hide()
            row:SetScript("OnClick", function()
                profile.portals.utilityToyWhitelist = {}
                self:RefreshControls()
                self:NotifyConfigChanged()
                self:RefreshToyWhitelistMenu()
            end)
        else
            local option = sortedOptions[i - 1]
            local isSelected = whitelistMap[option.itemID] and true or false
            local icon = option.icon or DEFAULT_ICON_TEXTURE
            local label = option.name
            if type(label) ~= "string" or label == "" then
                label = string.format(L["ITEM_FALLBACK_FMT"], tostring(option.itemID))
            end

            row.Icon:SetTexture(icon)
            row.Icon:SetVertexColor(1, 1, 1, 1)
            row.Icon:SetDesaturated(false)
            row.Icon:SetAlpha(1)
            setFontStringTextSafe(row.Text, label, 12, "", GameFontHighlightSmall)
            row.Text:SetTextColor(0.92, 0.95, 1, 1)
            if isSelected then
                row.Check:Show()
            else
                row.Check:Hide()
            end
            row:SetScript("OnClick", function()
                if not isSelected and whitelistCount >= whitelistLimit then
                    self:SetToyLookupStatus(string.format(L["CONFIG_TOY_WHITELIST_LIMIT_FMT"], whitelistLimit), 1, 0.4, 0.4)
                    return
                end

                vesperTools:SetToyWhitelisted(option.itemID, not isSelected)
                self:RefreshControls()
                self:NotifyConfigChanged()
                self:RefreshToyWhitelistMenu()
            end)
        end

        row:Show()
    end

    for i = rowCount + 1, #menu.Rows do
        menu.Rows[i]:Hide()
    end

    local totalHeight = rowCount * TOY_MENU_ROW_HEIGHT
    menu.Content:SetHeight(math.max(menu.ScrollFrame:GetHeight(), totalHeight))
    menu.ScrollFrame:SetVerticalScroll(0)
end

function Configuration:RefreshCurrencyBarMenu()
    local menu = self.bagsCurrencyMenuFrame
    if not menu then
        return
    end

    local bagsProfile = ensureBagsProfile()
    if not bagsProfile then
        return
    end

    local options = vesperTools:GetCurrencyBarSelectionOptions()
    local hasOptions = type(options) == "table" and #options > 0
    local selectedIDs = vesperTools:GetConfiguredBagCurrencyIDs()
    local selectedMap = {}
    local limit = vesperTools:GetBagCurrencyBarLimit()

    for i = 1, #selectedIDs do
        selectedMap[selectedIDs[i]] = true
    end

    local sortedOptions = {}
    if hasOptions then
        for i = 1, #options do
            sortedOptions[i] = options[i]
        end
        table.sort(sortedOptions, function(a, b)
            local aSelected = selectedMap[a.currencyID] and 1 or 0
            local bSelected = selectedMap[b.currencyID] and 1 or 0
            if aSelected ~= bSelected then
                return aSelected > bSelected
            end
            return (a.name or "") < (b.name or "")
        end)
    end

    local rowCount = hasOptions and (#sortedOptions + 1) or 1
    local contentWidth = math.floor((tonumber(menu.ScrollFrame:GetWidth()) or 0) + 0.5)
    if contentWidth <= 0 then
        contentWidth = math.floor((tonumber(menu:GetWidth()) or 396) - 34)
    end
    if contentWidth < 40 then
        contentWidth = 40
    end
    menu.Content:SetWidth(contentWidth)

    for i = 1, rowCount do
        local row = menu.Rows[i]
        if not row then
            row = self:CreateCurrencyBarMenuRow(menu.Content)
            menu.Rows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu.Content, "TOPLEFT", 0, -((i - 1) * CURRENCY_MENU_ROW_HEIGHT))
        row:SetWidth(contentWidth)

        if not hasOptions then
            row.Icon:SetTexture(DEFAULT_ICON_TEXTURE)
            row.Icon:SetVertexColor(0.6, 0.6, 0.6, 1)
            setFontStringTextSafe(row.Text, L["CONFIG_BAGS_CURRENCY_BAR_NONE_AVAILABLE"], 12, "", GameFontHighlightSmall)
            row.Text:SetTextColor(0.8, 0.8, 0.8, 1)
            row.Check:Hide()
            row:SetScript("OnClick", nil)
        elseif i == 1 then
            row.Icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
            row.Icon:SetVertexColor(1, 0.82, 0.12, 1)
            setFontStringTextSafe(row.Text, L["CONFIG_BAGS_CURRENCY_BAR_USE_TRACKED"], 12, "", GameFontHighlightSmall)
            row.Text:SetTextColor(0.84, 0.9, 1, 1)
            if #selectedIDs == 0 then
                row.Check:Show()
            else
                row.Check:Hide()
            end
            row:SetScript("OnClick", function()
                vesperTools:ClearConfiguredBagCurrencies()
                self:SetBagsCurrencyBarStatus(L["CONFIG_BAGS_CURRENCY_BAR_HINT"], 0.78, 0.82, 0.9)
                self:RefreshControls()
                self:NotifyConfigChanged()
                self:RefreshCurrencyBarMenu()
            end)
        else
            local option = sortedOptions[i - 1]
            local isSelected = selectedMap[option.currencyID] and true or false
            row.Icon:SetTexture(option.iconFileID or DEFAULT_ICON_TEXTURE)
            row.Icon:SetVertexColor(1, 1, 1, 1)
            setFontStringTextSafe(row.Text, option.name or string.format(L["ITEM_FALLBACK_FMT"], tostring(option.currencyID)), 12, "", GameFontHighlightSmall)
            row.Text:SetTextColor(0.92, 0.95, 1, 1)
            if isSelected then
                row.Check:Show()
            else
                row.Check:Hide()
            end
            row:SetScript("OnClick", function()
                if not isSelected and #selectedIDs >= limit then
                    self:SetBagsCurrencyBarStatus(string.format(L["CONFIG_BAGS_CURRENCY_BAR_LIMIT_FMT"], limit), 1, 0.4, 0.4)
                    return
                end

                if vesperTools:SetBagCurrencySelected(option.currencyID, not isSelected) then
                    self:SetBagsCurrencyBarStatus(L["CONFIG_BAGS_CURRENCY_BAR_HINT"], 0.78, 0.82, 0.9)
                    self:RefreshControls()
                    self:NotifyConfigChanged()
                    self:RefreshCurrencyBarMenu()
                end
            end)
        end

        row:Show()
    end

    for i = rowCount + 1, #menu.Rows do
        menu.Rows[i]:Hide()
    end

    local totalHeight = rowCount * CURRENCY_MENU_ROW_HEIGHT
    menu.Content:SetHeight(math.max(menu.ScrollFrame:GetHeight(), totalHeight))
    menu.ScrollFrame:SetVerticalScroll(0)
end

-- Open a scrollable whitelist selector for utility toys.
-- This keeps large toy collections usable by limiting visible rows.
function Configuration:OpenToyWhitelistPicker(anchorButton)
    local profile = ensureProfile()
    if not profile then
        return
    end

    local menu = self:EnsureToyWhitelistMenuFrame(anchorButton)
    if not menu then
        return
    end

    if menu:IsShown() and menu._anchorButton == anchorButton then
        menu:Hide()
        return
    end

    menu._anchorButton = anchorButton
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -4)
    menu:SetWidth(anchorButton:GetWidth() or 396)
    menu:Show()
    menu:Raise()
    self:RefreshToyWhitelistMenu()
end

function Configuration:OpenRosterOnlineBlacklistPicker(anchorButton)
    local profile = ensureProfile()
    if not profile then
        return
    end

    if IsInGuild() then
        vesperTools:RequestGuildRosterUpdate()
    end

    local menu = self:EnsureRosterOnlineBlacklistMenuFrame(anchorButton)
    if not menu then
        return
    end

    if menu:IsShown() and menu._anchorButton == anchorButton then
        menu:Hide()
        return
    end

    menu._anchorButton = anchorButton
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -4)
    menu:SetWidth(anchorButton:GetWidth() or 396)
    menu:Show()
    menu:Raise()
    self:RefreshRosterOnlineBlacklistMenu()
end

function Configuration:OpenCurrencyBarPicker(anchorButton)
    if not ensureBagsProfile() then
        return
    end

    local menu = self:EnsureCurrencyBarMenuFrame(anchorButton)
    if not menu then
        return
    end

    if menu:IsShown() and menu._anchorButton == anchorButton then
        menu:Hide()
        return
    end

    menu._anchorButton = anchorButton
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", 0, -4)
    menu:SetWidth(anchorButton:GetWidth() or 396)
    menu:Show()
    menu:Raise()
    self:RefreshCurrencyBarMenu()
end

-- Update helper text for toy-name lookup/add flow.
function Configuration:SetToyLookupStatus(text, r, g, b)
    if not self.toyLookupStatusText then
        return
    end

    setFontStringTextSafe(self.toyLookupStatusText, text or "", 11, "", GameFontHighlightSmall)
    self.toyLookupStatusText:SetTextColor(r or 0.78, g or 0.82, b or 0.9, 1)
end

-- Match an owned toy by a typed name query.
-- Match strategy: exact -> prefix -> contains (case-insensitive).
function Configuration:FindOwnedToyByName(query, ownedToyOptions)
    if type(query) ~= "string" or query == "" then
        return nil
    end
    if type(ownedToyOptions) ~= "table" or #ownedToyOptions == 0 then
        return nil
    end

    local loweredQuery = string.lower(query)

    for i = 1, #ownedToyOptions do
        local option = ownedToyOptions[i]
        local optionName = type(option.name) == "string" and option.name or ""
        if string.lower(optionName) == loweredQuery then
            return option
        end
    end

    for i = 1, #ownedToyOptions do
        local option = ownedToyOptions[i]
        local optionName = type(option.name) == "string" and option.name or ""
        if string.find(string.lower(optionName), loweredQuery, 1, true) == 1 then
            return option
        end
    end

    for i = 1, #ownedToyOptions do
        local option = ownedToyOptions[i]
        local optionName = type(option.name) == "string" and option.name or ""
        if string.find(string.lower(optionName), loweredQuery, 1, true) then
            return option
        end
    end

    return nil
end

-- Add toy to whitelist using free-text toy name input.
function Configuration:AddToyToWhitelistByName()
    if not self.toyNameInput then
        return
    end

    local query = strtrim(self.toyNameInput:GetText() or "")
    if query == "" then
        self:SetToyLookupStatus(L["CONFIG_ENTER_TOY_NAME"], 1, 0.7, 0.2)
        return
    end

    local whitelistLimit = vesperTools:GetToyWhitelistLimit()
    local whitelistCount = #vesperTools:GetConfiguredToyWhitelist()

    -- Support direct numeric itemID entry as a reliable fallback path.
    local numericID = tonumber(query)
    if numericID and numericID > 0 then
        local toyID = math.floor(numericID + 0.5)
        if not (PlayerHasToy and PlayerHasToy(toyID)) then
            self:SetToyLookupStatus(L["CONFIG_TOY_ID_NOT_OWNED"], 1, 0.4, 0.4)
            return
        end

        if vesperTools:IsToyWhitelisted(toyID) then
            self:SetToyLookupStatus(string.format(L["CONFIG_ALREADY_WHITELISTED_ITEM_FMT"], tostring(toyID)), 1, 0.7, 0.2)
            return
        end

        if whitelistCount >= whitelistLimit then
            self:SetToyLookupStatus(string.format(L["CONFIG_TOY_WHITELIST_LIMIT_FMT"], whitelistLimit), 1, 0.4, 0.4)
            return
        end

        vesperTools:SetToyWhitelisted(toyID, true)

        local toyName = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(toyID))
            or GetItemInfo(toyID)
            or string.format(L["ITEM_FALLBACK_FMT"], tostring(toyID))
        self:SetToyLookupStatus(string.format(L["CONFIG_ADDED_FMT"], toyName), 0.5, 1, 0.5)
        self.toyNameInput:SetText(toyName)
        self:RefreshControls()
        self:NotifyConfigChanged()
        return
    end

    local ownedToyOptions = vesperTools:GetOwnedToyOptions()
    if #ownedToyOptions == 0 then
        self:SetToyLookupStatus(L["CONFIG_TOY_LIST_NOT_READY"], 1, 0.7, 0.2)
        return
    end

    local match = self:FindOwnedToyByName(query, ownedToyOptions)
    if not match then
        self:SetToyLookupStatus(L["CONFIG_NO_OWNED_TOY_MATCH"], 1, 0.4, 0.4)
        return
    end

    if vesperTools:IsToyWhitelisted(match.itemID) then
        self:SetToyLookupStatus(string.format(L["CONFIG_ALREADY_WHITELISTED_FMT"], match.name or L["TOY_FALLBACK"]), 1, 0.7, 0.2)
        return
    end

    if whitelistCount >= whitelistLimit then
        self:SetToyLookupStatus(string.format(L["CONFIG_TOY_WHITELIST_LIMIT_FMT"], whitelistLimit), 1, 0.4, 0.4)
        return
    end

    vesperTools:SetToyWhitelisted(match.itemID, true)
    self:SetToyLookupStatus(string.format(L["CONFIG_ADDED_FMT"], match.name or L["TOY_FALLBACK"]), 0.5, 1, 0.5)
    self.toyNameInput:SetText(match.name or "")
    self:RefreshControls()
    self:NotifyConfigChanged()
end

-- Build the custom configuration panel once.
-- The panel uses a minimal dark style aligned with mummuFrames aesthetics.
function Configuration:BuildPanel()
    if self.panel then
        return
    end

    local panel = CreateFrame("Frame", "vesperToolsConfigWindow", UIParent, "BackdropTemplate")
    panel:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    vesperTools:ApplyAddonWindowLayer(panel, 50)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    vesperTools:ApplyRoundedWindowBackdrop(panel)
    panel:SetBackdropColor(0.05, 0.05, 0.06, 0.95)
    panel:SetBackdropBorderColor(0.2, 0.2, 0.24, 1)
    panel:Hide()

    local function closePanel()
        if panel and panel:IsShown() then
            panel:Hide()
        end
    end

    -- Header visuals.
    local headerFill = panel:CreateTexture(nil, "ARTWORK")
    headerFill:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    headerFill:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    headerFill:SetHeight(34)
    headerFill:SetColorTexture(1, 1, 1, 0.04)

    local headerLine = panel:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT", headerFill, "BOTTOMLEFT", 0, 0)
    headerLine:SetPoint("TOPRIGHT", headerFill, "BOTTOMRIGHT", 0, 0)
    headerLine:SetHeight(1)
    headerLine:SetColorTexture(1, 1, 1, 0.08)

    -- Invisible drag handle spanning the title area.
    local dragHandle = CreateFrame("Frame", nil, panel)
    dragHandle:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -6)
    dragHandle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -42, -6)
    dragHandle:SetHeight(24)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        panel:StartMoving()
    end)
    dragHandle:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
    end)

    local closeButton = vesperTools:CreateModernCloseButton(panel, closePanel, {
        size = 22,
        iconScale = 0.5,
        backgroundAlpha = 0.05,
        borderAlpha = 0.08,
        hoverAlpha = 0.14,
        pressedAlpha = 0.2,
    })
    closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -6)

    -- Window headings.
    local title = panel:CreateFontString(nil, "ARTWORK")
    title:SetPoint("TOPLEFT", 16, -10)
    setFontStringTextSafe(title, "vesperTools", 24, "", GameFontHighlightLarge)

    local subtitle = panel:CreateFontString(nil, "ARTWORK")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    setFontStringTextSafe(subtitle, L["CONFIG_TITLE"], 12, "", GameFontHighlightSmall)
    subtitle:SetTextColor(0.86, 0.86, 0.86, 1)

    local sharedLabel = panel:CreateFontString(nil, "ARTWORK")
    sharedLabel:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    setFontStringTextSafe(sharedLabel, L["CONFIG_SHARED_FONT_FAMILY"], 12, "OUTLINE", GameFontHighlight)

    local fontDropdown = self:CreateFlatDropdown(
        "vesperToolsConfigFontDropdown",
        panel,
        sharedLabel,
        -6,
        420,
        function(button)
            self:OpenFontPicker(button)
        end
    )
    local fontText = fontDropdown.Text

    -- Tab row: each frame now has its own settings pane.
    local rosterTabButton = self:CreateTabButton(panel, "roster", L["CONFIG_TAB_ROSTER"], fontDropdown, 0, -20, 84)
    self:CreateTabButton(panel, "portals", L["CONFIG_TAB_PORTALS"], fontDropdown, 86, -20, 84)
    self:CreateTabButton(panel, "bestKeys", L["CONFIG_TAB_BEST_KEYS"], fontDropdown, 172, -20, 84)
    self:CreateTabButton(panel, "bags", L["CONFIG_TAB_BAGS"], fontDropdown, 258, -20, 84)
    local bankTabButton = self:CreateTabButton(panel, "bank", L["CONFIG_TAB_BANK"], fontDropdown, 344, -20, 84)

    local contentRoot = CreateFrame("Frame", nil, panel)
    contentRoot:SetPoint("TOPLEFT", rosterTabButton, "BOTTOMLEFT", 0, -10)
    contentRoot:SetPoint("TOPRIGHT", bankTabButton, "BOTTOMRIGHT", 0, -10)
    contentRoot:SetPoint("BOTTOM", panel, "BOTTOM", 0, 14)

    -- Separate content containers are shown/hidden by active tab state.
    local rosterTab = CreateFrame("Frame", nil, contentRoot)
    rosterTab:SetAllPoints()

    local portalsTab = CreateFrame("Frame", nil, contentRoot)
    portalsTab:SetAllPoints()

    local bestKeysTab = CreateFrame("Frame", nil, contentRoot)
    bestKeysTab:SetAllPoints()

    local bagsTab = CreateFrame("Frame", nil, contentRoot)
    bagsTab:SetAllPoints()

    local bankTab = CreateFrame("Frame", nil, contentRoot)
    bankTab:SetAllPoints()

    self.tabFrames.roster = rosterTab
    self.tabFrames.portals = portalsTab
    self.tabFrames.bestKeys = bestKeysTab
    self.tabFrames.bags = bagsTab
    self.tabFrames.bank = bankTab

    local rosterSectionTitle = rosterTab:CreateFontString(nil, "ARTWORK")
    rosterSectionTitle:SetPoint("TOPLEFT", 0, -2)
    setFontStringTextSafe(rosterSectionTitle, L["CONFIG_SECTION_ROSTER_FRAME"], 13, "OUTLINE", GameFontHighlight)

    local rosterFontSizeSlider = self:CreateFontSizeSlider(
        "vesperToolsConfigRosterFontSizeSlider",
        rosterTab,
        L["CONFIG_ROSTER_FONT_SIZE"],
        rosterSectionTitle,
        -16
    )
    local rosterOpacitySlider = self:CreateOpacitySlider(
        "vesperToolsConfigRosterOpacitySlider",
        rosterTab,
        L["CONFIG_ROSTER_OPACITY"],
        rosterFontSizeSlider,
        -30
    )

    local rosterOnlineBlacklistLabel = rosterTab:CreateFontString(nil, "ARTWORK")
    rosterOnlineBlacklistLabel:SetPoint("TOPLEFT", rosterOpacitySlider, "BOTTOMLEFT", 0, -34)
    setFontStringTextSafe(rosterOnlineBlacklistLabel, L["CONFIG_ROSTER_ONLINE_BLACKLIST"], 12, "", GameFontNormal)

    local rosterOnlineBlacklistDropdown = self:CreateFlatDropdown(
        "vesperToolsConfigRosterOnlineBlacklistDropdown",
        rosterTab,
        rosterOnlineBlacklistLabel,
        -6,
        396,
        function(button)
            self:OpenRosterOnlineBlacklistPicker(button)
        end
    )
    local rosterOnlineBlacklistText = rosterOnlineBlacklistDropdown.Text

    local rosterOnlineBlacklistHint = rosterTab:CreateFontString(nil, "ARTWORK")
    rosterOnlineBlacklistHint:SetPoint("TOPLEFT", rosterOnlineBlacklistDropdown, "BOTTOMLEFT", 0, -6)
    rosterOnlineBlacklistHint:SetPoint("RIGHT", rosterTab, "RIGHT", -12, 0)
    rosterOnlineBlacklistHint:SetJustifyH("LEFT")
    rosterOnlineBlacklistHint:SetJustifyV("TOP")
    rosterOnlineBlacklistHint:SetWordWrap(true)
    setFontStringTextSafe(rosterOnlineBlacklistHint, L["CONFIG_ROSTER_ONLINE_BLACKLIST_HINT"], 11, "", GameFontHighlightSmall)
    rosterOnlineBlacklistHint:SetTextColor(0.78, 0.82, 0.9, 1)

    local portalsSectionTitle = portalsTab:CreateFontString(nil, "ARTWORK")
    portalsSectionTitle:SetPoint("TOPLEFT", 0, -2)
    setFontStringTextSafe(portalsSectionTitle, L["CONFIG_SECTION_PORTALS_FRAME"], 13, "OUTLINE", GameFontHighlight)

    local portalsFontSizeSlider = self:CreateFontSizeSlider(
        "vesperToolsConfigPortalsFontSizeSlider",
        portalsTab,
        L["CONFIG_PORTALS_FONT_SIZE"],
        portalsSectionTitle,
        -16
    )
    local portalsOpacitySlider = self:CreateOpacitySlider(
        "vesperToolsConfigPortalsOpacitySlider",
        portalsTab,
        L["CONFIG_PORTALS_OPACITY"],
        portalsFontSizeSlider,
        -30
    )
    local minUtilityButtonSize, maxUtilityButtonSize = vesperTools:GetTopUtilityButtonSizeBounds()
    local utilityButtonSizeSlider = self:CreateUtilityButtonSizeSlider(
        "vesperToolsConfigTopUtilityButtonSizeSlider",
        portalsTab,
        L["CONFIG_TOP_UTILITY_BUTTON_SIZE"],
        portalsOpacitySlider,
        -30,
        minUtilityButtonSize,
        maxUtilityButtonSize
    )

    local hearthstoneLabel = portalsTab:CreateFontString(nil, "ARTWORK")
    hearthstoneLabel:SetPoint("TOPLEFT", utilityButtonSizeSlider, "BOTTOMLEFT", 0, -34)
    setFontStringTextSafe(hearthstoneLabel, L["CONFIG_PRIMARY_HEARTHSTONE"], 12, "", GameFontNormal)

    local hearthstoneDropdown = self:CreateFlatDropdown(
        "vesperToolsConfigPrimaryHearthstoneDropdown",
        portalsTab,
        hearthstoneLabel,
        -6,
        396,
        function(button)
            self:OpenHearthstonePicker(button)
        end
    )
    local hearthstoneText = hearthstoneDropdown.Text

    local toyWhitelistLabel = portalsTab:CreateFontString(nil, "ARTWORK")
    toyWhitelistLabel:SetPoint("TOPLEFT", hearthstoneDropdown, "BOTTOMLEFT", 0, -16)
    setFontStringTextSafe(toyWhitelistLabel, L["CONFIG_TOY_FLYOUT_WHITELIST"], 12, "", GameFontNormal)

    local toyWhitelistDropdown = self:CreateFlatDropdown(
        "vesperToolsConfigToyWhitelistDropdown",
        portalsTab,
        toyWhitelistLabel,
        -6,
        396,
        function(button)
            self:OpenToyWhitelistPicker(button)
        end
    )
    local toyWhitelistText = toyWhitelistDropdown.Text

    local toyNameLabel = portalsTab:CreateFontString(nil, "ARTWORK")
    toyNameLabel:SetPoint("TOPLEFT", toyWhitelistDropdown, "BOTTOMLEFT", 0, -16)
    setFontStringTextSafe(toyNameLabel, L["CONFIG_ADD_TOY_BY_NAME"], 12, "", GameFontNormal)

    local toyNameInput = self:CreateFlatInput(
        "vesperToolsConfigToyNameInput",
        portalsTab,
        toyNameLabel,
        -6,
        298
    )
    toyNameInput:SetScript("OnEnterPressed", function(selfInput)
        self:AddToyToWhitelistByName()
        selfInput:ClearFocus()
    end)

    local toyAddButton = self:CreateFlatActionButton(
        "vesperToolsConfigToyNameAddButton",
        portalsTab,
        L["CONFIG_ADD_BUTTON"],
        toyNameInput,
        "TOPRIGHT",
        6,
        0,
        92
    )
    toyAddButton:SetScript("OnClick", function()
        self:AddToyToWhitelistByName()
    end)

    local toyLookupStatusText = portalsTab:CreateFontString(nil, "ARTWORK")
    toyLookupStatusText:SetPoint("TOPLEFT", toyNameInput, "BOTTOMLEFT", 0, -8)
    toyLookupStatusText:SetPoint("TOPRIGHT", toyAddButton, "BOTTOMRIGHT", 0, -8)
    toyLookupStatusText:SetJustifyH("LEFT")
    setFontStringTextSafe(toyLookupStatusText, "", 11, "", GameFontHighlightSmall)
    toyLookupStatusText:SetTextColor(0.78, 0.82, 0.9, 1)

    local bestKeysSectionTitle = bestKeysTab:CreateFontString(nil, "ARTWORK")
    bestKeysSectionTitle:SetPoint("TOPLEFT", 0, -2)
    setFontStringTextSafe(bestKeysSectionTitle, L["CONFIG_SECTION_BEST_KEYS_FRAME"], 13, "OUTLINE", GameFontHighlight)

    local bestKeysFontSizeSlider = self:CreateFontSizeSlider(
        "vesperToolsConfigBestKeysFontSizeSlider",
        bestKeysTab,
        L["CONFIG_BEST_KEYS_FONT_SIZE"],
        bestKeysSectionTitle,
        -16
    )
    local bestKeysOpacitySlider = self:CreateOpacitySlider(
        "vesperToolsConfigBestKeysOpacitySlider",
        bestKeysTab,
        L["CONFIG_BEST_KEYS_OPACITY"],
        bestKeysFontSizeSlider,
        -30
    )

    local bagsAllowGuildLookupRequestsCheckbox = self:CreateCheckButton(
        "vesperToolsConfigBagsAllowGuildLookupRequestsCheckbox",
        bagsTab,
        L["CONFIG_BAGS_ALLOW_GUILD_LOOKUP_REQUESTS"],
        bagsTab,
        -2
    )
    bagsAllowGuildLookupRequestsCheckbox:ClearAllPoints()
    bagsAllowGuildLookupRequestsCheckbox:SetPoint("TOPLEFT", 0, -2)

    local bagsGuildLookupHint = bagsTab:CreateFontString(nil, "ARTWORK")
    bagsGuildLookupHint:SetPoint("TOPLEFT", bagsAllowGuildLookupRequestsCheckbox, "BOTTOMLEFT", 4, -2)
    bagsGuildLookupHint:SetWidth(400)
    bagsGuildLookupHint:SetJustifyH("LEFT")
    bagsGuildLookupHint:SetJustifyV("TOP")
    setFontStringTextSafe(
        bagsGuildLookupHint,
        L["CONFIG_BAGS_ALLOW_GUILD_LOOKUP_REQUESTS_HINT"],
        11,
        "",
        GameFontHighlightSmall
    )
    bagsGuildLookupHint:SetTextColor(0.78, 0.82, 0.9, 1)

    local bagsSectionTitle = bagsTab:CreateFontString(nil, "ARTWORK")
    bagsSectionTitle:SetPoint("TOPLEFT", bagsGuildLookupHint, "BOTTOMLEFT", -4, -12)
    setFontStringTextSafe(bagsSectionTitle, L["CONFIG_SECTION_BAGS_WINDOW"], 13, "OUTLINE", GameFontHighlight)

    local bagsColumnsSlider = self:CreateIntegerSlider(
        "vesperToolsConfigBagsColumnsSlider",
        bagsTab,
        L["CONFIG_BAGS_COLUMNS"],
        bagsSectionTitle,
        -16,
        1,
        20
    )
    local bagsIconSizeSlider = self:CreateIntegerSlider(
        "vesperToolsConfigBagsIconSizeSlider",
        bagsTab,
        L["CONFIG_BAGS_ICON_SIZE"],
        bagsColumnsSlider,
        -30,
        24,
        56
    )
    local bagsStackCountFontSizeSlider = self:CreateIntegerSlider(
        "vesperToolsConfigBagsStackCountFontSizeSlider",
        bagsTab,
        L["CONFIG_BAGS_STACK_COUNT_FONT_SIZE"],
        bagsIconSizeSlider,
        -30,
        8,
        20
    )
    local bagsItemLevelFontSizeSlider = self:CreateIntegerSlider(
        "vesperToolsConfigBagsItemLevelFontSizeSlider",
        bagsTab,
        L["CONFIG_BAGS_ILVL_FONT_SIZE"],
        bagsStackCountFontSizeSlider,
        -30,
        8,
        18
    )
    local bagsShowItemLevelCheckbox = self:CreateCheckButton(
        "vesperToolsConfigBagsShowItemLevelCheckbox",
        bagsTab,
        L["CONFIG_BAGS_SHOW_ITEM_LEVEL"],
        bagsItemLevelFontSizeSlider,
        -30
    )
    local bagsQualityGlowSlider = self:CreatePercentSlider(
        "vesperToolsConfigBagsQualityGlowSlider",
        bagsTab,
        L["CONFIG_BAGS_QUALITY_GLOW"],
        bagsShowItemLevelCheckbox,
        -24,
        0,
        1,
        0.05
    )
    local bagsShowCurrencyBarCheckbox = self:CreateCheckButton(
        "vesperToolsConfigBagsShowCurrencyBarCheckbox",
        bagsTab,
        L["CONFIG_BAGS_SHOW_CURRENCY_BAR"],
        bagsQualityGlowSlider,
        -24
    )
    local bagsCurrencyBarLabel = bagsTab:CreateFontString(nil, "ARTWORK")
    bagsCurrencyBarLabel:SetPoint("TOPLEFT", bagsShowCurrencyBarCheckbox, "BOTTOMLEFT", 4, -8)
    setFontStringTextSafe(bagsCurrencyBarLabel, L["CONFIG_BAGS_CURRENCY_BAR"], 12, "", GameFontNormal)

    local bagsCurrencyBarDropdown
    bagsCurrencyBarDropdown = self:CreateFlatDropdown(
        "vesperToolsConfigBagsCurrencyBarDropdown",
        bagsTab,
        bagsCurrencyBarLabel,
        -6,
        360,
        function()
            self:OpenCurrencyBarPicker(bagsCurrencyBarDropdown)
        end
    )
    local bagsCurrencyBarHint = bagsTab:CreateFontString(nil, "ARTWORK")
    bagsCurrencyBarHint:SetPoint("TOPLEFT", bagsCurrencyBarDropdown, "BOTTOMLEFT", 0, -6)
    bagsCurrencyBarHint:SetWidth(400)
    bagsCurrencyBarHint:SetJustifyH("LEFT")
    bagsCurrencyBarHint:SetJustifyV("TOP")
    setFontStringTextSafe(bagsCurrencyBarHint, L["CONFIG_BAGS_CURRENCY_BAR_HINT"], 11, "", GameFontHighlightSmall)
    bagsCurrencyBarHint:SetTextColor(0.78, 0.82, 0.9, 1)

    local bagsReplaceBlizzardCheckbox = self:CreateCheckButton(
        "vesperToolsConfigBagsReplaceBlizzardCheckbox",
        bagsTab,
        L["CONFIG_BAGS_REPLACE_BLIZZARD"],
        bagsCurrencyBarHint,
        -18
    )

    local bankSectionTitle = bankTab:CreateFontString(nil, "ARTWORK")
    bankSectionTitle:SetPoint("TOPLEFT", 0, -2)
    setFontStringTextSafe(bankSectionTitle, L["CONFIG_SECTION_BANK_WINDOW"], 13, "OUTLINE", GameFontHighlight)

    local bankColumnsSlider = self:CreateIntegerSlider(
        "vesperToolsConfigBankColumnsSlider",
        bankTab,
        L["CONFIG_BANK_COLUMNS"],
        bankSectionTitle,
        -16,
        1,
        20
    )
    local bankIconSizeSlider = self:CreateIntegerSlider(
        "vesperToolsConfigBankIconSizeSlider",
        bankTab,
        L["CONFIG_BANK_ICON_SIZE"],
        bankColumnsSlider,
        -30,
        24,
        56
    )
    local bankStackCountFontSizeSlider = self:CreateIntegerSlider(
        "vesperToolsConfigBankStackCountFontSizeSlider",
        bankTab,
        L["CONFIG_BANK_STACK_COUNT_FONT_SIZE"],
        bankIconSizeSlider,
        -30,
        8,
        20
    )
    local bankItemLevelFontSizeSlider = self:CreateIntegerSlider(
        "vesperToolsConfigBankItemLevelFontSizeSlider",
        bankTab,
        L["CONFIG_BANK_ILVL_FONT_SIZE"],
        bankStackCountFontSizeSlider,
        -30,
        8,
        18
    )
    local bankShowItemLevelCheckbox = self:CreateCheckButton(
        "vesperToolsConfigBankShowItemLevelCheckbox",
        bankTab,
        L["CONFIG_BANK_SHOW_ITEM_LEVEL"],
        bankItemLevelFontSizeSlider,
        -30
    )
    local bankQualityGlowSlider = self:CreatePercentSlider(
        "vesperToolsConfigBankQualityGlowSlider",
        bankTab,
        L["CONFIG_BANK_QUALITY_GLOW"],
        bankShowItemLevelCheckbox,
        -24,
        0,
        1,
        0.05
    )
    local bankReplaceBlizzardCheckbox = self:CreateCheckButton(
        "vesperToolsConfigBankReplaceBlizzardCheckbox",
        bankTab,
        L["CONFIG_BANK_REPLACE_BLIZZARD"],
        bankQualityGlowSlider,
        -30
    )

    self.opacitySliders.roster = rosterOpacitySlider
    self.opacitySliders.portals = portalsOpacitySlider
    self.opacitySliders.bestKeys = bestKeysOpacitySlider

    self.fontSizeSliders.roster = rosterFontSizeSlider
    self.fontSizeSliders.portals = portalsFontSizeSlider
    self.fontSizeSliders.bestKeys = bestKeysFontSizeSlider

    -- Live-write opacity values and notify listeners on user-driven changes.
    local function bindOpacitySlider(slider, frameKey)
        slider:SetScript("OnValueChanged", function(changedSlider, value)
            local profile = ensureProfile()
            if not profile then
                return
            end
            local normalized = clamp(roundToStep(tonumber(value) or 0.95, 0.05), 0.10, 1.00)
            if math.abs(normalized - value) > 0.0001 then
                changedSlider:SetValue(normalized)
                return
            end
            profile.style.backgroundOpacity[frameKey] = normalized
            self:UpdateSliderLabel(changedSlider)
            if not self._isRefreshing then
                self:NotifyConfigChanged()
            end
        end)
    end

    -- Live-write frame-specific font size values.
    local function bindFontSizeSlider(slider, frameKey)
        slider:SetScript("OnValueChanged", function(changedSlider, value)
            local profile = ensureProfile()
            if not profile then
                return
            end
            local normalized = clamp(roundToStep(tonumber(value) or 12, 1), 8, 24)
            if math.abs(normalized - value) > 0.0001 then
                changedSlider:SetValue(normalized)
                return
            end
            profile.style.fontSize[frameKey] = normalized
            self:UpdateFontSizeSliderLabel(changedSlider)
            if not self._isRefreshing then
                self:NotifyConfigChanged()
            end
        end)
    end

    -- Live-write top utility button size used by hearthstone/toy controls.
    local function bindUtilityButtonSizeSlider(slider)
        slider:SetScript("OnValueChanged", function(changedSlider, value)
            local profile = ensureProfile()
            if not profile then
                return
            end
            local minSize, maxSize, defaultSize = vesperTools:GetTopUtilityButtonSizeBounds()
            local normalized = clamp(roundToStep(tonumber(value) or defaultSize, 1), minSize, maxSize)
            normalized = math.floor(normalized + 0.5)
            if math.abs(normalized - value) > 0.0001 then
                changedSlider:SetValue(normalized)
                return
            end
            profile.portals.utilityButtonSize = normalized
            self:UpdateUtilityButtonSizeSliderLabel(changedSlider)
            if not self._isRefreshing then
                self:NotifyConfigChanged()
            end
        end)
    end

    -- Live-write integer bag display values stored in the separate bags profile DB.
    local function bindInventoryIntegerSlider(slider, displayRootKey, fieldKey, minValue, maxValue)
        slider:SetScript("OnValueChanged", function(changedSlider, value)
            local bagsProfile = ensureBagsProfile()
            if not bagsProfile then
                return
            end
            local normalized = clamp(math.floor((tonumber(value) or minValue) + 0.5), minValue, maxValue)
            if math.abs(normalized - value) > 0.0001 then
                changedSlider:SetValue(normalized)
                return
            end
            bagsProfile[displayRootKey] = bagsProfile[displayRootKey] or {}
            bagsProfile[displayRootKey][fieldKey] = normalized
            self:UpdateIntegerSliderLabel(changedSlider)
            if not self._isRefreshing then
                self:NotifyConfigChanged()
            end
        end)
    end

    -- Live-write inventory glow intensity as a normalized 0..1 value.
    local function bindInventoryPercentSlider(slider, displayRootKey, fieldKey)
        slider:SetScript("OnValueChanged", function(changedSlider, value)
            local bagsProfile = ensureBagsProfile()
            if not bagsProfile then
                return
            end
            local normalized = clamp(roundToStep(tonumber(value) or 0, 0.05), 0, 1)
            if math.abs(normalized - value) > 0.0001 then
                changedSlider:SetValue(normalized)
                return
            end
            bagsProfile[displayRootKey] = bagsProfile[displayRootKey] or {}
            bagsProfile[displayRootKey][fieldKey] = normalized
            self:UpdatePercentSliderLabel(changedSlider)
            if not self._isRefreshing then
                self:NotifyConfigChanged()
            end
        end)
    end

    -- Toggle item-level overlays in the inventory windows.
    local function bindInventoryCheckBox(checkbox, displayRootKey, fieldKey)
        checkbox:SetScript("OnClick", function(changedCheckbox)
            local bagsProfile = ensureBagsProfile()
            if not bagsProfile then
                return
            end
            bagsProfile[displayRootKey] = bagsProfile[displayRootKey] or {}
            bagsProfile[displayRootKey][fieldKey] = changedCheckbox:GetChecked() and true or false
            if not self._isRefreshing then
                self:NotifyConfigChanged()
            end
        end)
    end

    local function bindBagsFlagCheckBox(checkbox, fieldKey)
        checkbox:SetScript("OnClick", function(changedCheckbox)
            local bagsProfile = ensureBagsProfile()
            if not bagsProfile then
                return
            end
            bagsProfile[fieldKey] = changedCheckbox:GetChecked() and true or false
            if not self._isRefreshing then
                self:NotifyConfigChanged()
            end
        end)
    end

    local function bindBagsGuildLookupCheckBox(checkbox, fieldKey)
        checkbox:SetScript("OnClick", function(changedCheckbox)
            local bagsProfile = ensureBagsProfile()
            if not bagsProfile then
                return
            end
            bagsProfile.guildLookup = bagsProfile.guildLookup or {}
            bagsProfile.guildLookup[fieldKey] = changedCheckbox:GetChecked() and true or false
            if not self._isRefreshing then
                self:NotifyConfigChanged()
            end
        end)
    end

    local function bindBankReplacementCheckBox(checkbox)
        checkbox:SetScript("OnClick", function(changedCheckbox)
            local bagsProfile = ensureBagsProfile()
            if not bagsProfile then
                return
            end

            local enabled = changedCheckbox:GetChecked() and true or false
            bagsProfile.replaceCharacterBank = enabled
            bagsProfile.replaceAccountBank = enabled
            if not self._isRefreshing then
                self:NotifyConfigChanged()
            end
        end)
    end

    bindOpacitySlider(rosterOpacitySlider, "roster")
    bindOpacitySlider(portalsOpacitySlider, "portals")
    bindOpacitySlider(bestKeysOpacitySlider, "bestKeys")

    bindFontSizeSlider(rosterFontSizeSlider, "roster")
    bindFontSizeSlider(portalsFontSizeSlider, "portals")
    bindFontSizeSlider(bestKeysFontSizeSlider, "bestKeys")
    bindUtilityButtonSizeSlider(utilityButtonSizeSlider)
    bindInventoryIntegerSlider(bagsColumnsSlider, "display", "columns", 1, 20)
    bindInventoryIntegerSlider(bagsIconSizeSlider, "display", "itemIconSize", 24, 56)
    bindInventoryIntegerSlider(bagsStackCountFontSizeSlider, "display", "stackCountFontSize", 8, 20)
    bindInventoryIntegerSlider(bagsItemLevelFontSizeSlider, "display", "itemLevelFontSize", 8, 18)
    bindInventoryPercentSlider(bagsQualityGlowSlider, "display", "qualityGlowIntensity")
    bindBagsGuildLookupCheckBox(bagsAllowGuildLookupRequestsCheckbox, "allowIncomingRequests")
    bindInventoryCheckBox(bagsShowItemLevelCheckbox, "display", "showItemLevel")
    bindInventoryCheckBox(bagsShowCurrencyBarCheckbox, "display", "showCurrencyBar")
    bindBagsFlagCheckBox(bagsReplaceBlizzardCheckbox, "replaceBackpack")
    bindInventoryIntegerSlider(bankColumnsSlider, "bankDisplay", "columns", 1, 20)
    bindInventoryIntegerSlider(bankIconSizeSlider, "bankDisplay", "itemIconSize", 24, 56)
    bindInventoryIntegerSlider(bankStackCountFontSizeSlider, "bankDisplay", "stackCountFontSize", 8, 20)
    bindInventoryIntegerSlider(bankItemLevelFontSizeSlider, "bankDisplay", "itemLevelFontSize", 8, 18)
    bindInventoryPercentSlider(bankQualityGlowSlider, "bankDisplay", "qualityGlowIntensity")
    bindInventoryCheckBox(bankShowItemLevelCheckbox, "bankDisplay", "showItemLevel")
    bindBankReplacementCheckBox(bankReplaceBlizzardCheckbox)

    panel:SetScript("OnShow", function()
        self:SetActiveTab(self.activeTab or "roster")
        self:RefreshControls()
    end)
    panel:SetScript("OnHide", function()
        if self.fontMenuFrame then
            self.fontMenuFrame:Hide()
        end
        if self.rosterOnlineBlacklistMenuFrame then
            self.rosterOnlineBlacklistMenuFrame:Hide()
        end
        if self.toyWhitelistMenuFrame then
            self.toyWhitelistMenuFrame:Hide()
        end
        if self.bagsCurrencyMenuFrame then
            self.bagsCurrencyMenuFrame:Hide()
        end
    end)

    self.panel = panel
    self.fontDropdown = fontDropdown
    self.fontDropdownText = fontText
    self.rosterOnlineBlacklistDropdown = rosterOnlineBlacklistDropdown
    self.rosterOnlineBlacklistDropdownText = rosterOnlineBlacklistText
    self.rosterOnlineBlacklistHint = rosterOnlineBlacklistHint
    self.hearthstoneDropdown = hearthstoneDropdown
    self.hearthstoneDropdownText = hearthstoneText
    self.toyWhitelistDropdown = toyWhitelistDropdown
    self.toyWhitelistDropdownText = toyWhitelistText
    self.toyNameInput = toyNameInput
    self.toyNameAddButton = toyAddButton
    self.toyLookupStatusText = toyLookupStatusText
    self.utilityButtonSizeSlider = utilityButtonSizeSlider
    self.bagsColumnsSlider = bagsColumnsSlider
    self.bagsIconSizeSlider = bagsIconSizeSlider
    self.bagsStackCountFontSizeSlider = bagsStackCountFontSizeSlider
    self.bagsItemLevelFontSizeSlider = bagsItemLevelFontSizeSlider
    self.bagsQualityGlowSlider = bagsQualityGlowSlider
    self.bagsAllowGuildLookupRequestsCheckbox = bagsAllowGuildLookupRequestsCheckbox
    self.bagsReplaceBlizzardCheckbox = bagsReplaceBlizzardCheckbox
    self.bagsShowItemLevelCheckbox = bagsShowItemLevelCheckbox
    self.bagsShowCurrencyBarCheckbox = bagsShowCurrencyBarCheckbox
    self.bagsCurrencyBarDropdown = bagsCurrencyBarDropdown
    self.bagsCurrencyBarDropdownText = bagsCurrencyBarDropdown.Text
    self.bagsCurrencyBarHint = bagsCurrencyBarHint
    self.bankColumnsSlider = bankColumnsSlider
    self.bankIconSizeSlider = bankIconSizeSlider
    self.bankStackCountFontSizeSlider = bankStackCountFontSizeSlider
    self.bankItemLevelFontSizeSlider = bankItemLevelFontSizeSlider
    self.bankQualityGlowSlider = bankQualityGlowSlider
    self.bankShowItemLevelCheckbox = bankShowItemLevelCheckbox
    self.bankReplaceBlizzardCheckbox = bankReplaceBlizzardCheckbox
    vesperTools:RegisterEscapeFrame(panel, closePanel)
    self:SetActiveTab(self.activeTab or "roster")
end

-- Pull profile values into controls without rebroadcasting updates.
function Configuration:RefreshControls()
    local profile = ensureProfile()
    local bagsProfile = ensureBagsProfile()
    if not profile or not bagsProfile then
        return
    end

    -- Guard prevents slider OnValueChanged handlers from rebroadcasting while we hydrate UI.
    self._isRefreshing = true

    self:RefreshFontDropdownText()
    self:RefreshRosterOnlineBlacklistDropdownText()
    self:RefreshHearthstoneDropdownText()
    self:RefreshToyWhitelistDropdownText()
    self:RefreshBagsCurrencyBarDropdownText()
    self:SetBagsCurrencyBarStatus(L["CONFIG_BAGS_CURRENCY_BAR_HINT"], 0.78, 0.82, 0.9)

    local rosterValue = clamp(tonumber(profile.style.backgroundOpacity.roster) or 0.95, 0.10, 1.00)
    local portalsValue = clamp(tonumber(profile.style.backgroundOpacity.portals) or 0.95, 0.10, 1.00)
    local bestKeysValue = clamp(tonumber(profile.style.backgroundOpacity.bestKeys) or 0.95, 0.10, 1.00)
    local rosterFontSize = clamp(tonumber(profile.style.fontSize.roster) or 12, 8, 24)
    local portalsFontSize = clamp(tonumber(profile.style.fontSize.portals) or 12, 8, 24)
    local bestKeysFontSize = clamp(tonumber(profile.style.fontSize.bestKeys) or 11, 8, 24)
    local minUtilityButtonSize, maxUtilityButtonSize, defaultUtilityButtonSize = vesperTools:GetTopUtilityButtonSizeBounds()
    local utilityButtonSize = clamp(
        math.floor((tonumber(profile.portals.utilityButtonSize) or defaultUtilityButtonSize) + 0.5),
        minUtilityButtonSize,
        maxUtilityButtonSize
    )
    local bagsColumns = clamp(math.floor((tonumber(bagsProfile.display.columns) or 10) + 0.5), 1, 20)
    local bagsIconSize = clamp(math.floor((tonumber(bagsProfile.display.itemIconSize) or 38) + 0.5), 24, 56)
    local bagsStackCountFontSize = clamp(math.floor((tonumber(bagsProfile.display.stackCountFontSize) or 11) + 0.5), 8, 20)
    local bagsItemLevelFontSize = clamp(math.floor((tonumber(bagsProfile.display.itemLevelFontSize) or 9) + 0.5), 8, 18)
    local bagsQualityGlow = clamp(tonumber(bagsProfile.display.qualityGlowIntensity) or 0.65, 0, 1)
    local bagsAllowGuildLookupRequests = bagsProfile.guildLookup.allowIncomingRequests and true or false
    local bagsReplaceBlizzard = bagsProfile.replaceBackpack and true or false
    local bagsShowItemLevel = bagsProfile.display.showItemLevel and true or false
    local bagsShowCurrencyBar = bagsProfile.display.showCurrencyBar and true or false
    local bankColumns = clamp(math.floor((tonumber(bagsProfile.bankDisplay.columns) or 10) + 0.5), 1, 20)
    local bankIconSize = clamp(math.floor((tonumber(bagsProfile.bankDisplay.itemIconSize) or 38) + 0.5), 24, 56)
    local bankStackCountFontSize = clamp(math.floor((tonumber(bagsProfile.bankDisplay.stackCountFontSize) or 11) + 0.5), 8, 20)
    local bankItemLevelFontSize = clamp(math.floor((tonumber(bagsProfile.bankDisplay.itemLevelFontSize) or 9) + 0.5), 8, 18)
    local bankQualityGlow = clamp(tonumber(bagsProfile.bankDisplay.qualityGlowIntensity) or 0.65, 0, 1)
    local bankShowItemLevel = bagsProfile.bankDisplay.showItemLevel and true or false
    local bankReplaceBlizzard = (bagsProfile.replaceCharacterBank or bagsProfile.replaceAccountBank) and true or false

    if self.opacitySliders.roster then
        self.opacitySliders.roster:SetValue(rosterValue)
        self:UpdateSliderLabel(self.opacitySliders.roster)
    end
    if self.opacitySliders.portals then
        self.opacitySliders.portals:SetValue(portalsValue)
        self:UpdateSliderLabel(self.opacitySliders.portals)
    end
    if self.opacitySliders.bestKeys then
        self.opacitySliders.bestKeys:SetValue(bestKeysValue)
        self:UpdateSliderLabel(self.opacitySliders.bestKeys)
    end
    if self.fontSizeSliders.roster then
        self.fontSizeSliders.roster:SetValue(rosterFontSize)
        self:UpdateFontSizeSliderLabel(self.fontSizeSliders.roster)
    end
    if self.fontSizeSliders.portals then
        self.fontSizeSliders.portals:SetValue(portalsFontSize)
        self:UpdateFontSizeSliderLabel(self.fontSizeSliders.portals)
    end
    if self.fontSizeSliders.bestKeys then
        self.fontSizeSliders.bestKeys:SetValue(bestKeysFontSize)
        self:UpdateFontSizeSliderLabel(self.fontSizeSliders.bestKeys)
    end
    if self.utilityButtonSizeSlider then
        self.utilityButtonSizeSlider:SetValue(utilityButtonSize)
        self:UpdateUtilityButtonSizeSliderLabel(self.utilityButtonSizeSlider)
    end
    if self.bagsColumnsSlider then
        self.bagsColumnsSlider:SetValue(bagsColumns)
        self:UpdateIntegerSliderLabel(self.bagsColumnsSlider)
    end
    if self.bagsIconSizeSlider then
        self.bagsIconSizeSlider:SetValue(bagsIconSize)
        self:UpdateIntegerSliderLabel(self.bagsIconSizeSlider)
    end
    if self.bagsStackCountFontSizeSlider then
        self.bagsStackCountFontSizeSlider:SetValue(bagsStackCountFontSize)
        self:UpdateIntegerSliderLabel(self.bagsStackCountFontSizeSlider)
    end
    if self.bagsItemLevelFontSizeSlider then
        self.bagsItemLevelFontSizeSlider:SetValue(bagsItemLevelFontSize)
        self:UpdateIntegerSliderLabel(self.bagsItemLevelFontSizeSlider)
    end
    if self.bagsQualityGlowSlider then
        self.bagsQualityGlowSlider:SetValue(bagsQualityGlow)
        self:UpdatePercentSliderLabel(self.bagsQualityGlowSlider)
    end
    if self.bagsAllowGuildLookupRequestsCheckbox then
        self.bagsAllowGuildLookupRequestsCheckbox:SetChecked(bagsAllowGuildLookupRequests)
    end
    if self.bagsReplaceBlizzardCheckbox then
        self.bagsReplaceBlizzardCheckbox:SetChecked(bagsReplaceBlizzard)
    end
    if self.bagsShowItemLevelCheckbox then
        self.bagsShowItemLevelCheckbox:SetChecked(bagsShowItemLevel)
    end
    if self.bagsShowCurrencyBarCheckbox then
        self.bagsShowCurrencyBarCheckbox:SetChecked(bagsShowCurrencyBar)
    end
    if self.bankColumnsSlider then
        self.bankColumnsSlider:SetValue(bankColumns)
        self:UpdateIntegerSliderLabel(self.bankColumnsSlider)
    end
    if self.bankIconSizeSlider then
        self.bankIconSizeSlider:SetValue(bankIconSize)
        self:UpdateIntegerSliderLabel(self.bankIconSizeSlider)
    end
    if self.bankStackCountFontSizeSlider then
        self.bankStackCountFontSizeSlider:SetValue(bankStackCountFontSize)
        self:UpdateIntegerSliderLabel(self.bankStackCountFontSizeSlider)
    end
    if self.bankItemLevelFontSizeSlider then
        self.bankItemLevelFontSizeSlider:SetValue(bankItemLevelFontSize)
        self:UpdateIntegerSliderLabel(self.bankItemLevelFontSizeSlider)
    end
    if self.bankQualityGlowSlider then
        self.bankQualityGlowSlider:SetValue(bankQualityGlow)
        self:UpdatePercentSliderLabel(self.bankQualityGlowSlider)
    end
    if self.bankShowItemLevelCheckbox then
        self.bankShowItemLevelCheckbox:SetChecked(bankShowItemLevel)
    end
    if self.bankReplaceBlizzardCheckbox then
        self.bankReplaceBlizzardCheckbox:SetChecked(bankReplaceBlizzard)
    end

    -- Keep toy name-add controls in sync with real toy availability.
    local ownedToyOptions = vesperTools:GetOwnedToyOptions()
    local hasOwnedToys = type(ownedToyOptions) == "table" and #ownedToyOptions > 0
    if self.toyNameInput then
        self.toyNameInput:Enable()
        self.toyNameInput:EnableMouse(true)
        self.toyNameInput:SetAlpha(1)
    end
    if self.toyNameAddButton then
        self.toyNameAddButton:Enable()
        self.toyNameAddButton:SetAlpha(1)
    end
    if not hasOwnedToys then
        self:SetToyLookupStatus(L["CONFIG_NO_TOYS_DETECTED"], 1, 0.7, 0.2)
    elseif self.toyLookupStatusText and self.toyLookupStatusText:GetText() == L["CONFIG_NO_TOYS_DETECTED"] then
        self:SetToyLookupStatus("", 0.78, 0.82, 0.9)
    end

    self:RefreshPanelFonts()
    if self.fontMenuFrame and self.fontMenuFrame:IsShown() then
        self:RefreshFontMenu()
    end
    if self.rosterOnlineBlacklistMenuFrame and self.rosterOnlineBlacklistMenuFrame:IsShown() then
        self:RefreshRosterOnlineBlacklistMenu()
    end

    self._isRefreshing = false
end

-- Public entrypoint used by slash commands and in-panel UI actions.
function Configuration:OpenConfig()
    self:BuildPanel()
    if not self.panel then
        return
    end
    self.panel:Show()
    self.panel:Raise()
    self:RefreshControls()
end
