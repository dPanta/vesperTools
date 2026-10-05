local _, addonTable = ...
local vesperTools = vesperTools or LibStub("AceAddon-3.0"):GetAddon("vesperTools")
local Roster = vesperTools:NewModule("Roster", "AceEvent-3.0")
local L = vesperTools.L
local CombatGate = addonTable.CombatGate
local WindowLifecycle = addonTable.WindowLifecycle

-- Roster renders the guild list view and wires its action buttons, sorting, and menus.
local HEADER_ACTION_BUTTON_GAP = 6
local ROSTER_PARTY_KEY_BUTTON_PADDING = 10
local ROSTER_PARTY_KEY_BUTTON_OFFSET_Y = 10
local ROSTER_PARTY_KEY_BUTTON_DEFAULT_SIZE = 52
local ROSTER_PARTY_UTILITY_BUTTON_GAP = 6
local ROSTER_PARTY_KEY_BUTTON_ICON = "Interface\\Icons\\INV_Misc_Dice_01"
local ROSTER_PARTY_SPEC_ROLE_BUTTON_ICON = "Interface\\AddOns\\vesperTools\\Media\\RoleTarot-64"
local ROSTER_READY_CHECK_BUTTON_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ROSTER_PULL_TIMER_BUTTON_ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01"
local ROSTER_PULL_COUNTDOWN_SECONDS = 9
local ROSTER_HEADER_BOTTOM_MARGIN = 5
local ROSTER_SCROLLBAR_GUTTER = 27
local ROSTER_MIN_CONTENT_WIDTH = 520
local ROSTER_TEXT_INSET = 4
local ROSTER_DOUBLE_CLICK_THRESHOLD = 0.35
local ROSTER_MIN_ROW_HEIGHT = 24
local ROSTER_MIN_HEADER_HEIGHT = 24
local ROSTER_MIN_ACTION_BUTTON_HEIGHT = 22
local ROSTER_MIN_TITLEBAR_HEIGHT = 32
local ROSTER_SORT_ICON_SIZE = 12
local ROSTER_SORT_ICON_RESERVE = ROSTER_SORT_ICON_SIZE + ROSTER_TEXT_INSET
-- Column whose width is reserved for the secure portal-cast button overlay.
local PORTAL_COLUMN_KEY = "keyLevel"
-- Auto-sizing bounds for the roster window.
local ROSTER_MIN_FRAME_WIDTH = 600
local ROSTER_MIN_FRAME_HEIGHT = 250
local ROSTER_MAX_HEIGHT_FRACTION = 0.7
-- Vertical chrome around the scroll viewport: titlebar top inset (1) +
-- contentFrame top inset (5) + headerFrame bottom margin (5) + contentFrame
-- bottom inset (20). Add titlebar + header heights at runtime.
local ROSTER_CHROME_PADDING = 31

local function rosterChromeHeight(titleBarH, headerH)
    return (titleBarH or ROSTER_MIN_TITLEBAR_HEIGHT) + (headerH or ROSTER_MIN_HEADER_HEIGHT) + ROSTER_CHROME_PADDING
end

local function rosterFontSize()
    return vesperTools:GetConfiguredFontSize("roster", 12, 8, 24)
end

local function rosterRowHeight(fontSize)
    return math.max(ROSTER_MIN_ROW_HEIGHT, math.floor((tonumber(fontSize) or 12) + 12))
end

local function rosterHeaderHeight(fontSize)
    return math.max(ROSTER_MIN_HEADER_HEIGHT, math.floor((tonumber(fontSize) or 12) + 12))
end

local function rosterActionButtonHeight(fontSize)
    return math.max(ROSTER_MIN_ACTION_BUTTON_HEIGHT, math.floor((tonumber(fontSize) or 12) + 10))
end

local function rosterTitleBarHeight(fontSize)
    return math.max(ROSTER_MIN_TITLEBAR_HEIGHT, rosterActionButtonHeight(fontSize) + 10)
end

-- Column relative weights — divided by TOTAL_COLUMN_WEIGHT at layout time, so they
-- do not need to sum to any specific total. The last column absorbs rounding.
local COLUMNS = {
    { key = "name", label = L["ROSTER_COLUMN_NAME"], width = 15, sort = "string" },
    { key = "level", label = L["ROSTER_COLUMN_LEVEL"], width = 7, sort = "number" },
    { key = "zone", label = L["ROSTER_COLUMN_ZONE"], width = 18, sort = "string" },
    { key = "status", label = L["ROSTER_COLUMN_STATUS"], width = 10, sort = "string" },
    { key = "ilvl", label = L["ROSTER_COLUMN_ILVL"], width = 10, sort = "number" },
    { key = "rating", label = L["ROSTER_COLUMN_RATING"], width = 10, sort = "number" },
    { key = "keyLevel", label = L["ROSTER_COLUMN_KEY"], width = 18, sort = "number" },
}

local TOTAL_COLUMN_WEIGHT = 0
for i = 1, #COLUMNS do
    TOTAL_COLUMN_WEIGHT = TOTAL_COLUMN_WEIGHT + (tonumber(COLUMNS[i].width) or 0)
end

local function getSpellName(spellID)
    if not spellID then
        return nil
    end

    if vesperTools and type(vesperTools.GetSpellNameSafe) == "function" then
        local spellName = vesperTools:GetSpellNameSafe(spellID)
        if spellName then
            return spellName
        end
    end

    if GetSpellInfo then
        local ok, spellName = pcall(GetSpellInfo, spellID)
        if ok then
            return spellName
        end
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
    button:SetSize(width, rosterActionButtonHeight(rosterFontSize()))
    button.minWidth = width
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

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(label)
    vesperTools:ApplyConfiguredFont(text, 11, "")
    button.text = text

    return button
end

local function getRosterUtilityButtonSize()
    if vesperTools and type(vesperTools.GetConfiguredTopUtilityButtonSize) == "function" then
        return vesperTools:GetConfiguredTopUtilityButtonSize()
    end

    return ROSTER_PARTY_KEY_BUTTON_DEFAULT_SIZE
end

local function getPartyChatChannel()
    if type(IsInGroup) ~= "function" or not IsInGroup() then
        return nil
    end

    if type(IsInRaid) == "function" and IsInRaid() then
        return nil
    end

    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    return "PARTY"
end

local function isPlayerPartyLeader()
    if type(UnitIsGroupLeader) ~= "function" then
        return false
    end

    return UnitIsGroupLeader("player") and true or false
end

local function isPlayerInGroup()
    return type(IsInGroup) == "function" and IsInGroup() and true or false
end

local function getUnavailableText()
    return L["UTILITY_TOOLTIP_UNAVAILABLE"] or "Unavailable"
end

local function getPartyKeystoneUnavailableText()
    if getPartyChatChannel() == nil then
        return L["ROSTER_PARTY_KEY_NO_GROUP"]
    end

    if not isPlayerPartyLeader() then
        return L["ROSTER_PARTY_KEY_LEADER_ONLY"]
    end

    return nil
end

local function getPartySpecRoleUnavailableText()
    if getPartyChatChannel() == nil then
        return L["ROSTER_PARTY_SPEC_ROLE_NO_GROUP"]
    end

    return nil
end

local function getReadyCheckUnavailableText()
    if not isPlayerInGroup() or not isPlayerPartyLeader() then
        return getUnavailableText()
    end

    return nil
end

