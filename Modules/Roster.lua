local _, addonTable = ...
local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local Roster = vesperTools:NewModule("Roster", "AceEvent-3.0")
local L = vesperTools.L
local CombatGate = addonTable.CombatGate
local WindowLifecycle = addonTable.WindowLifecycle

-- Roster renders the guild list view and wires its action buttons, sorting, and menus.
local HEADER_ACTION_BUTTON_HEIGHT = 22
local HEADER_ACTION_BUTTON_GAP = 6
local ROSTER_HEADER_HEIGHT = 24
local ROSTER_HEADER_BOTTOM_MARGIN = 5
local ROSTER_ROW_HEIGHT = 24
local ROSTER_SCROLL_STEP = ROSTER_ROW_HEIGHT * 2
local ROSTER_SCROLLBAR_GUTTER = 27
local ROSTER_MIN_CONTENT_WIDTH = 520
local ROSTER_TEXT_INSET = 4
local ROSTER_DOUBLE_CLICK_THRESHOLD = 0.35

-- Sort arrow indicators (WoW built-in arrow textures)
local ARROW_UP = " |TInterface\\Buttons\\Arrow-Up-Up:12:12|t"
local ARROW_DOWN = " |TInterface\\Buttons\\Arrow-Down-Up:12:12|t"

-- Column definitions: key, label, width, sort type
local COLUMNS = {
    { key = "name", label = L["ROSTER_COLUMN_NAME"], width = 0.15, sort = "string" },
    { key = "level", label = L["ROSTER_COLUMN_LEVEL"], width = 0.07, sort = "number" },
    { key = "zone", label = L["ROSTER_COLUMN_ZONE"], width = 0.18, sort = "string" },
    { key = "status", label = L["ROSTER_COLUMN_STATUS"], width = 0.10, sort = "string" },
    { key = "ilvl", label = L["ROSTER_COLUMN_ILVL"], width = 0.10, sort = "number" },
    { key = "rating", label = L["ROSTER_COLUMN_RATING"], width = 0.10, sort = "number" },
    { key = "keyLevel", label = L["ROSTER_COLUMN_KEY"], width = 0.18, sort = "number" },
}

local TOTAL_COLUMN_WEIGHT = 0
for i = 1, #COLUMNS do
    TOTAL_COLUMN_WEIGHT = TOTAL_COLUMN_WEIGHT + (tonumber(COLUMNS[i].width) or 0)
end

local function getSpellName(spellID)
    if not spellID then
        return nil
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo and spellInfo.name then
            return spellInfo.name
        end
    end

    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end

    return nil
end

local function canRequestJoinGroupForMember(member)
    if type(member) ~= "table" then
        return false
    end

    if member.isInGroup or IsInGroup() or member.guid == UnitGUID("player") then
        return false
    end

    if not (member.guid and C_SocialQueue and C_SocialQueue.GetGroupForPlayer and C_SocialQueue.GetGroupInfo) then
        return false
    end

    local groupGUID = C_SocialQueue.GetGroupForPlayer(member.guid)
    if not groupGUID then
        return false
    end

    local canJoin = C_SocialQueue.GetGroupInfo(groupGUID)
    return canJoin and true or false
end

local function resolveMemberFullName(memberOrFullName)
    local member = type(memberOrFullName) == "table" and memberOrFullName or nil
    local resolvedFullName = strtrim(tostring((member and member.fullName) or memberOrFullName or ""))
    if resolvedFullName == "" then
        return nil, member
    end

    return resolvedFullName, member
end

-- Build one consistent titlebar action button for roster header controls.
local function createHeaderActionButton(parent, anchor, width, label, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetPoint("RIGHT", anchor, "LEFT", -HEADER_ACTION_BUTTON_GAP, 0)
    button:SetSize(width, HEADER_ACTION_BUTTON_HEIGHT)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    button:SetBackdropColor(0.08, 0.08, 0.1, 0.92)
    button:SetBackdropBorderColor(1, 1, 1, 0.12)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    button:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.2)
    button:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    button:GetPushedTexture():SetVertexColor(0.12, 0.2, 0.3, 0.36)
    if type(onClick) == "function" then
        button:SetScript("OnClick", onClick)
    end

    local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(label)
    vesperTools:ApplyConfiguredFont(text, 11, "")
    button.text = text

    return button
end

local function createRosterText(parent, template)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    return text
end

function Roster:OnInitialize()
    self.frame = nil
    self.contentFrame = nil
    self.titleBar = nil
    self.titleText = nil
    self.closeButton = nil
    self.syncButton = nil
    self.headerFrame = nil
    self.headerButtons = {}
    self.scrollFrame = nil
    self.scrollContent = nil
    self.rosterRows = {}
    self.currentColumnLayout = nil
    self.pendingRosterRefresh = false
    self.lastRosterRowClickName = nil
    self.lastRosterRowClickTime = 0
end

function Roster:OnEnable()
    self:RegisterMessage("VESPERTOOLS_ILVL_UPDATE", "OnSyncUpdate")
    self:RegisterMessage("VESPERTOOLS_BESTKEYS_UPDATE", "OnSyncUpdate")
    self:RegisterMessage("VESPERTOOLS_KEYSTONE_UPDATE", "OnSyncUpdate")
    self:RegisterMessage("VESPERTOOLS_PORTAL_SPELLS_REFRESHED", "OnSyncUpdate")
    self:RegisterMessage("VESPERTOOLS_CONFIG_CHANGED", "OnConfigChanged")
end

-- Redraw the list whenever synced guild data changes.
function Roster:OnSyncUpdate()
    self:RequestRosterRefresh()
end

function Roster:OnConfigChanged()
    self:ApplyRosterStyling()
end