local function getPullCountdownUnavailableText()
    if not isPlayerInGroup() or not isPlayerPartyLeader() then
        return getUnavailableText()
    end

    if not C_PartyInfo or type(C_PartyInfo.DoCountdown) ~= "function" then
        return getUnavailableText()
    end

    return nil
end

local function startReadyCheck()
    if getReadyCheckUnavailableText() ~= nil or type(DoReadyCheck) ~= "function" then
        return false
    end

    local ok = pcall(DoReadyCheck)
    return ok and true or false
end

local function startPullCountdown()
    if getPullCountdownUnavailableText() ~= nil then
        return false
    end

    if C_PartyInfo and type(C_PartyInfo.DoCountdown) == "function" then
        local ok = pcall(C_PartyInfo.DoCountdown, ROSTER_PULL_COUNTDOWN_SECONDS)
        if ok then
            return true
        end
    end

    return false
end

local function getUnitFullName(unit)
    if type(unit) ~= "string" or not UnitExists(unit) then
        return nil
    end

    local name, realm
    if type(UnitFullName) == "function" then
        name, realm = UnitFullName(unit)
    end
    if not name and type(UnitName) == "function" then
        name, realm = UnitName(unit)
    end
    if type(name) ~= "string" or name == "" then
        return nil
    end

    if type(realm) == "string" and realm ~= "" then
        return name .. "-" .. realm
    end

    return vesperTools:NormalizePlayerFullName(name)
end

local function getPartyDisplayName(fullName, unit)
    if type(UnitIsUnit) == "function" and UnitIsUnit(unit, "player") then
        return UnitName("player") or (fullName and fullName:match("([^-]+)")) or UNKNOWN
    end

    if Ambiguate and type(fullName) == "string" then
        return Ambiguate(fullName, "short")
    end

    return (fullName and fullName:match("([^-]+)")) or UNKNOWN
end

local function isSamePartyKeystoneChoice(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end

    return left.fullName == right.fullName
        and tonumber(left.mapID) == tonumber(right.mapID)
        and tonumber(left.level) == tonumber(right.level)
end

local function isSamePartySpecRoleChoice(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end

    return tonumber(left.classID) == tonumber(right.classID)
        and tonumber(left.specID) == tonumber(right.specID)
end

local function getPartySpecRoleLabel(role)
    if role == "TANK" then
        return L["ROSTER_PARTY_SPEC_ROLE_TANK"]
    end
    if role == "HEALER" then
        return L["ROSTER_PARTY_SPEC_ROLE_HEALER"]
    end
    if role == "DAMAGER" then
        return L["ROSTER_PARTY_SPEC_ROLE_DPS"]
    end

    return tostring(role or UNKNOWN)
end

local function createRosterIconUtilityButton(parent, iconTexture, onClick, onEnter)
    local button = CreateFrame("Button", nil, parent)
    button:RegisterForClicks("LeftButtonUp")
    button:SetSize(getRosterUtilityButtonSize(), getRosterUtilityButtonSize())
    if type(onClick) == "function" then
        button:SetScript("OnClick", onClick)
    end
    if type(onEnter) == "function" then
        button:SetScript("OnEnter", onEnter)
    end
    button:SetScript("OnLeave", GameTooltip_Hide)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    button.bg = bg

    local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetAllPoints()
    icon:SetTexture(iconTexture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetVertexColor(1, 1, 1, 1)
    icon:SetBlendMode("BLEND")
    button.icon = icon

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 0, 0.4)
    button:SetHighlightTexture(highlight)

    return button
end

local function applyRosterIconButtonAvailability(button, isAvailable, unavailableText)
    if not button or not button.icon then
        return
    end

    button._isAvailable = isAvailable and true or false
    button._unavailableText = unavailableText
    button.icon:SetDesaturated(not button._isAvailable)
    button.icon:SetAlpha(button._isAvailable and 1 or 0.45)
    if button.SetEnabled then
        button:SetEnabled(button._isAvailable)
    elseif button._isAvailable and button.Enable then
        button:Enable()
    elseif button.Disable then
        button:Disable()
    end
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
    self.partyKeystoneFrame = nil
    self.partyKeystoneButton = nil
    self.partySpecRoleButton = nil
    self.partyReadyCheckButton = nil
    self.partyPullButton = nil
    self.partyKeystoneChoiceGroupSignature = nil
    self.partyKeystoneChoice = nil
    self.partySpecRoleChoiceClassID = nil
    self.partySpecRoleChoice = nil
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
    self:RegisterMessage("VESPERTOOLS_ROSTER_REFRESH_REQUESTED", "OnRosterSourceChanged")
    self:RegisterMessage("VESPERTOOLS_CONFIG_CHANGED", "OnConfigChanged")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterSourceChanged")
    self:RegisterEvent("PARTY_LEADER_CHANGED", "OnRosterSourceChanged")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnRosterSourceChanged")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "OnRosterSourceChanged")
end

-- Redraw the list whenever synced guild data changes.
function Roster:OnSyncUpdate()
    self:RequestRosterRefresh()
end

function Roster:OnRosterSourceChanged()
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
    self.partyKeystoneFrame = frame.vgPartyKeystoneFrame or self.partyKeystoneFrame
    self.partyKeystoneButton = frame.vgPartyKeystoneButton or self.partyKeystoneButton
    self.partySpecRoleButton = frame.vgPartySpecRoleButton or self.partySpecRoleButton
    self.partyReadyCheckButton = frame.vgPartyReadyCheckButton or self.partyReadyCheckButton
    self.partyPullButton = frame.vgPartyPullButton or self.partyPullButton
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

    local clampAnchor = self.leftmostTitlebarButton or syncButton

    if vesperTools:UseRoundedWindowCorners() then
        titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -1)
        titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -1)
        closeButton:SetPoint("LEFT", titleBar, "LEFT", 6, 0)
        syncButton:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
        titleText:SetPoint("LEFT", closeButton, "RIGHT", 8, 0)
        titleText:SetPoint("RIGHT", clampAnchor, "LEFT", -HEADER_ACTION_BUTTON_GAP, 0)
    else
        titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        closeButton:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
        syncButton:SetPoint("RIGHT", closeButton, "LEFT", -HEADER_ACTION_BUTTON_GAP, 0)
        titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
        titleText:SetPoint("RIGHT", clampAnchor, "LEFT", -HEADER_ACTION_BUTTON_GAP, 0)
    end
end

function Roster:ApplyPartyKeystoneFrameStyle()
    local utilityFrame = self.partyKeystoneFrame
    if not utilityFrame then
        return
    end

    vesperTools:ApplyRoundedWindowBackdrop(utilityFrame)
    utilityFrame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("roster"))

    local _, englishClass = UnitClass("player")
    local classColor = englishClass and C_ClassColor.GetClassColor(englishClass) or nil
    if classColor then
        utilityFrame:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)
    else
        utilityFrame:SetBackdropBorderColor(1, 1, 1, 0.2)
    end
end

function Roster:LayoutPartyKeystoneButton()
    local frame = self.frame
    local utilityFrame = self.partyKeystoneFrame
    local button = self.partyKeystoneButton
    if not (frame and utilityFrame and button) then
        return
    end

    local buttonSize = getRosterUtilityButtonSize()
    local buttonGap = ROSTER_PARTY_UTILITY_BUTTON_GAP
    local buttonCount = 1
    if self.partySpecRoleButton then
        buttonCount = buttonCount + 1
    end
    if self.partyReadyCheckButton then
        buttonCount = buttonCount + 1
    end
    if self.partyPullButton then
        buttonCount = buttonCount + 1
    end

    local rowWidth = (buttonSize * buttonCount) + (buttonGap * math.max(0, buttonCount - 1))
    local frameWidth = rowWidth + (ROSTER_PARTY_KEY_BUTTON_PADDING * 2)
    local frameHeight = buttonSize + (ROSTER_PARTY_KEY_BUTTON_PADDING * 2)
    utilityFrame:SetFrameStrata(frame:GetFrameStrata())
    utilityFrame:SetFrameLevel((frame:GetFrameLevel() or 0) + 70)
    utilityFrame:ClearAllPoints()
    utilityFrame:SetPoint("BOTTOM", frame, "TOP", 0, ROSTER_PARTY_KEY_BUTTON_OFFSET_Y)
    utilityFrame:SetSize(frameWidth, frameHeight)

    local previousButton = nil
    local function layoutButton(rowButton)
        if not rowButton then
            return
        end

        rowButton:SetSize(buttonSize, buttonSize)
        rowButton:ClearAllPoints()
        if previousButton then
            rowButton:SetPoint("LEFT", previousButton, "RIGHT", buttonGap, 0)
        else
            rowButton:SetPoint("LEFT", utilityFrame, "LEFT", ROSTER_PARTY_KEY_BUTTON_PADDING, 0)
        end
        previousButton = rowButton
    end

    layoutButton(button)
    layoutButton(self.partySpecRoleButton)
    layoutButton(self.partyReadyCheckButton)
    layoutButton(self.partyPullButton)
end

function Roster:RefreshPartyKeystoneButton()
    local button = self.partyKeystoneButton
    if not button or not button.icon then
        return
    end

    local unavailableText = getPartyKeystoneUnavailableText()
    local isAvailable = unavailableText == nil
    applyRosterIconButtonAvailability(button, isAvailable, unavailableText)
    self:RefreshPartySpecRoleButton()
    self:RefreshPartyGroupActionButtons()
end

function Roster:RefreshPartySpecRoleButton()
    local unavailableText = getPartySpecRoleUnavailableText()
    applyRosterIconButtonAvailability(
        self.partySpecRoleButton,
        unavailableText == nil,
        unavailableText
    )
end

function Roster:RefreshPartyGroupActionButtons()
    local readyUnavailableText = getReadyCheckUnavailableText()
    applyRosterIconButtonAvailability(
        self.partyReadyCheckButton,
        readyUnavailableText == nil,
        readyUnavailableText
    )

    local pullUnavailableText = getPullCountdownUnavailableText()
    applyRosterIconButtonAvailability(
        self.partyPullButton,
        pullUnavailableText == nil,
        pullUnavailableText
    )
end

function Roster:CreatePartyKeystoneFrame(parent)
    if self.partyKeystoneFrame then
        return self.partyKeystoneFrame
    end

    local utilityFrame = CreateFrame("Frame", "vesperToolsRosterPartyKeystoneFrame", parent, "BackdropTemplate")
    vesperTools:ApplyAddonWindowLayer(utilityFrame)

    local button = createRosterIconUtilityButton(
        utilityFrame,
        ROSTER_PARTY_KEY_BUTTON_ICON,
        function()
            self:ChoosePartyKeystone()
        end,
        function(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["ROSTER_PARTY_KEY_DECIDER"], 1, 1, 1)
            GameTooltip:AddLine(L["ROSTER_PARTY_KEY_TOOLTIP"], 0.85, 0.85, 0.85)
            if not selfButton._isAvailable then
                GameTooltip:AddLine(selfButton._unavailableText or L["ROSTER_PARTY_KEY_NO_GROUP"], 1, 0.35, 0.35)
            end
            GameTooltip:Show()
        end
    )

    local specRoleButton = createRosterIconUtilityButton(
        utilityFrame,
        ROSTER_PARTY_SPEC_ROLE_BUTTON_ICON,
        function()
            self:ChoosePartySpecRole()
        end,
        function(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["ROSTER_PARTY_SPEC_ROLE_DECIDER"], 1, 1, 1)
            GameTooltip:AddLine(L["ROSTER_PARTY_SPEC_ROLE_TOOLTIP"], 0.85, 0.85, 0.85)
            if not selfButton._isAvailable then
                GameTooltip:AddLine(selfButton._unavailableText or L["ROSTER_PARTY_SPEC_ROLE_NO_GROUP"], 1, 0.35, 0.35)
            end
            GameTooltip:Show()
        end
    )

    local readyButton = createRosterIconUtilityButton(
        utilityFrame,
        ROSTER_READY_CHECK_BUTTON_ICON,
        function()
            if not startReadyCheck() then
                vesperTools:Print(getUnavailableText())
            end
        end,
        function(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["GROUP_ACTION_READY"] or READY_CHECK or "Ready", 1, 1, 1)
            GameTooltip:AddLine(L["GROUP_ACTION_READY_TOOLTIP"] or "Start a ready check", 0.85, 0.85, 0.85)
            if not selfButton._isAvailable then
                GameTooltip:AddLine(selfButton._unavailableText or getUnavailableText(), 1, 0.35, 0.35)
            end
            GameTooltip:Show()
        end
    )

    local pullButton = createRosterIconUtilityButton(
        utilityFrame,
        ROSTER_PULL_TIMER_BUTTON_ICON,
        function()
            if not startPullCountdown() then
                vesperTools:Print(L["GROUP_ACTION_PULL_FAILED"])
            end
        end,
        function(selfButton)
            local tooltipFormat = L["GROUP_ACTION_PULL_TOOLTIP_FMT"] or "Start a %d second pull timer"
            GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
            GameTooltip:SetText(string.format("%s %d", L["GROUP_ACTION_PULL"] or "Pull", ROSTER_PULL_COUNTDOWN_SECONDS), 1, 1, 1)
            GameTooltip:AddLine(string.format(tooltipFormat, ROSTER_PULL_COUNTDOWN_SECONDS), 0.85, 0.85, 0.85)
            if not selfButton._isAvailable then
                GameTooltip:AddLine(selfButton._unavailableText or getUnavailableText(), 1, 0.35, 0.35)
            end
            GameTooltip:Show()
        end
    )

    self.partyKeystoneFrame = utilityFrame
    self.partyKeystoneButton = button
    self.partySpecRoleButton = specRoleButton
    self.partyReadyCheckButton = readyButton
    self.partyPullButton = pullButton
    self:ApplyPartyKeystoneFrameStyle()
    self:LayoutPartyKeystoneButton()
    self:RefreshPartyKeystoneButton()
    return utilityFrame
end