function Roster:OnDisable()
    if CombatGate then
        CombatGate:CancelOwner(self)
    end
end

function Roster:RestoreWindowReferences(frame)
    if not frame then
        return
    end

    self.frame = frame
    self.contentFrame = frame.vgContentFrame or self.contentFrame
    self.titleBar = frame.vgTitleBar or self.titleBar
    self.titleText = frame.vgTitleText or self.titleText
    self.closeButton = frame.vgCloseButton or self.closeButton
    self.syncButton = frame.vgSyncButton or self.syncButton
    self.headerFrame = frame.vgHeaderFrame or self.headerFrame
    self.headerButtons = frame.vgHeaderButtons or self.headerButtons
    self.scrollFrame = frame.vgScrollFrame or self.scrollFrame
    self.scrollContent = frame.vgScrollContent or self.scrollContent
    self.rosterRows = frame.vgRosterRows or self.rosterRows
end

function Roster:ApplyTitlebarLayout()
    local frame = self.frame
    local titleBar = self.titleBar
    local titleText = self.titleText
    local closeButton = self.closeButton
    local syncButton = self.syncButton
    if not (frame and titleBar and titleText and closeButton and syncButton) then
        return
    end

    titleBar:ClearAllPoints()
    closeButton:ClearAllPoints()
    syncButton:ClearAllPoints()
    titleText:ClearAllPoints()

    if vesperTools:UseRoundedWindowCorners() then
        titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -1)
        titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -1)
        closeButton:SetPoint("LEFT", titleBar, "LEFT", 6, 0)
        syncButton:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
        titleText:SetPoint("LEFT", closeButton, "RIGHT", 8, 0)
    else
        titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        closeButton:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
        syncButton:SetPoint("RIGHT", closeButton, "LEFT", -HEADER_ACTION_BUTTON_GAP, 0)
        titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    end
end

function Roster:ApplyRosterStyling()
    if not self.frame then
        return
    end

    local baseFontSize = vesperTools:GetConfiguredFontSize("roster", 12, 8, 24)
    self.frame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("roster"))
    self:ApplyTitlebarLayout()

    if self.titleText then
        self.titleText:SetText(GetGuildInfo("player") or L["ROSTER_TITLE_FALLBACK"])
        vesperTools:ApplyConfiguredFont(self.titleText, baseFontSize + 4, "")
    end

    for i = 1, #(self.headerButtons or {}) do
        local button = self.headerButtons[i]
        if button and button.text then
            vesperTools:ApplyConfiguredFont(button.text, baseFontSize, "")
        end
    end

    for i = 1, #(self.rosterRows or {}) do
        local row = self.rosterRows[i]
        if row and row.columns then
            for _, text in pairs(row.columns) do
                vesperTools:ApplyConfiguredFont(text, baseFontSize, "")
            end
        end
    end
end

function Roster:PerformRosterRefresh()
    self.pendingRosterRefresh = false
    if not self.frame or not self.frame:IsShown() then
        return
    end

    self:UpdateRosterList()
end

function Roster:RequestRosterRefresh()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    if CombatGate then
        local executedNow = CombatGate:RunNamed(self, "refresh", function()
            self:PerformRosterRefresh()
        end)
        self.pendingRosterRefresh = not executedNow
        return
    end

    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self.pendingRosterRefresh = true
        return
    end

    self:PerformRosterRefresh()
end

-- Lazily create one dropdown frame used by legacy fallback context menus.
function Roster:GetContextMenuDropdown()
    local dropdownLevel = 80
    if self.frame and self.frame.GetFrameLevel then
        dropdownLevel = math.max(dropdownLevel, (self.frame:GetFrameLevel() or 0) + 40)
    end

    if self.contextMenuDropdown and self.contextMenuDropdown.GetName then
        self.contextMenuDropdown:SetFrameStrata("TOOLTIP")
        self.contextMenuDropdown:SetFrameLevel(dropdownLevel)
        self.contextMenuDropdown:SetToplevel(true)
        return self.contextMenuDropdown
    end

    self.contextMenuDropdown = CreateFrame("Frame", "vesperToolsContextMenu", UIParent, "UIDropDownMenuTemplate")
    self.contextMenuDropdown:SetFrameStrata("TOOLTIP")
    self.contextMenuDropdown:SetFrameLevel(dropdownLevel)
    self.contextMenuDropdown:SetToplevel(true)
    return self.contextMenuDropdown
end

-- Create a neutral top-level anchor so Blizzard context menus do not inherit row layering.
function Roster:GetContextMenuAnchor(anchorButton)
    local anchorLevel = 80
    if self.frame and self.frame.GetFrameLevel then
        anchorLevel = math.max(anchorLevel, (self.frame:GetFrameLevel() or 0) + 40)
    end

    if not (self.contextMenuAnchor and self.contextMenuAnchor.GetName) then
        self.contextMenuAnchor = CreateFrame("Frame", "vesperToolsContextMenuAnchor", UIParent)
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