function Roster:GetPartyKeystoneCandidates(keystoneSync)
    local candidates = {}
    if getPartyChatChannel() == nil then
        return candidates, nil
    end

    if keystoneSync and type(keystoneSync.UpdateCurrentCharacterKeystoneSnapshot) == "function" then
        keystoneSync:UpdateCurrentCharacterKeystoneSnapshot()
    end

    local seen = {}
    local groupNames = {}
    local function addUnit(unit)
        local fullName = getUnitFullName(unit)
        if not fullName or seen[fullName] then
            return
        end
        seen[fullName] = true
        groupNames[#groupNames + 1] = fullName

        local keyData = keystoneSync
            and type(keystoneSync.GetStoredKeystoneData) == "function"
            and keystoneSync:GetStoredKeystoneData(fullName)
            or nil
        if type(keyData) ~= "table" then
            return
        end

        local mapID = math.floor((tonumber(keyData.mapID) or 0) + 0.5)
        local level = math.floor((tonumber(keyData.level) or 0) + 0.5)
        if mapID <= 0 or level <= 0 then
            return
        end

        local abbrev = keystoneSync
            and type(keystoneSync.GetDungeonAbbrev) == "function"
            and keystoneSync:GetDungeonAbbrev(mapID)
            or L["KEYSTONE_UNKNOWN_ABBREV"]
        candidates[#candidates + 1] = {
            fullName = fullName,
            ownerName = getPartyDisplayName(fullName, unit),
            mapID = mapID,
            level = level,
            keyText = string.format("%s +%d", abbrev, level),
        }
    end

    addUnit("player")

    local partyCount = 0
    if type(GetNumSubgroupMembers) == "function" then
        partyCount = tonumber(GetNumSubgroupMembers()) or 0
    elseif type(GetNumGroupMembers) == "function" then
        partyCount = math.max(0, (tonumber(GetNumGroupMembers()) or 1) - 1)
    end

    for i = 1, partyCount do
        addUnit("party" .. i)
    end

    table.sort(groupNames)
    return candidates, table.concat(groupNames, "|")
end

function Roster:GetCachedPartyKeystoneChoice(candidates, groupSignature)
    if type(groupSignature) ~= "string" or groupSignature == "" then
        return nil
    end
    if self.partyKeystoneChoiceGroupSignature ~= groupSignature or type(self.partyKeystoneChoice) ~= "table" then
        return nil
    end

    for i = 1, #(candidates or {}) do
        local candidate = candidates[i]
        if isSamePartyKeystoneChoice(candidate, self.partyKeystoneChoice) then
            return candidate
        end
    end

    return nil
end

function Roster:SetCachedPartyKeystoneChoice(choice, groupSignature)
    if type(choice) ~= "table" or type(groupSignature) ~= "string" or groupSignature == "" then
        self.partyKeystoneChoice = nil
        self.partyKeystoneChoiceGroupSignature = nil
        return
    end

    self.partyKeystoneChoiceGroupSignature = groupSignature
    self.partyKeystoneChoice = {
        fullName = choice.fullName,
        ownerName = choice.ownerName,
        mapID = choice.mapID,
        level = choice.level,
        keyText = choice.keyText,
    }
end

function Roster:PickPartyKeystoneChoice(candidates, groupSignature, forceNew)
    if type(candidates) ~= "table" or #candidates == 0 then
        return nil
    end

    local pool = candidates
    if forceNew and #candidates > 1 and self.partyKeystoneChoiceGroupSignature == groupSignature then
        local rerollPool = {}
        for i = 1, #candidates do
            if not isSamePartyKeystoneChoice(candidates[i], self.partyKeystoneChoice) then
                rerollPool[#rerollPool + 1] = candidates[i]
            end
        end
        if #rerollPool > 0 then
            pool = rerollPool
        end
    end

    local choice = pool[math.random(#pool)]
    self:SetCachedPartyKeystoneChoice(choice, groupSignature)
    return choice
end

function Roster:AnnouncePartyKeystoneChoice(choice)
    if type(choice) ~= "table" then
        return false
    end

    local message = string.format(
        L["ROSTER_PARTY_KEY_ANNOUNCE_FMT"],
        choice.ownerName or UNKNOWN,
        choice.keyText or L["KEYSTONE_UNKNOWN_ABBREV"]
    )
    local channel = getPartyChatChannel()
    if channel and type(SendChatMessage) == "function" then
        SendChatMessage(message, channel)
        return true
    end

    vesperTools:Print(message)
    return false
end

function Roster:ChoosePartyKeystone()
    local unavailableText = getPartyKeystoneUnavailableText()
    if unavailableText then
        self:SetCachedPartyKeystoneChoice(nil, nil)
        vesperTools:Print(unavailableText)
        self:RefreshPartyKeystoneButton()
        return false
    end

    local keystoneSync = vesperTools:GetModule("KeystoneSync", true)
    if keystoneSync and type(keystoneSync.RequestPartyKeystones) == "function" then
        keystoneSync:RequestPartyKeystones({ silent = true })
    end

    local candidates, groupSignature = self:GetPartyKeystoneCandidates(keystoneSync)
    if #candidates == 0 then
        self:SetCachedPartyKeystoneChoice(nil, nil)
        vesperTools:Print(L["ROSTER_PARTY_KEY_NONE"])
        self:RefreshPartyKeystoneButton()
        return false
    end

    local forceNew = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
    local choice = (not forceNew) and self:GetCachedPartyKeystoneChoice(candidates, groupSignature) or nil
    if not choice then
        choice = self:PickPartyKeystoneChoice(candidates, groupSignature, forceNew)
    end

    self:RefreshPartyKeystoneButton()
    return self:AnnouncePartyKeystoneChoice(choice)
end

function Roster:GetPartySpecRoleCandidates()
    local candidates = {}
    local _, _, classID = UnitClass("player")
    classID = tonumber(classID)
    if not classID then
        return candidates, nil
    end

    if not C_SpecializationInfo
        or type(C_SpecializationInfo.GetNumSpecializationsForClassID) ~= "function"
        or type(GetSpecializationInfoForClassID) ~= "function" then
        return candidates, classID
    end

    local ok, specializationCount = pcall(C_SpecializationInfo.GetNumSpecializationsForClassID, classID)
    if not ok then
        return candidates, classID
    end

    specializationCount = math.max(0, math.floor(tonumber(specializationCount) or 0))
    local sex = type(UnitSex) == "function" and UnitSex("player") or nil
    for index = 1, specializationCount do
        local infoOK, specID, specName, _specDescription, _specIcon, role = pcall(
            GetSpecializationInfoForClassID,
            classID,
            index,
            sex
        )
        if infoOK
            and tonumber(specID)
            and type(specName) == "string"
            and specName ~= ""
            and (role == "TANK" or role == "HEALER" or role == "DAMAGER") then
            candidates[#candidates + 1] = {
                classID = classID,
                specID = tonumber(specID),
                specName = specName,
                role = role,
            }
        end
    end

    return candidates, classID
end

function Roster:GetCachedPartySpecRoleChoice(candidates, classID)
    classID = tonumber(classID)
    if not classID
        or tonumber(self.partySpecRoleChoiceClassID) ~= classID
        or type(self.partySpecRoleChoice) ~= "table" then
        return nil
    end

    for i = 1, #(candidates or {}) do
        local candidate = candidates[i]
        if isSamePartySpecRoleChoice(candidate, self.partySpecRoleChoice) then
            return candidate
        end
    end

    return nil
end

function Roster:SetCachedPartySpecRoleChoice(choice, classID)
    classID = tonumber(classID)
    if type(choice) ~= "table" or not classID then
        self.partySpecRoleChoice = nil
        self.partySpecRoleChoiceClassID = nil
        return
    end

    self.partySpecRoleChoiceClassID = classID
    self.partySpecRoleChoice = {
        classID = classID,
        specID = choice.specID,
        specName = choice.specName,
        role = choice.role,
    }
end

function Roster:PickPartySpecRoleChoice(candidates, classID, forceNew)
    if type(candidates) ~= "table" or #candidates == 0 then
        return nil
    end

    local pool = candidates
    if forceNew
        and #candidates > 1
        and tonumber(self.partySpecRoleChoiceClassID) == tonumber(classID)
        and type(self.partySpecRoleChoice) == "table" then
        local rerollPool = {}
        for i = 1, #candidates do
            if not isSamePartySpecRoleChoice(candidates[i], self.partySpecRoleChoice) then
                rerollPool[#rerollPool + 1] = candidates[i]
            end
        end
        if #rerollPool > 0 then
            pool = rerollPool
        end
    end

    local choice = pool[math.random(#pool)]
    self:SetCachedPartySpecRoleChoice(choice, classID)
    return choice
end

function Roster:AnnouncePartySpecRoleChoice(choice)
    if type(choice) ~= "table" then
        return false
    end

    local message = string.format(
        L["ROSTER_PARTY_SPEC_ROLE_ANNOUNCE_FMT"],
        getPartySpecRoleLabel(choice.role),
        choice.specName or UNKNOWN
    )
    local channel = getPartyChatChannel()
    if channel and type(SendChatMessage) == "function" then
        SendChatMessage(message, channel)
        return true
    end

    vesperTools:Print(message)
    return false
end

function Roster:ChoosePartySpecRole()
    local unavailableText = getPartySpecRoleUnavailableText()
    if unavailableText then
        self:SetCachedPartySpecRoleChoice(nil, nil)
        vesperTools:Print(unavailableText)
        self:RefreshPartySpecRoleButton()
        return false
    end

    local candidates, classID = self:GetPartySpecRoleCandidates()
    if #candidates == 0 then
        self:SetCachedPartySpecRoleChoice(nil, nil)
        vesperTools:Print(L["ROSTER_PARTY_SPEC_ROLE_NONE"])
        self:RefreshPartySpecRoleButton()
        return false
    end

    local forceNew = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
    local choice = (not forceNew) and self:GetCachedPartySpecRoleChoice(candidates, classID) or nil
    if not choice then
        choice = self:PickPartySpecRoleChoice(candidates, classID, forceNew)
    end

    self:RefreshPartySpecRoleButton()
    return self:AnnouncePartySpecRoleChoice(choice)
end

function Roster:ApplyRosterStyling()
    if not self.frame then
        return
    end

    local baseFontSize = rosterFontSize()
    self.currentFontSize = baseFontSize
    self.rowHeight = rosterRowHeight(baseFontSize)
    self.headerHeight = rosterHeaderHeight(baseFontSize)
    self.actionButtonHeight = rosterActionButtonHeight(baseFontSize)
    self.titleBarHeight = rosterTitleBarHeight(baseFontSize)

    self.frame:SetBackdropColor(0.07, 0.07, 0.07, vesperTools:GetConfiguredOpacity("roster"))
    self:ApplyPartyKeystoneFrameStyle()
    self:LayoutPartyKeystoneButton()
    self:RefreshPartyKeystoneButton()

    if self.titleBar then
        self.titleBar:SetHeight(self.titleBarHeight)
    end
    if self.headerFrame then
        self.headerFrame:SetHeight(self.headerHeight)
    end

    if self.titleText then
        self.titleText:SetText(GetGuildInfo("player") or L["ROSTER_TITLE_FALLBACK"])
        vesperTools:ApplyConfiguredFont(self.titleText, baseFontSize + 4, "")
        vesperTools:EnsureFontStringRenders(self.titleText)
    end

    for i = 1, #(self.headerButtons or {}) do
        local button = self.headerButtons[i]
        if button and button.text then
            vesperTools:ApplyConfiguredFont(button.text, baseFontSize, "")
            vesperTools:EnsureFontStringRenders(button.text)
        end
    end

    -- Resize titlebar action buttons to fit text + current font. Re-apply the
    -- font first: labels are fonted at creation and the configured font may
    -- have changed or only become resolvable afterwards.
    for i = 1, #(self.titlebarActionButtons or {}) do
        local btn = self.titlebarActionButtons[i]
        if btn and btn.text then
            vesperTools:ApplyConfiguredFont(btn.text, 11, "")
            vesperTools:EnsureFontStringRenders(btn.text)
            local minWidth = btn.minWidth or 56
            local stringWidth = btn.text:GetStringWidth() or 0
            local desiredWidth = math.max(minWidth, math.floor(stringWidth + 16))
            btn:SetSize(desiredWidth, self.actionButtonHeight)
        end
    end

    -- Apply titlebar layout AFTER buttons resize so the title text clamp uses
    -- the post-resize position of the leftmost button.
    self:ApplyTitlebarLayout()

    for i = 1, #(self.rosterRows or {}) do
        local row = self.rosterRows[i]
        if row and row.columns then
            for _, text in pairs(row.columns) do
                vesperTools:ApplyConfiguredFont(text, baseFontSize, "")
            end
        end
    end

    -- Row heights / positions depend on font size; refresh the list when shown.
    if self.frame:IsShown() then
        self:RequestRosterRefresh()
    end
end

function Roster:PerformRosterRefresh()
    self.pendingRosterRefresh = false
    if not self.frame or not self.frame:IsShown() then
        return
    end

    self:UpdateRosterList()
    self:RefreshPartyKeystoneButton()
end

function Roster:RequestRosterRefresh()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    -- Coalesce bursts of refresh requests (e.g. multiple sync messages firing
    -- back-to-back) into a single rebuild on the next frame.
    if self.refreshScheduled then
        return
    end
    self.refreshScheduled = true

    C_Timer.After(0, function()
        self.refreshScheduled = false
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
    end)
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

-- Width derived arithmetically from contentFrame so a freshly-applied scrollbar
-- inset does not require WoW to re-flow before we can read scrollFrame:GetWidth().
function Roster:GetListContentWidth(hasScrollBar)
    local width = 0
    if self.contentFrame and self.contentFrame.GetWidth then
        width = self.contentFrame:GetWidth() or 0
    end
    if width <= 0 and self.scrollFrame and self.scrollFrame.GetWidth then
        width = self.scrollFrame:GetWidth() or 0
    end
    if hasScrollBar then
        width = width - ROSTER_SCROLLBAR_GUTTER
    end
    return math.max(ROSTER_MIN_CONTENT_WIDTH, math.floor(width + 0.5))
end

function Roster:UpdateListViewportLayout(hasScrollBar)
    if not self.contentFrame or not self.headerFrame or not self.scrollFrame then
        return
    end

    local shouldShowScrollBar = hasScrollBar and true or false
    self.rosterScrollBarVisible = shouldShowScrollBar
    vesperTools:SetModernScrollBarVisibility(self.scrollFrame, shouldShowScrollBar)

    -- Always re-apply anchors. The cost is four SetPoint calls; the benefit is
    -- that any external mutation (skinning, drag handles, future code) cannot
    -- silently desync the header from the scroll viewport.
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

    local resolvedFontSize = tonumber(fontSize) or rosterFontSize()
    local headerH = self.headerHeight or rosterHeaderHeight(resolvedFontSize)
    for i = 1, #COLUMNS do
        local layout = columnLayout[i]
        local button = self.headerButtons and self.headerButtons[i] or nil
        if layout and button then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.headerFrame, "TOPLEFT", layout.offset, 0)
            button:SetSize(layout.width, headerH)
            vesperTools:ApplyConfiguredFont(button.text, resolvedFontSize, "")
            button.text:SetText(layout.label)
            vesperTools:EnsureFontStringRenders(button.text)

            -- Show / hide a separate sort-direction icon. Rendering it as a
            -- texture (instead of an inline |T...|t suffix on the label) keeps
            -- it visible even when a long localized label gets truncated.
            if button.sortIcon then
                if self.sortColumn == layout.key then
                    local texture = self.sortAscending
                        and "Interface\\Buttons\\Arrow-Up-Up"
                        or "Interface\\Buttons\\Arrow-Down-Up"
                    button.sortIcon:SetTexture(texture)
                    button.sortIcon:Show()
                else
                    button.sortIcon:Hide()
                end
            end
        end
    end
end

function Roster:LayoutRowColumns(row, columnLayout, fontSize)
    if not row or not row.columns then
        return
    end

    local resolvedFontSize = tonumber(fontSize) or rosterFontSize()
    local rowH = self.rowHeight or rosterRowHeight(resolvedFontSize)
    row:SetSize(columnLayout.totalWidth, rowH)
    local portalColumnLayout = nil

    for i = 1, #COLUMNS do
        local layout = columnLayout[i]
        local text = row.columns[layout.key]
        if layout.key == PORTAL_COLUMN_KEY then
            portalColumnLayout = layout
        end
        if text then
            text:ClearAllPoints()
            text:SetPoint("TOPLEFT", row, "TOPLEFT", layout.offset + ROSTER_TEXT_INSET, -1)
            text:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", layout.offset + layout.width - ROSTER_TEXT_INSET, -(rowH - 1))
            vesperTools:ApplyConfiguredFont(text, resolvedFontSize, "")
            vesperTools:EnsureFontStringRenders(text)
        end
    end

    if row.button then
        row.button:SetAllPoints(row)
    end

    if row.portalButton then
        if type(InCombatLockdown) == "function" and InCombatLockdown() then
            return
        end
        row.portalButton:ClearAllPoints()
        if portalColumnLayout and row.portalSpellName then
            row.portalButton:SetPoint("TOPLEFT", row, "TOPLEFT", portalColumnLayout.offset, 0)
            row.portalButton:SetSize(portalColumnLayout.width, rowH)
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
            -- Reset background to base in case the row was recycled mid-hover
            -- (OnLeave never fires when a frame hides under the cursor).
            if row.background and row.baseColorR then
                row.background:SetColorTexture(row.baseColorR, row.baseColorG, row.baseColorB, 1)
            end
            if row.button then
                row.button.ownerRow = nil
            end
            if row.portalButton then
                row.portalButton.ownerRow = nil
                if not (type(InCombatLockdown) == "function" and InCombatLockdown()) then
                    row.portalButton:SetAttribute("type1", nil)
                    row.portalButton:SetAttribute("spell1", nil)
                    row.portalButton:EnableMouse(false)
                    row.portalButton:Hide()
                end
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

    frame:SetSize(ROSTER_MIN_FRAME_WIDTH, ROSTER_MIN_FRAME_HEIGHT)

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
    frame:SetClampedToScreen(true)
    frame:SetResizable(true)
    -- Initial bounds; ApplyAutoFrameHeight() locks the vertical range to the
    -- content-driven height on every refresh.
    local screenW = math.floor((UIParent:GetWidth() or 1920) + 0.5)
    frame:SetResizeBounds(
        ROSTER_MIN_FRAME_WIDTH,
        ROSTER_MIN_FRAME_HEIGHT,
        math.max(screenW, ROSTER_MIN_FRAME_WIDTH),
        self:GetMaxFrameHeight()
    )

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
    self:CreatePartyKeystoneFrame(frame)

    -- Titlebar
    local initialFontSize = rosterFontSize()
    local titlebar = CreateFrame("Frame", nil, frame)
    titlebar:SetHeight(rosterTitleBarHeight(initialFontSize))
    titlebar:SetPoint("TOPLEFT", 1, -1)
    titlebar:SetPoint("TOPRIGHT", -1, -1)

    local titlebg = titlebar:CreateTexture(nil, "BACKGROUND")
    titlebg:SetAllPoints()
    titlebg:SetColorTexture(0.1, 0.1, 0.1, 1)

    local title = titlebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 10, 0)
    title:SetText(GetGuildInfo("player") or L["ROSTER_TITLE_FALLBACK"])
    title:SetWordWrap(false)
    title:SetNonSpaceWrap(false)
    title:SetJustifyH("LEFT")
    vesperTools:ApplyConfiguredFont(title, initialFontSize + 4, "")
    self.titleText = title
    self.titleBar = titlebar
    self.titlebarActionButtons = {}

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
        local function rebuildPortalCache()
            local Portals = vesperTools:GetModule("Portals", true)
            if Portals and type(Portals.ForceRefreshPortalAvailability) == "function" then
                Portals:ForceRefreshPortalAvailability({ clearCache = true })
            end
        end

        local Auto = vesperTools:GetModule("Automation", true)
        if Auto and type(Auto.ManualSync) == "function" then
            Auto:ManualSync()
            rebuildPortalCache()
        else
            local KeystoneSync = vesperTools:GetModule("KeystoneSync", true)
            if KeystoneSync and type(KeystoneSync.RefreshKeystoneData) == "function" then
                KeystoneSync:RefreshKeystoneData({ requestGuild = true, silent = false })
            elseif KeystoneSync and type(KeystoneSync.RequestGuildKeystones) == "function" then
                KeystoneSync:RequestGuildKeystones()
            end

            rebuildPortalCache()
        end
        self:RequestRosterRefresh()
    end)
    self.syncButton = syncBtn
    self.titlebarActionButtons[#self.titlebarActionButtons + 1] = syncBtn

    local confBtn = createHeaderActionButton(titlebar, syncBtn, 56, L["ROSTER_BUTTON_CONFIG"], function(_, mouseButton)
        if mouseButton == "LeftButton" then
            vesperTools:OpenConfig()
        end
    end)
    self.titlebarActionButtons[#self.titlebarActionButtons + 1] = confBtn

    local bagsBtn = createHeaderActionButton(titlebar, confBtn, 56, L["ROSTER_BUTTON_BAGS"], function(_, mouseButton)
        if mouseButton == "LeftButton" then
            local BagsWindow = vesperTools:GetModule("BagsWindow", true)
            if BagsWindow and type(BagsWindow.Toggle) == "function" then
                BagsWindow:Toggle()
            end
        end
    end)
    self.titlebarActionButtons[#self.titlebarActionButtons + 1] = bagsBtn

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
    self.titlebarActionButtons[#self.titlebarActionButtons + 1] = blizzBagsBtn

    local bankBtn = createHeaderActionButton(titlebar, blizzBagsBtn, 56, L["ROSTER_BUTTON_BANK"], function(_, mouseButton)
        if mouseButton == "LeftButton" then
            local BankWindow = vesperTools:GetModule("BankWindow", true)
            if BankWindow and type(BankWindow.Toggle) == "function" then
                BankWindow:Toggle()
            end
        end
    end)
    self.titlebarActionButtons[#self.titlebarActionButtons + 1] = bankBtn
    self.leftmostTitlebarButton = bankBtn

    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", titlebar, "BOTTOMLEFT", 5, -5)
    contentFrame:SetPoint("BOTTOMRIGHT", -5, 20)
    self.contentFrame = contentFrame

    local headerFrame = CreateFrame("Frame", nil, contentFrame)
    headerFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -ROSTER_SCROLLBAR_GUTTER, 0)
    headerFrame:SetHeight(rosterHeaderHeight(initialFontSize))
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

        local sortIcon = button:CreateTexture(nil, "OVERLAY")
        sortIcon:SetSize(ROSTER_SORT_ICON_SIZE, ROSTER_SORT_ICON_SIZE)
        sortIcon:SetPoint("RIGHT", button, "RIGHT", -ROSTER_TEXT_INSET, 0)
        sortIcon:Hide()
        button.sortIcon = sortIcon

        local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", button, "LEFT", ROSTER_TEXT_INSET, 0)
        -- Always reserve room on the right so the sort icon never overlaps the label.
        text:SetPoint("RIGHT", button, "RIGHT", -(ROSTER_TEXT_INSET + ROSTER_SORT_ICON_RESERVE), 0)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("MIDDLE")
        text:SetWordWrap(false)
        vesperTools:ApplyConfiguredFont(text, initialFontSize, "")
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
    scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -ROSTER_SCROLLBAR_GUTTER, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(selfFrame, delta)
        local current = selfFrame:GetVerticalScroll() or 0
        local maximum = math.max(0, (selfFrame.contentHeight or 0) - (selfFrame:GetHeight() or 0))
        local step = (self.rowHeight or rosterRowHeight(rosterFontSize())) * 2
        local nextValue = math.max(0, math.min(maximum, current - (delta * step)))
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
    frame.vgPartyKeystoneFrame = self.partyKeystoneFrame
    frame.vgPartyKeystoneButton = self.partyKeystoneButton
    frame.vgPartySpecRoleButton = self.partySpecRoleButton
    frame.vgPartyReadyCheckButton = self.partyReadyCheckButton
    frame.vgPartyPullButton = self.partyPullButton
    frame.vgHeaderFrame = headerFrame
    frame.vgHeaderButtons = self.headerButtons
    frame.vgScrollFrame = scrollFrame
    frame.vgScrollContent = scrollChild
    frame.vgRosterRows = self.rosterRows

    -- Live-resize relayout: when the user drags the resize grip, columns and
    -- rows are positioned by absolute pixel widths computed in UpdateRosterList.
    -- Without this hook, the columns stay frozen until OnMouseUp triggers a
    -- refresh, leaving rows misaligned mid-drag. We schedule a column-only
    -- relayout on the next frame (cheap, no data refetch).
    frame:SetScript("OnSizeChanged", function()
        if self.relayoutScheduled then
            return
        end
        self.relayoutScheduled = true
        C_Timer.After(0, function()
            self.relayoutScheduled = false
            self:RelayoutColumnsForCurrentSize()
        end)
    end)

    self:ApplyRosterStyling()
    return frame
end

-- Lightweight column-only relayout used during live resize drags. Reuses the
-- already-collected data; only recomputes widths and re-anchors visible rows.
function Roster:RelayoutColumnsForCurrentSize()
    if not self.frame or not self.frame:IsShown() then
        return
    end
    if not self.scrollContent or not self.scrollFrame then
        return
    end

    local fontSize = self.currentFontSize or rosterFontSize()
    local visibleHeight = self.scrollFrame:GetHeight() or 0
    local contentHeight = self.scrollFrame.contentHeight or 0
    local hasScrollBar = contentHeight > (visibleHeight + 0.5)

    self:UpdateListViewportLayout(hasScrollBar)
    local columnLayout = self:BuildColumnLayout(self:GetListContentWidth(hasScrollBar))
    self.currentColumnLayout = columnLayout
    self:UpdateHeaderLayout(columnLayout, fontSize)

    for i = 1, #(self.rosterRows or {}) do
        local row = self.rosterRows[i]
        if row and row:IsShown() then
            self:LayoutRowColumns(row, columnLayout, fontSize)
        end
    end

    self.scrollContent:SetWidth(columnLayout.totalWidth)
end

function Roster:AcquireRosterRow()
    local parent = self.scrollContent
    if not parent then
        return nil
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(self.rowHeight or rosterRowHeight(rosterFontSize()))

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
        -- Mirror the row's left-click handling so a double-click on the keyLevel
        -- column still triggers the row's primary action (invite / request join).
        -- The secure spell cast still fires; this only adds the row action on top.
        if button == "LeftButton" and not down then
            if ownerRow then
                self:HandleRosterRowLeftClick(ownerRow)
            end
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
    if not mapID then
        return
    end

    local ok, dungeonName = false, nil
    if C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" then
        ok, dungeonName = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
    end
    dungeonName = ok and dungeonName or nil
    if not dungeonName and dataHandle and type(dataHandle.GetDefaultDungeonByMapID) == "function" then
        local dungeonInfo = dataHandle:GetDefaultDungeonByMapID(mapID)
        dungeonName = dungeonInfo and dungeonInfo.dungeonName or nil
    end
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
                        fullName = playerName,
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

    local highlightColors = {}
    local function highlightUnit(unit, color)
        local fullName = getUnitFullName(unit)
        if fullName then
            highlightColors[fullName] = color
            -- Guild-leader fallback entries may only supply a short name.
            highlightColors[fullName:match("([^-]+)") or fullName] = color
        end
    end
    local partyColor = { 0, 0.8, 0.8 }
    for partyIndex = 1, 4 do
        highlightUnit("party" .. partyIndex, partyColor)
    end
    -- Self takes priority over party highlights, including when solo.
    highlightUnit("player", { 1, 105 / 255, 180 / 255 })

    for i = 1, #entries do
        local entry = entries[i]
        local runText = "+" .. entry.level
        -- Guild-leader fallback entries have no timing flag; keep them neutral.
        -- Inline key-rarity colors would override these timing-status colors.
        local r, g, b = 0.8, 0.8, 0.8
        if entry.inTime == true then
            r, g, b = 129 / 255, 199 / 255, 132 / 255
            runText = runText .. " (" .. L["BEST_KEYS_STATUS_TIMED"] .. ")"
        elseif entry.inTime == false then
            r, g, b = 229 / 255, 115 / 255, 115 / 255
            runText = runText .. " (" .. L["BEST_KEYS_STATUS_OVER"] .. ")"
        end
        local nameR, nameG, nameB = 1, 1, 1
        local highlight = highlightColors[entry.fullName or entry.name]
        if highlight then
            nameR, nameG, nameB = highlight[1], highlight[2], highlight[3]
            r, g, b = nameR, nameG, nameB
        end
        GameTooltip:AddDoubleLine(entry.name, runText, nameR, nameG, nameB, r, g, b)
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

    local canUpdateSecure = not (type(InCombatLockdown) == "function" and InCombatLockdown())
    if canUpdateSecure then
        portalButton:SetAttribute("type1", nil)
        portalButton:SetAttribute("spell1", nil)

        row.portalSpellName = nil
        if member.keystoneMapID and dataHandle then
            local portals = vesperTools:GetModule("Portals", true)
            local portalState = portals
                and type(portals.ResolveDungeonPortalState) == "function"
                and portals:ResolveDungeonPortalState(member.keystoneMapID, {
                    allowSessionCache = true,
                    rememberSession = true,
                })
                or nil

            if portalState and portalState.known and portalState.spellName then
                row.portalSpellName = portalState.spellName
                portalButton:SetAttribute("type1", "spell")
                portalButton:SetAttribute("spell1", portalState.spellName)
            else
                local dungeonInfo = dataHandle:GetDungeonByMapID(member.keystoneMapID)
                if dungeonInfo then
                    local spellName = getSpellName(dungeonInfo.spellID)
                    if spellName and vesperTools:IsSpellKnownForPlayer(dungeonInfo.spellID, {
                        allowSessionCache = true,
                        rememberSession = true,
                        sessionScope = "dungeonPortal",
                    }) then
                        row.portalSpellName = spellName
                        portalButton:SetAttribute("type1", "spell")
                        portalButton:SetAttribute("spell1", spellName)
                    end
                end
            end
        end
    end

    local rowH = self.rowHeight or rosterRowHeight(rosterFontSize())
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.scrollContent, "TOPLEFT", 0, -((index - 1) * rowH))
    self:LayoutRowColumns(row, columnLayout, fontSize)
    row:Show()
end

function Roster:CollectRosterMembers(dataHandle, keystoneSync)
    local members = {}
    local playerRealm = GetRealmName()
    local playerRealmNormalized = GetNormalizedRealmName()

    local groupMembers = {}
    local function markGroupMember(unitName, unitRealm)
        if type(unitName) ~= "string" or unitName == "" then
            return
        end

        groupMembers[unitName] = true
        local shortName = unitName:match("([^-]+)") or unitName
        groupMembers[shortName] = true

        if string.find(unitName, "-", 1, true) then
            groupMembers[unitName] = true
            return
        end

        local realm = unitRealm and unitRealm ~= "" and unitRealm or playerRealmNormalized
        if realm and realm ~= "" then
            groupMembers[unitName .. "-" .. realm] = true
        end
    end

    if IsInGroup() then
        for j = 1, GetNumGroupMembers() do
            local unit = IsInRaid() and ("raid" .. j) or (j == 1 and "player" or ("party" .. (j - 1)))
            markGroupMember(UnitName(unit))
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
                isInGroup = groupMembers[fullName] or groupMembers[name] or groupMembers[displayName] or false,
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

function Roster:GetMaxFrameHeight()
    local screenH = UIParent and UIParent:GetHeight() or 1080
    return math.max(ROSTER_MIN_FRAME_HEIGHT, math.floor(screenH * ROSTER_MAX_HEIGHT_FRACTION + 0.5))
end

-- Returns (autoHeight, scrollViewport, chrome, rowH) for `numMembers`. autoHeight
-- is clamped to [ROSTER_MIN_FRAME_HEIGHT, 70% of screen]; scrollViewport is the
-- arithmetic scrollFrame height after auto-resize, used in place of
-- scrollFrame:GetHeight() (which is stale until layout reflows).
function Roster:ComputeAutoFrameMetrics(numMembers)
    local fontSize = self.currentFontSize or rosterFontSize()
    local rowH = self.rowHeight or rosterRowHeight(fontSize)
    local headerH = self.headerHeight or rosterHeaderHeight(fontSize)
    local titleBarH = self.titleBarHeight or rosterTitleBarHeight(fontSize)
    local chrome = rosterChromeHeight(titleBarH, headerH)
    local rowsHeight = math.max(rowH, (tonumber(numMembers) or 0) * rowH)
    local desired = chrome + rowsHeight
    local maxH = self:GetMaxFrameHeight()
    local clampedHeight = math.max(ROSTER_MIN_FRAME_HEIGHT, math.min(maxH, desired))
    return clampedHeight, clampedHeight - chrome, chrome, rowH
end

-- Apply a new frame height while preserving the visual vertical center, then
-- save the resulting position. Width is left untouched. Vertical resize bounds
-- are locked to the new height so the resize grip can only adjust width.
function Roster:ApplyAutoFrameHeight(targetHeight)
    if not self.frame then
        return false
    end
    local currentHeight = self.frame:GetHeight() or 0
    local delta = targetHeight - currentHeight

    if math.abs(delta) >= 0.5 then
        self.frame:SetHeight(targetHeight)

        -- Keep the visual center fixed: shift the anchor by half the delta in
        -- the direction opposite the anchor edge. CENTER / LEFT / RIGHT anchors
        -- already grow symmetrically, so they need no adjustment.
        local point, relativeTo, relativePoint, xOfs, yOfs = self.frame:GetPoint()
        if point then
            local yAdjust = 0
            if point:find("TOP") then
                yAdjust = delta / 2
            elseif point:find("BOTTOM") then
                yAdjust = -delta / 2
            end
            local newY = (yOfs or 0) + yAdjust
            if yAdjust ~= 0 then
                self.frame:ClearAllPoints()
                self.frame:SetPoint(point, relativeTo or UIParent, relativePoint, xOfs or 0, newY)
            end
            vesperTools.db.profile.rosterPosition = {
                point = point,
                relativePoint = relativePoint,
                xOfs = xOfs,
                yOfs = newY,
            }
        end
    end

    -- Lock vertical bounds to the new auto height; keep horizontal range open.
    local screenW = math.floor((UIParent:GetWidth() or 1920) + 0.5)
    self.frame:SetResizeBounds(
        ROSTER_MIN_FRAME_WIDTH,
        targetHeight,
        math.max(screenW, ROSTER_MIN_FRAME_WIDTH),
        targetHeight
    )

    return true
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

    local fontSize = rosterFontSize()
    local rowH = self.rowHeight or rosterRowHeight(fontSize)
    local dataHandle = vesperTools:GetModule("DataHandle", true)
    local keystoneSync = vesperTools:GetModule("KeystoneSync", true)
    local members = self:CollectRosterMembers(dataHandle, keystoneSync)

    -- Auto-size the frame vertically based on member count. Resizes both up
    -- and down (anchor shifted by half the height delta to keep visual center).
    local autoHeight, scrollViewport = self:ComputeAutoFrameMetrics(#members)
    self:ApplyAutoFrameHeight(autoHeight)

    local contentHeight = math.max(1, #members * rowH)
    -- Use the arithmetic scrollViewport instead of scrollFrame:GetHeight(),
    -- which is stale until WoW reflows after the SetHeight above.
    local hasScrollBar = contentHeight > (scrollViewport + 0.5)

    self:UpdateListViewportLayout(hasScrollBar)

    local columnLayout = self:BuildColumnLayout(self:GetListContentWidth(hasScrollBar))
    local scrollPosition = self.scrollFrame and (self.scrollFrame:GetVerticalScroll() or 0) or 0

    self.currentColumnLayout = columnLayout
    self:UpdateHeaderLayout(columnLayout, fontSize)

    for index = 1, #members do
        local row = self.rosterRows[index] or self:AcquireRosterRow()
        self:ConfigureRosterRow(row, members[index], index, columnLayout, fontSize, dataHandle)
    end

    self:HideRosterRows(#members + 1)

    self.scrollContent:SetWidth(columnLayout.totalWidth)
    self.scrollContent:SetHeight(contentHeight)
    self.scrollFrame.contentHeight = contentHeight

    local maxScroll = hasScrollBar and math.max(0, contentHeight - scrollViewport) or 0
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

    -- Portals UI hosts SecureActionButtonTemplate children, so hiding it during
    -- combat lockdown taints. Delegate to Portals which gates this correctly;
    -- if we're locked down, leave portals up rather than risk a taint error
    -- that would abort the macro/slash dispatch entirely.
    local Portals = vesperTools:GetModule("Portals", true)
    if Portals and Portals.VesperPortalsUI and Portals.VesperPortalsUI:IsShown() then
        if not InCombatLockdown() then
            if type(Portals.HandleCloseRequest) == "function" then
                Portals:HandleCloseRequest()
            else
                Portals.VesperPortalsUI:Hide()
            end
        end
    end
end

function Roster:Toggle()
    if self.frame and self.frame:IsShown() then
        self:HandleCloseRequest()
    else
        self:ShowRoster()
    end
end