-- Open manual roster right-click menu with stable cross-client fallbacks.
function Roster:OpenRosterContextMenu(anchorButton, memberOrFullName)
    local resolvedFullName, member = resolveMemberFullName(memberOrFullName)
    if not resolvedFullName then
        return false
    end

    local function whisperPlayer()
        if ChatFrame_OpenChat then
            ChatFrame_OpenChat("/w " .. resolvedFullName .. " ")
        elseif ChatFrame_SendTell then
            ChatFrame_SendTell(resolvedFullName)
        end
    end

    local primaryActionLabel, primaryActionFunc = self:GetRosterMemberPrimaryAction(member or resolvedFullName)

    if anchorButton and MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        local menuAnchor = self:GetContextMenuAnchor(anchorButton)
        GameTooltip:Hide()
        MenuUtil.CreateContextMenu(menuAnchor, function(_, rootDescription)
            if primaryActionLabel and primaryActionFunc then
                rootDescription:CreateButton(primaryActionLabel, primaryActionFunc)
            end
            rootDescription:CreateButton(L["CONTEXT_MENU_WHISPER"], whisperPlayer)
            rootDescription:CreateButton(L["CONTEXT_MENU_CLOSE"], function() end)
        end)
        return true
    end

    if EasyMenu then
        local menu = {}
        if primaryActionLabel and primaryActionFunc then
            menu[#menu + 1] = { text = primaryActionLabel, func = primaryActionFunc, notCheckable = true }
        end
        menu[#menu + 1] = { text = L["CONTEXT_MENU_WHISPER"], func = whisperPlayer, notCheckable = true }
        menu[#menu + 1] = { text = L["CONTEXT_MENU_CLOSE"], func = function() end, notCheckable = true }
        local dropdown = self:GetContextMenuDropdown()
        GameTooltip:Hide()
        dropdown:Raise()
        EasyMenu(menu, dropdown, "cursor", 0, 0, "MENU")
        return true
    end

    return false
end

function Roster:GetRosterMemberPrimaryAction(memberOrFullName)
    local resolvedFullName, member = resolveMemberFullName(memberOrFullName)
    if not resolvedFullName then
        return nil, nil
    end

    if member and member.guid and member.guid == UnitGUID("player") then
        return nil, nil
    end

    local function invitePlayer()
        if C_PartyInfo and C_PartyInfo.InviteUnit then
            C_PartyInfo.InviteUnit(resolvedFullName)
        elseif InviteUnit then
            InviteUnit(resolvedFullName)
        end
    end

    local function requestJoinPlayer()
        if C_PartyInfo and C_PartyInfo.RequestInviteFromUnit then
            C_PartyInfo.RequestInviteFromUnit(resolvedFullName)
        elseif RequestInviteFromUnit then
            RequestInviteFromUnit(resolvedFullName)
        else
            invitePlayer()
        end
    end

    if canRequestJoinGroupForMember(member) then
        return L["CONTEXT_MENU_REQUEST_JOIN"], requestJoinPlayer
    end

    if member and member.isInGroup then
        return nil, nil
    end

    return L["CONTEXT_MENU_INVITE"], invitePlayer
end

function Roster:ResetRosterRowClickState()
    self.lastRosterRowClickName = nil
    self.lastRosterRowClickTime = 0
end

function Roster:BuildColumnLayout(availableWidth)
    local resolvedWidth = math.max(ROSTER_MIN_CONTENT_WIDTH, math.floor((tonumber(availableWidth) or 0) + 0.5))
    local layout = {}
    local usedWidth = 0

    for i = 1, #COLUMNS do
        local column = COLUMNS[i]
        local width
        if i == #COLUMNS then
            width = math.max(32, resolvedWidth - usedWidth)
        else
            width = math.max(32, math.floor((resolvedWidth * (column.width / TOTAL_COLUMN_WEIGHT)) + 0.5))
        end

        layout[i] = {
            key = column.key,
            label = column.label,
            sort = column.sort,
            offset = usedWidth,
            width = width,
        }
        usedWidth = usedWidth + width
    end

    if layout[#layout] then
        layout[#layout].width = math.max(32, resolvedWidth - layout[#layout].offset)
    end

    layout.totalWidth = resolvedWidth
    return layout
end

function Roster:GetListContentWidth()
    local width = 0
    if self.scrollFrame and self.scrollFrame.GetWidth then
        width = self.scrollFrame:GetWidth() or 0
    elseif self.headerFrame and self.headerFrame.GetWidth then
        width = self.headerFrame:GetWidth() or 0
    end

    return math.max(ROSTER_MIN_CONTENT_WIDTH, math.floor(width + 0.5))
end

function Roster:UpdateListViewportLayout(hasScrollBar)
    if not self.contentFrame or not self.headerFrame or not self.scrollFrame then
        return
    end

    local shouldShowScrollBar = hasScrollBar and true or false
    if self.rosterScrollBarVisible == shouldShowScrollBar then
        vesperTools:SetModernScrollBarVisibility(self.scrollFrame, shouldShowScrollBar)
        return
    end

    self.rosterScrollBarVisible = shouldShowScrollBar
    vesperTools:SetModernScrollBarVisibility(self.scrollFrame, shouldShowScrollBar)

    local rightInset = shouldShowScrollBar and -ROSTER_SCROLLBAR_GUTTER or 0

    self.headerFrame:ClearAllPoints()
    self.headerFrame:SetPoint("TOPLEFT", self.contentFrame, "TOPLEFT", 0, 0)
    self.headerFrame:SetPoint("TOPRIGHT", self.contentFrame, "TOPRIGHT", rightInset, 0)

    self.scrollFrame:ClearAllPoints()
    self.scrollFrame:SetPoint("TOPLEFT", self.headerFrame, "BOTTOMLEFT", 0, -ROSTER_HEADER_BOTTOM_MARGIN)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", self.contentFrame, "BOTTOMRIGHT", rightInset, 0)
end

function Roster:UpdateHeaderLayout(columnLayout, fontSize)
    if not self.headerFrame then
        return
    end

    local resolvedFontSize = tonumber(fontSize) or vesperTools:GetConfiguredFontSize("roster", 12, 8, 24)
    for i = 1, #COLUMNS do
        local layout = columnLayout[i]
        local button = self.headerButtons and self.headerButtons[i] or nil
        if layout and button then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.headerFrame, "TOPLEFT", layout.offset, 0)
            button:SetSize(layout.width, ROSTER_HEADER_HEIGHT)
            vesperTools:ApplyConfiguredFont(button.text, resolvedFontSize, "")

            local arrow = ""
            if self.sortColumn == layout.key then
                arrow = self.sortAscending and ARROW_UP or ARROW_DOWN
            end
            button.text:SetText(layout.label .. arrow)
        end
    end
end

function Roster:LayoutRowColumns(row, columnLayout, fontSize)
    if not row or not row.columns then
        return
    end

    local resolvedFontSize = tonumber(fontSize) or vesperTools:GetConfiguredFontSize("roster", 12, 8, 24)
    row:SetSize(columnLayout.totalWidth, ROSTER_ROW_HEIGHT)
    local keyColumnLayout = nil

    for i = 1, #COLUMNS do
        local layout = columnLayout[i]
        local text = row.columns[layout.key]
        if layout.key == "keyLevel" then
            keyColumnLayout = layout
        end
        if text then
            text:ClearAllPoints()
            text:SetPoint("TOPLEFT", row, "TOPLEFT", layout.offset + ROSTER_TEXT_INSET, -1)
            text:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", layout.offset + layout.width - ROSTER_TEXT_INSET, -(ROSTER_ROW_HEIGHT - 1))
            vesperTools:ApplyConfiguredFont(text, resolvedFontSize, "")
        end
    end

    if row.button then
        row.button:SetAllPoints(row)
    end

    if row.portalButton then
        row.portalButton:ClearAllPoints()
        if keyColumnLayout and row.portalSpellName then
            row.portalButton:SetPoint("TOPLEFT", row, "TOPLEFT", keyColumnLayout.offset, 0)
            row.portalButton:SetSize(keyColumnLayout.width, ROSTER_ROW_HEIGHT)
            row.portalButton:EnableMouse(true)
            row.portalButton:Show()
        else
            row.portalButton:EnableMouse(false)
            row.portalButton:Hide()
        end
    end
end

function Roster:HideRosterRows(startIndex)
    local firstIndex = math.max(1, tonumber(startIndex) or 1)
    for index = firstIndex, #(self.rosterRows or {}) do
        local row = self.rosterRows[index]
        if row then
            row.member = nil
            row.portalSpellName = nil
            row.tooltipMapID = nil
            row.dataHandle = nil
            row.fullName = nil
            if row.button then
                row.button.ownerRow = nil
            end
            if row.portalButton then
                row.portalButton.ownerRow = nil
                row.portalButton:SetAttribute("type1", nil)
                row.portalButton:SetAttribute("spell1", nil)
                row.portalButton:EnableMouse(false)
                row.portalButton:Hide()
            end
            row:Hide()
        end
    end
end

function Roster:CreateWindow()
    if self.frame then
        return self.frame
    end

    local frame, wasCreated = WindowLifecycle:GetOrCreateNamedFrame(self, "frame", "vesperToolsFrame", function()
        return CreateFrame("Frame", "vesperToolsFrame", UIParent, "BackdropTemplate")
    end)
    self:RestoreWindowReferences(frame)
    if not wasCreated then
        return frame
    end

    frame:SetSize(600, 250)

    -- Restore saved position or use default
    if vesperTools.db.profile.rosterPosition then
        local pos = vesperTools.db.profile.rosterPosition
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    else
        frame:SetPoint("RIGHT", UIParent, "CENTER", -250, 0)
    end

    vesperTools:ApplyAddonWindowLayer(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(600, 250)

    vesperTools:ApplyRoundedWindowBackdrop(frame)
    frame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("roster"))
    local _, englishClass = UnitClass("player")
    local classColor = englishClass and C_ClassColor.GetClassColor(englishClass) or nil
    if classColor then
        frame:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    end
    vesperTools:RegisterEscapeFrame(frame, function()
        self:HandleCloseRequest()
    end)

    -- Titlebar
    local titlebar = CreateFrame("Frame", nil, frame)
    titlebar:SetHeight(32)
    titlebar:SetPoint("TOPLEFT", 1, -1)
    titlebar:SetPoint("TOPRIGHT", -1, -1)

    local titlebg = titlebar:CreateTexture(nil, "BACKGROUND")
    titlebg:SetAllPoints()
    titlebg:SetColorTexture(0.1, 0.1, 0.1, 1)

    local title = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 10, 0)
    title:SetText(GetGuildInfo("player") or L["ROSTER_TITLE_FALLBACK"])
    vesperTools:ApplyConfiguredFont(title, vesperTools:GetConfiguredFontSize("roster", 12, 8, 24) + 4, "")
    self.titleText = title
    self.titleBar = titlebar

    -- Make draggable via titlebar
    titlebar:EnableMouse(true)
    titlebar:RegisterForDrag("LeftButton")
    titlebar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titlebar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
        vesperTools.db.profile.rosterPosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
        }
    end)

    local closeBtn = vesperTools:CreateModernCloseButton(titlebar, function()
        self:HandleCloseRequest()
    end, {
        size = 20,
        iconScale = 0.52,
        useClassColor = true,
        backgroundAlpha = 0.04,
        borderAlpha = 0.08,
        hoverAlpha = 0.12,
        pressedAlpha = 0.18,
    })
    closeBtn:SetPoint("RIGHT", -6, 0)
    self.closeButton = closeBtn

    local resizeBtn = CreateFrame("Button", nil, frame)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT")
    resizeBtn:EnableMouse(true)

    local resizeTex = resizeBtn:CreateTexture(nil, "OVERLAY")
    resizeTex:SetAllPoints()
    resizeTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")

    resizeBtn:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:RequestRosterRefresh()
    end)

    local syncBtn = createHeaderActionButton(titlebar, closeBtn, 72, L["ROSTER_BUTTON_SYNC"], function()
        local Auto = vesperTools:GetModule("Automation", true)
        if Auto and type(Auto.ManualSync) == "function" then
            Auto:ManualSync()
        else
            local KeystoneSync = vesperTools:GetModule("KeystoneSync", true)
            if KeystoneSync and type(KeystoneSync.RefreshKeystoneData) == "function" then
                KeystoneSync:RefreshKeystoneData({ requestGuild = true, silent = false })
            elseif KeystoneSync and type(KeystoneSync.RequestGuildKeystones) == "function" then
                KeystoneSync:RequestGuildKeystones()
            end

            local Portals = vesperTools:GetModule("Portals", true)
            if Portals and type(Portals.ForceRefreshPortalAvailability) == "function" then
                Portals:ForceRefreshPortalAvailability()
            end
        end
        self:RequestRosterRefresh()
    end)
    self.syncButton = syncBtn

    local confBtn = createHeaderActionButton(titlebar, syncBtn, 56, L["ROSTER_BUTTON_CONFIG"], function(_, mouseButton)
        if mouseButton == "LeftButton" then
            vesperTools:OpenConfig()
        end
    end)

    local bagsBtn = createHeaderActionButton(titlebar, confBtn, 56, L["ROSTER_BUTTON_BAGS"], function(_, mouseButton)
        if mouseButton == "LeftButton" then
            local BagsWindow = vesperTools:GetModule("BagsWindow", true)
            if BagsWindow and type(BagsWindow.Toggle) == "function" then
                BagsWindow:Toggle()
            end
        end
    end)

    local blizzBagsBtn = createHeaderActionButton(titlebar, bagsBtn, 46, "Blizz", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            local BagsBridge = vesperTools:GetModule("BagsBridge", true)
            if BagsBridge and type(BagsBridge.ShowBlizzardBags) == "function" then
                BagsBridge:ShowBlizzardBags()
            elseif type(OpenAllBags) == "function" then
                OpenAllBags()
            elseif type(ToggleAllBags) == "function" then
                ToggleAllBags()
            end
        end
    end)

    local bankBtn = createHeaderActionButton(titlebar, blizzBagsBtn, 56, L["ROSTER_BUTTON_BANK"], function(_, mouseButton)
        if mouseButton == "LeftButton" then
            local BankWindow = vesperTools:GetModule("BankWindow", true)
            if BankWindow and type(BankWindow.Toggle) == "function" then
                BankWindow:Toggle()
            end
        end
    end)

    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", titlebar, "BOTTOMLEFT", 5, -5)
    contentFrame:SetPoint("BOTTOMRIGHT", -5, 20)
    self.contentFrame = contentFrame

    local headerFrame = CreateFrame("Frame", nil, contentFrame)
    headerFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -27, 0)
    headerFrame:SetHeight(ROSTER_HEADER_HEIGHT)
    self.headerFrame = headerFrame

    local headerBackground = headerFrame:CreateTexture(nil, "BACKGROUND")
    headerBackground:SetAllPoints()
    headerBackground:SetColorTexture(0.1, 0.1, 0.1, 1)
    headerFrame.vgBackground = headerBackground

    local headerDivider = contentFrame:CreateTexture(nil, "BORDER")
    headerDivider:SetHeight(1)
    headerDivider:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -1)
    headerDivider:SetPoint("TOPRIGHT", headerFrame, "BOTTOMRIGHT", 0, -1)
    headerDivider:SetColorTexture(1, 1, 1, 0.08)
    contentFrame.vgHeaderDivider = headerDivider

    self.headerButtons = {}
    for i = 1, #COLUMNS do
        local column = COLUMNS[i]
        local button = CreateFrame("Button", nil, headerFrame)
        button.columnKey = column.key
        button.columnLabel = column.label
        button.sortType = column.sort
        button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
        button:GetHighlightTexture():SetVertexColor(0.24, 0.46, 0.72, 0.18)

        local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", button, "LEFT", ROSTER_TEXT_INSET, 0)
        text:SetPoint("RIGHT", button, "RIGHT", -ROSTER_TEXT_INSET, 0)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("MIDDLE")
        text:SetWordWrap(false)
        vesperTools:ApplyConfiguredFont(text, vesperTools:GetConfiguredFontSize("roster", 12, 8, 24), "")
        button.text = text

        button:SetScript("OnClick", function(selfButton)
            if self.sortColumn == selfButton.columnKey then
                self.sortAscending = not self.sortAscending
            else
                self.sortColumn = selfButton.columnKey
                self.sortAscending = (selfButton.sortType == "string")
            end
            self:RequestRosterRefresh()
        end)
        button:SetScript("OnEnter", function(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(string.format(L["ROSTER_SORT_BY_FMT"], selfButton.columnLabel))
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        self.headerButtons[i] = button
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -ROSTER_HEADER_BOTTOM_MARGIN)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -27, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(selfFrame, delta)
        local current = selfFrame:GetVerticalScroll() or 0
        local maximum = math.max(0, (selfFrame.contentHeight or 0) - (selfFrame:GetHeight() or 0))
        local nextValue = math.max(0, math.min(maximum, current - (delta * ROSTER_SCROLL_STEP)))
        selfFrame:SetVerticalScroll(nextValue)
    end)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame.child = scrollChild
    vesperTools:ApplyModernScrollBar(scrollFrame)
    vesperTools:SetModernScrollBarVisibility(scrollFrame, false)

    self.scrollFrame = scrollFrame
    self.scrollContent = scrollChild
    self.rosterRows = {}
    self.rosterScrollBarVisible = nil

    frame.vgContentFrame = contentFrame
    frame.vgTitleBar = titlebar
    frame.vgTitleText = title
    frame.vgCloseButton = closeBtn
    frame.vgSyncButton = syncBtn
    frame.vgHeaderFrame = headerFrame
    frame.vgHeaderButtons = self.headerButtons
    frame.vgScrollFrame = scrollFrame
    frame.vgScrollContent = scrollChild
    frame.vgRosterRows = self.rosterRows

    self:ApplyRosterStyling()
    return frame
end

function Roster:AcquireRosterRow()
    local parent = self.scrollContent
    if not parent then
        return nil
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROSTER_ROW_HEIGHT)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    row.background = background

    row.columns = {
        name = createRosterText(row, "GameFontHighlightSmall"),
        level = createRosterText(row, "GameFontHighlightSmall"),
        zone = createRosterText(row, "GameFontHighlightSmall"),
        status = createRosterText(row, "GameFontHighlightSmall"),
        ilvl = createRosterText(row, "GameFontHighlightSmall"),
        rating = createRosterText(row, "GameFontHighlightSmall"),
        keyLevel = createRosterText(row, "GameFontHighlightSmall"),
    }

    local actionButton = CreateFrame("Button", nil, row)
    actionButton:SetFrameLevel(row:GetFrameLevel() + 1)
    actionButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    actionButton:SetScript("OnClick", function(selfButton, button)
        local ownerRow = selfButton.ownerRow
        if ownerRow and button == "LeftButton" then
            self:HandleRosterRowLeftClick(ownerRow)
        elseif ownerRow and button == "RightButton" then
            self:ResetRosterRowClickState()
            self:OpenRosterContextMenu(selfButton, ownerRow.member or ownerRow.fullName)
        end
    end)
    actionButton:SetScript("OnEnter", function(selfButton)
        local ownerRow = selfButton.ownerRow
        if ownerRow then
            self:ShowRosterRowTooltip(ownerRow, selfButton)
        end
    end)
    actionButton:SetScript("OnLeave", function(selfButton)
        local ownerRow = selfButton.ownerRow
        if ownerRow then
            self:HideRosterRowTooltip(ownerRow)
        end
    end)
    row.button = actionButton

    local portalButton = CreateFrame("Button", nil, row, "InsecureActionButtonTemplate")
    portalButton:SetFrameLevel(row:GetFrameLevel() + 2)
    portalButton:RegisterForClicks("AnyUp", "AnyDown")
    portalButton:HookScript("OnClick", function(selfButton, button, down)
        local ownerRow = selfButton.ownerRow
        if button == "LeftButton" then
            self:ResetRosterRowClickState()
        elseif ownerRow and button == "RightButton" and not down then
            self:ResetRosterRowClickState()
            self:OpenRosterContextMenu(selfButton, ownerRow.member or ownerRow.fullName)
        end
    end)
    portalButton:SetScript("OnEnter", function(selfButton)
        local ownerRow = selfButton.ownerRow
        if ownerRow then
            self:ShowRosterRowTooltip(ownerRow, selfButton)
        end
    end)
    portalButton:SetScript("OnLeave", function(selfButton)
        local ownerRow = selfButton.ownerRow
        if ownerRow then
            self:HideRosterRowTooltip(ownerRow)
        end
    end)
    portalButton:EnableMouse(false)
    portalButton:Hide()
    row.portalButton = portalButton

    self.rosterRows[#self.rosterRows + 1] = row
    return row
end

function Roster:HandleRosterRowLeftClick(row)
    if not row or not row.member then
        return
    end

    local _, primaryActionFunc = self:GetRosterMemberPrimaryAction(row.member)
    if type(primaryActionFunc) ~= "function" then
        self:ResetRosterRowClickState()
        return
    end

    local now = GetTimePreciseSec and GetTimePreciseSec() or GetTime()
    local fullName = row.fullName or row.member.fullName or row.member.name
    local previousName = self.lastRosterRowClickName
    local previousTime = tonumber(self.lastRosterRowClickTime) or 0

    self.lastRosterRowClickName = fullName
    self.lastRosterRowClickTime = now

    if previousName == fullName and (now - previousTime) <= ROSTER_DOUBLE_CLICK_THRESHOLD then
        self:ResetRosterRowClickState()
        primaryActionFunc()
    end
end

function Roster:GetRosterTooltipLines(row)
    local lines = {}
    local primaryActionLabel = row and row.member and select(1, self:GetRosterMemberPrimaryAction(row.member)) or nil
    if primaryActionLabel then
        lines[#lines + 1] = string.format(L["ROSTER_ROW_TOOLTIP_DOUBLE_LEFT_FMT"], primaryActionLabel)
    end
    if row and row.portalSpellName then
        lines[#lines + 1] = string.format(L["ROSTER_ROW_TOOLTIP_KEY_LEFT_FMT"], row.portalSpellName)
    end
    lines[#lines + 1] = L["ROSTER_ROW_TOOLTIP_RIGHT_ONLY"]
    return lines
end

function Roster:BuildGuildBestTooltip(mapID, dataHandle)
    if not mapID or not (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then
        return
    end

    local dungeonName = C_ChallengeMode.GetMapUIInfo(mapID)
    if not dungeonName then
        return
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format(L["ROSTER_ROW_TOOLTIP_GUILD_BEST_FMT"], dungeonName), 1, 0.82, 0, true)

    local entries = {}
    local seen = {}

    if dataHandle then
        local bestKeysDB = dataHandle:GetBestKeysDB()
        if bestKeysDB then
            for playerName, data in pairs(bestKeysDB) do
                local info = data[mapID]
                if info and info.level and info.level > 0 then
                    local shortName = playerName:match("([^-]+)") or playerName
                    seen[shortName] = true
                    entries[#entries + 1] = {
                        name = shortName,
                        level = info.level,
                        inTime = info.inTime,
                    }
                end
            end
        end
    end

    local guildLeaders = C_ChallengeMode.GetGuildLeaders and C_ChallengeMode.GetGuildLeaders() or nil
    if guildLeaders then
        for i = 1, #guildLeaders do
            local attempt = guildLeaders[i]
            if attempt.mapChallengeModeID == mapID and attempt.keystoneLevel > 0 and not seen[attempt.name] then
                seen[attempt.name] = true
                entries[#entries + 1] = {
                    name = attempt.name,
                    level = attempt.keystoneLevel,
                }
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.level == b.level then
            return a.name < b.name
        end
        return a.level > b.level
    end)

    for i = 1, #entries do
        local entry = entries[i]
        local colorCode = dataHandle and dataHandle:GetKeyColor(entry.level) or "|cffffffff"
        local r, g, b = 0.8, 0.8, 0.8
        if entry.inTime then
            r, g, b = 0.51, 0.78, 0.52
        end
        GameTooltip:AddDoubleLine(entry.name, colorCode .. "+" .. entry.level .. "|r", 1, 1, 1, r, g, b)
    end

    if #entries == 0 then
        GameTooltip:AddLine(L["ROSTER_ROW_TOOLTIP_NO_DATA"], 0.5, 0.5, 0.5)
    end
end

function Roster:ShowRosterRowTooltip(row, anchorButton)
    if not row then
        return
    end

    if row.background then
        row.background:SetColorTexture(0.24, 0.24, 0.24, 1)
    end

    GameTooltip:SetOwner(anchorButton, "ANCHOR_TOPLEFT")
    local tooltipLines = self:GetRosterTooltipLines(row)
    if #tooltipLines > 0 then
        GameTooltip:SetText(tooltipLines[1])
        for index = 2, #tooltipLines do
            GameTooltip:AddLine(tooltipLines[index])
        end
    else
        GameTooltip:SetText(L["ROSTER_ROW_TOOLTIP_RIGHT_ONLY"])
    end

    if row.tooltipMapID then
        self:BuildGuildBestTooltip(row.tooltipMapID, row.dataHandle)
    end

    GameTooltip:Show()
end

function Roster:HideRosterRowTooltip(row)
    if row and row.background then
        row.background:SetColorTexture(row.baseColorR or 0.12, row.baseColorG or 0.12, row.baseColorB or 0.12, 1)
    end
    GameTooltip:Hide()
end

function Roster:ConfigureRosterRow(row, member, index, columnLayout, fontSize, dataHandle)
    if not row or not member then
        return
    end

    local classColor = member.classFileName and C_ClassColor.GetClassColor(member.classFileName) or nil
    local nameText = member.name
    if classColor then
        nameText = string.format("|c%s%s|r", classColor:GenerateHexColor(), member.name)
    end

    local statusDisplay = member.status
    if member.status == L["STATUS_AFK"] then
        statusDisplay = "|cffFFFF00" .. L["STATUS_AFK"] .. "|r"
    elseif member.status == L["STATUS_DND"] then
        statusDisplay = "|cffFF0000" .. L["STATUS_DND"] .. "|r"
    end

    local ratingText = "-"
    if member.rating > 0 then
        local colorCode = dataHandle and dataHandle:GetRatingColor(member.rating) or "|cff9d9d9d"
        ratingText = string.format("%s%d|r", colorCode, member.rating)
    end

    row.member = member
    row.fullName = member.fullName
    row.tooltipMapID = member.keystoneMapID
    row.dataHandle = dataHandle

    row.columns.name:SetText(nameText)
    row.columns.level:SetText(member.level and member.level > 0 and tostring(member.level) or "-")
    row.columns.zone:SetText(member.zone)
    row.columns.status:SetText(statusDisplay)
    row.columns.ilvl:SetText(member.ilvl > 0 and tostring(member.ilvl) or "-")
    row.columns.rating:SetText(ratingText)
    row.columns.keyLevel:SetText(member.keystoneText)

    if member.isInGroup then
        row.baseColorR, row.baseColorG, row.baseColorB = 0.12, 0.24, 0.24
    elseif (index % 2 == 0) then
        row.baseColorR, row.baseColorG, row.baseColorB = 0.17, 0.17, 0.17
    else
        row.baseColorR, row.baseColorG, row.baseColorB = 0.12, 0.12, 0.12
    end
    row.background:SetColorTexture(row.baseColorR, row.baseColorG, row.baseColorB, 1)

    local button = row.button
    button.ownerRow = row

    local portalButton = row.portalButton
    portalButton.ownerRow = row
    portalButton:SetAttribute("type1", nil)
    portalButton:SetAttribute("spell1", nil)

    row.portalSpellName = nil
    if member.keystoneMapID and dataHandle then
        local dungeonInfo = dataHandle:GetDungeonByMapID(member.keystoneMapID)
        if dungeonInfo then
            local spellName = getSpellName(dungeonInfo.spellID)
            if spellName and vesperTools:IsSpellKnownForPlayer(dungeonInfo.spellID) then
                row.portalSpellName = spellName
                portalButton:SetAttribute("type1", "spell")
                portalButton:SetAttribute("spell1", spellName)
            end
        end
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.scrollContent, "TOPLEFT", 0, -((index - 1) * ROSTER_ROW_HEIGHT))
    self:LayoutRowColumns(row, columnLayout, fontSize)
    row:Show()
end

function Roster:CollectRosterMembers(dataHandle, keystoneSync)
    local members = {}
    local playerRealm = GetRealmName()
    local playerRealmNormalized = GetNormalizedRealmName()

    local groupMembers = {}
    if IsInGroup() then
        for j = 1, GetNumGroupMembers() do
            local unit = IsInRaid() and ("raid" .. j) or (j == 1 and "player" or ("party" .. (j - 1)))
            local groupName = UnitName(unit)
            if groupName then
                groupMembers[groupName] = true
            end
        end
    end

    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, _, level, _, zone, _, _, isOnline, status, classFileName, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        if isOnline then
            local displayName = name:match("([^-]+)") or name
            local fullName = name
            if not string.find(name, "-") then
                fullName = name .. "-" .. playerRealmNormalized
            end

            local statusRaw = L["STATUS_ONLINE"]
            if status == 1 then
                statusRaw = L["STATUS_AFK"]
            elseif status == 2 then
                statusRaw = L["STATUS_DND"]
            end

            local ilvlNum = 0
            if dataHandle then
                local ilvlData = dataHandle:GetIlvlForPlayer(fullName)
                    or dataHandle:GetIlvlForPlayer(name)
                    or dataHandle:GetIlvlForPlayer(displayName)
                    or dataHandle:GetIlvlForPlayer(displayName .. "-" .. playerRealm)
                if ilvlData then
                    ilvlNum = ilvlData.ilvl
                end
            end

            local ratingNum = 0
            local keyData = vesperTools.db.global.keystones
                and (
                    vesperTools.db.global.keystones[fullName]
                    or vesperTools.db.global.keystones[name]
                    or vesperTools.db.global.keystones[displayName]
                    or vesperTools.db.global.keystones[displayName .. "-" .. playerRealm]
                )
            if keyData and keyData.rating then
                ratingNum = keyData.rating
            end

            local keystoneText = "-"
            local keystoneMapID = nil
            local keyLevel = 0
            if keystoneSync then
                keystoneText = keystoneSync:GetKeystoneForPlayer(fullName)
                    or keystoneSync:GetKeystoneForPlayer(name)
                    or "-"
                if keyData then
                    keystoneMapID = keyData.mapID
                    keyLevel = keyData.level or 0
                end
            end

            members[#members + 1] = {
                name = displayName,
                fullName = fullName,
                classFileName = classFileName,
                guid = guid,
                level = tonumber(level) or 0,
                zone = zone or UNKNOWN,
                status = statusRaw,
                ilvl = ilvlNum,
                rating = ratingNum,
                keystoneText = keystoneText,
                keystoneMapID = keystoneMapID,
                keyLevel = keyLevel,
                isInGroup = groupMembers[displayName] or false,
                guildIndex = i,
            }
        end
    end

    table.sort(members, function(a, b)
        if a.isInGroup ~= b.isInGroup then
            return a.isInGroup
        end

        if self.sortColumn then
            local va, vb = a[self.sortColumn], b[self.sortColumn]
            if va ~= vb then
                if self.sortAscending then
                    return va < vb
                end
                return va > vb
            end
            if a.name ~= b.name then
                return a.name < b.name
            end
        end

        return a.guildIndex < b.guildIndex
    end)

    return members
end

-- Rebuild the visible guild list, including sorting and per-row actions.
function Roster:UpdateRosterList()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    if CombatGate and CombatGate:IsLockedDown() then
        self:RequestRosterRefresh()
        return
    end

    local rosterFontSize = vesperTools:GetConfiguredFontSize("roster", 12, 8, 24)
    local dataHandle = vesperTools:GetModule("DataHandle", true)
    local keystoneSync = vesperTools:GetModule("KeystoneSync", true)
    local members = self:CollectRosterMembers(dataHandle, keystoneSync)
    local contentHeight = math.max(1, #members * ROSTER_ROW_HEIGHT)
    local visibleHeight = self.scrollFrame and (self.scrollFrame:GetHeight() or 0) or 0
    local hasScrollBar = contentHeight > (visibleHeight + 0.5)

    self:UpdateListViewportLayout(hasScrollBar)

    local columnLayout = self:BuildColumnLayout(self:GetListContentWidth())
    local scrollPosition = self.scrollFrame and (self.scrollFrame:GetVerticalScroll() or 0) or 0

    self.currentColumnLayout = columnLayout
    self:UpdateHeaderLayout(columnLayout, rosterFontSize)

    for index = 1, #members do
        local row = self.rosterRows[index] or self:AcquireRosterRow()
        self:ConfigureRosterRow(row, members[index], index, columnLayout, rosterFontSize, dataHandle)
    end

    self:HideRosterRows(#members + 1)

    self.scrollContent:SetWidth(columnLayout.totalWidth)
    self.scrollContent:SetHeight(math.max(visibleHeight, contentHeight))
    self.scrollFrame.contentHeight = contentHeight

    local maxScroll = hasScrollBar and math.max(0, contentHeight - visibleHeight) or 0
    self.scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, scrollPosition)))
end

-- Create the roster frame lazily, then refresh its contents on every open.
function Roster:ShowRoster()
    self:CreateWindow()
    self.pendingRosterRefresh = false
    self:ResetRosterRowClickState()
    self:ApplyRosterStyling()
    if self.scrollFrame then
        self.scrollFrame:SetVerticalScroll(0)
    end
    WindowLifecycle:Show(self.frame)
    self:RequestRosterRefresh()
end

function Roster:HandleCloseRequest()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    if CombatGate then
        CombatGate:CancelOwner(self)
    end

    self.pendingRosterRefresh = false
    self:ResetRosterRowClickState()
    self:HideRosterRows(1)
    GameTooltip:Hide()
    vesperTools:HideSearchOverlay()
    WindowLifecycle:Hide(self.frame)

    if self.dungeonPanel then
        self.dungeonPanel:Hide()
        self.dungeonPanel = nil
    end

    local Portals = vesperTools:GetModule("Portals", true)
    if Portals and Portals.VesperPortalsUI then
        Portals.VesperPortalsUI:Hide()
    end
end

function Roster:Toggle()
    if self.frame and self.frame:IsShown() then
        self:HandleCloseRequest()
    else
        self:ShowRoster()
    end
end
